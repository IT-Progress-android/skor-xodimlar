import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_cubit.dart';
import 'package:skore_hodimlar/core/models/notification_model.dart';
import 'package:skore_hodimlar/core/services/notification_storage_service.dart';
import 'package:skore_hodimlar/firebase_options.dart';
import 'package:skore_hodimlar/router/app_router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // 1. FlutterFire background isolate uchun Firebase'ni ishga tushirish
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    if (role == 'admin') {
      return;
    }

    // Bu alohida background izolyator — LanguageCubit hech qachon ishga
    // tushmaydi, shuning uchun saqlangan tilni qo'lda yuklaymiz.
    AppLocalizations.setCurrentLanguage(
      AppLanguage.fromCode(prefs.getString(LanguageCubit.prefKey)),
    );

    final bool hasNotificationPayload = message.notification != null;
    final rawTitle =
        message.notification?.title ?? message.data['title']?.toString() ?? '';
    final rawBody =
        message.notification?.body ?? message.data['body']?.toString() ?? '';

    // 2. Android Notification Kanallarini background izolatorida KAFOLATLI yaratish (Skor Maktab kabi)
    final FlutterLocalNotificationsPlugin flnp =
        FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await flnp.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    final androidImpl = flnp
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      final AndroidNotificationChannel voiceChannel =
          AndroidNotificationChannel(
            'davomat_voice_channel_v2',
            AppLocalizations.trStatic('notif_channel_attendance_name'),
            description: AppLocalizations.trStatic(
              'notif_channel_attendance_desc',
            ),
            importance: Importance.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('davomat_sound'),
            enableVibration: true,
          );
      await androidImpl.createNotificationChannel(voiceChannel);
      final AndroidNotificationChannel reviewChannel =
          AndroidNotificationChannel(
            'manual_review_channel',
            AppLocalizations.trStatic('notif_channel_review_name'),
            description: AppLocalizations.trStatic('notif_channel_review_desc'),
            importance: Importance.defaultImportance,
            playSound: true,
            enableVibration: false,
          );
      await androidImpl.createNotificationChannel(reviewChannel);
    }

    final title = rawTitle.isNotEmpty
        ? rawTitle
        : AppLocalizations.trStatic('notif_attendance_reminder_title');
    final body = rawBody.isNotEmpty
        ? rawBody
        : AppLocalizations.trStatic('notif_attendance_reminder_body');

    await NotificationStorageService.addNotification(
      NotificationItem(
        id:
            message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
        isRead: false,
        type: message.data['type']?.toString() ?? 'attendance',
        data: message.data,
      ),
    );

    // Agar server notification payload yuborgan bo'lsa, Android tizimi fon rejimida tray'ga o'zi chiqaradi.
    // Duplicate chiqmasligi uchun faqat data-only bo'lsa qo'lda flnp.show() chaqiriladi.
    if (hasNotificationPayload) {
      return;
    }

    // Data-only payload bo'lsa:
    final int notifId = DateTime.now().microsecondsSinceEpoch.remainder(
      2147483647,
    );
    await flnp.show(
      id: notifId,
      title: title,
      body: body,
      payload: jsonEncode(message.data),
      notificationDetails: FcmService.detailsFor(
        message.data['type']?.toString(),
      ),
    );
  } catch (_) {}
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static AndroidNotificationChannel get _channel => AndroidNotificationChannel(
    'davomat_voice_channel_v2',
    AppLocalizations.trStatic('notif_channel_attendance_name'),
    description: AppLocalizations.trStatic('notif_channel_attendance_desc'),
    importance: Importance.max,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('davomat_sound'),
    enableVibration: true,
  );

  /// Rahbar so'rovni tasdiqlagani/rad etgani haqidagi xabarlar uchun.
  /// Davomat eslatmasidan farqli o'laroq shoshilinch emas, shuning uchun
  /// standart muhimlik va standart ovoz — kechasi maxsus ovoz bilan
  /// uyg'otmaydi.
  static AndroidNotificationChannel get _reviewChannel =>
      AndroidNotificationChannel(
        'manual_review_channel',
        AppLocalizations.trStatic('notif_channel_review_name'),
        description: AppLocalizations.trStatic('notif_channel_review_desc'),
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: false,
      );

  /// Xabar turiga qarab mos bildirishnoma sozlamasini tanlaydi.
  /// Backend `data.type` da `manual_review` yuborsa — sokin kanal.
  static NotificationDetails detailsFor(String? type) {
    if (type == 'manual_review') {
      return NotificationDetails(
        android: AndroidNotificationDetails(
          'manual_review_channel',
          AppLocalizations.trStatic('notif_channel_review_name'),
          channelDescription: AppLocalizations.trStatic(
            'notif_channel_review_desc',
          ),
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'davomat_voice_channel_v2',
        AppLocalizations.trStatic('notif_channel_attendance_name'),
        channelDescription: AppLocalizations.trStatic(
          'notif_channel_attendance_desc',
        ),
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('davomat_sound'),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'davomat_sound.wav',
      ),
    );
  }

  static Future<void> init() async {
    try {
      // 1. Request notification permissions (Android 13+ and iOS)
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Explicit Android 13+ notification permission request (Skor Maktab usuli)
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImplementation?.requestNotificationsPermission();

      // 2. Setup Local Notifications for Foreground display
      const androidInit = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data =
                  jsonDecode(response.payload!) as Map<String, dynamic>;
              _handleNotificationTap(data);
              return;
            } catch (_) {}
          }
          _handleNotificationTap({'action': 'open_attendance'});
        },
      );

      // Remove obsolete channels if existing
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.deleteNotificationChannel(channelId: 'high_importance_channel');
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.deleteNotificationChannel(channelId: 'davomat_voice_channel_v1');

      // Create Android Notification Channel with custom voice sound
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_reviewChannel);

      // 3. Set foreground presentation options (iOS)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 5. Synchronize role & topic subscription ('hodimlar')
      await syncUserRole();

      // 6. Retrieve and print FCM token, then register on backend
      final currentToken = await printToken();
      if (currentToken != null) {
        await registerTokenOnBackend(token: currentToken);
      }

      // 7. Listen to token refreshes and auto-update on backend
      _messaging.onTokenRefresh.listen((newToken) {
        registerTokenOnBackend(token: newToken);
      });

      // 8. Handle notification tap when app opened from background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message.data);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        unawaited(_handleNotificationTap(initialMessage.data));
      }

      // 9. Listen to incoming foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        // Role check: Only Hodim should receive notifications, NOT Rahbar (admin)
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('user_role');
        if (role == 'admin') {
          return;
        }

        final notification = message.notification;
        final title =
            notification?.title ??
            message.data['title']?.toString() ??
            AppLocalizations.trStatic('notif_attendance_reminder_title');
        final body =
            notification?.body ??
            message.data['body']?.toString() ??
            AppLocalizations.trStatic('notif_attendance_reminder_body');

        await NotificationStorageService.addNotification(
          NotificationItem(
            id:
                message.messageId ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            body: body,
            timestamp: DateTime.now(),
            isRead: false,
            type: message.data['type']?.toString() ?? 'attendance',
            data: message.data,
          ),
        );

        // `onMessage` ilova haqiqiy old planda (resumed) bo'lmasa ham
        // ishga tushishi mumkin (masalan ilova xotirada, lekin ekranda
        // emas). Xabarda `notification` payload bo'lsa, bu holatda ham
        // Android tizimi uni tray'ga o'zi chiqaradi — background
        // handler'dagi kabi qo'lda ko'rsatsak, ikkitalab chiqib qoladi.
        final bool hasNotificationPayload = notification != null;
        final bool isForegroundVisible =
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
        if (hasNotificationPayload && !isForegroundVisible) {
          return;
        }

        final int notifId = DateTime.now().microsecondsSinceEpoch.remainder(
          2147483647,
        );
        await _localNotifications.show(
          id: notifId,
          title: title,
          body: body,
          payload: jsonEncode(message.data),
          notificationDetails: detailsFor(message.data['type']?.toString()),
        );
      });
    } catch (_) {}
  }

  /// Displays a test notification with custom sound to verify permissions and audio playback on device
  static Future<void> showTestNotification() async {
    final int notifId = DateTime.now().microsecondsSinceEpoch.remainder(
      2147483647,
    );
    await _localNotifications.show(
      id: notifId,
      title: AppLocalizations.trStatic('notif_test_title'),
      body: AppLocalizations.trStatic('notif_test_body'),
      payload: jsonEncode({
        'action': 'open_attendance',
        'type': 'attendance_reminder',
      }),
      notificationDetails: detailsFor('attendance_reminder'),
    );
  }

  /// Synchronizes FCM Topic subscription based on current user role.
  /// - Hodim -> Subscribes to 'hodimlar' topic.
  /// - Rahbar (admin) -> Unsubscribes from 'hodimlar' topic.
  static Future<void> syncUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role');

      if (role == 'admin') {
        await _messaging.unsubscribeFromTopic('hodimlar');
      } else {
        await _messaging.subscribeToTopic('hodimlar');
      }
    } catch (_) {}
  }

  /// Fetches the current FCM Token
  static Future<String?> printToken() async {
    try {
      if (Platform.isIOS) {
        String? apns = await _messaging.getAPNSToken();
        if (apns == null) {
          await Future.delayed(const Duration(seconds: 2));
          apns = await _messaging.getAPNSToken();
        }
      }

      final token = await _messaging.getToken();
      return token;
    } catch (_) {
      return null;
    }
  }

  static bool hasPendingCheckIn = false;

  /// Handles notification tap action.
  /// If action is 'open_attendance' or type is 'attendance_reminder':
  /// - If logged in: navigates directly to the Attendance / Check-In screen.
  /// - If not logged in: redirects directly to Login screen (/login).
  static Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    final action = data['action']?.toString();

    if (type == 'attendance_reminder' || action == 'open_attendance') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone');
        final rahbarToken = prefs.getString('rahbar_token');
        final userRole = prefs.getString('user_role');

        final bool isLoggedIn =
            (userRole == 'admin' &&
                rahbarToken != null &&
                rahbarToken.isNotEmpty) ||
            (phone != null && phone.isNotEmpty);

        if (!isLoggedIn) {
          hasPendingCheckIn = false;
          try {
            AppRouter.router.go('/login');
          } catch (_) {}
          return;
        }

        hasPendingCheckIn = true;
        try {
          unawaited(AppRouter.router.push('/check-in', extra: true));
        } catch (_) {}
      } catch (_) {}
    }
  }

  /// Registers/Updates current FCM token on backend:
  /// POST /api/bot/staff/fcm-token
  static Future<void> registerTokenOnBackend({
    String? phone,
    int? staffId,
    String? token,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final staffPhone =
          phone ?? prefs.getString('phone') ?? prefs.getString('staff_phone');
      final role = prefs.getString('user_role');

      // Do not register FCM token under staff endpoint if user is Rahbar (admin)
      if (role == 'admin') {
        debugPrint(
          'ℹ️ [FCM REGISTER] Rahbar (admin) roli uchun token xodimlar bazasiga yozilmaydi',
        );
        return;
      }

      if (staffPhone == null || staffPhone.isEmpty) {
        debugPrint(
          '⚠️ [FCM REGISTER] Telefon raqam topilmadi, token ro\'yxatdan o\'tkazilmadi',
        );
        return;
      }

      final fcmToken = token ?? await _messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ [FCM REGISTER] FCM token olinmadi (null yoki bo\'sh)');
        return;
      }

      final id = staffId ?? prefs.getInt('staff_id');
      final deviceType = Platform.isIOS ? 'ios' : 'android';

      String? deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId =
            'dev_${DateTime.now().millisecondsSinceEpoch}_${fcmToken.hashCode.abs()}';
        await prefs.setString('device_id', deviceId);
      }

      var cleanPhone = staffPhone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length == 9) {
        cleanPhone = '998$cleanPhone';
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final url = '${ApiConstants.baseUrl}${ApiConstants.staffFcmToken}';

      final body = <String, dynamic>{
        'phone': cleanPhone,
        if (id != null && id > 0) 'id': id,
        'fcm_token': fcmToken,
        'token': fcmToken,
        'device_type': deviceType,
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
      };

      debugPrint(
        '📡 [FCM REGISTER] So\'rov yuborilmoqda -> Tel: $cleanPhone | ID: $id | Token: ${fcmToken.substring(0, fcmToken.length > 20 ? 20 : fcmToken.length)}...',
      );
      if (kDebugMode) {
        debugPrint('🔑 [FCM FULL TOKEN] $fcmToken');
      }

      var response = await dio.post(
        url,
        data: jsonEncode(body),
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      // Agar ID noto'g'ri bo'lib 404 (Xodim topilmadi) bersa, faqat phone bilan qayta yuborib ko'ramiz
      if (response.statusCode == 404 && id != null) {
        debugPrint(
          '⚠️ [FCM REGISTER] ID bilan topilmadi (404), faqat telefon raqami bilan qayta yuborilmoqda...',
        );
        final retryBody = <String, dynamic>{
          'phone': cleanPhone,
          'fcm_token': fcmToken,
          'token': fcmToken,
          'device_type': deviceType,
          if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
        };
        response = await dio.post(
          url,
          data: jsonEncode(retryBody),
          options: Options(
            contentType: Headers.jsonContentType,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );
      }

      final bool isSuccess =
          (response.statusCode == 200 || response.statusCode == 201) &&
          (response.data is Map &&
              (response.data['status'] == 'success' ||
                  response.data['status'] == 'ok'));

      if (isSuccess) {
        await prefs.setString('last_fcm_token_registered', fcmToken);
        debugPrint(
          '📡 [FCM REGISTER] Qabul qilindi ✅ -> Tel: $cleanPhone | Status: ${response.statusCode} | Javob: ${response.data}',
        );
      } else {
        debugPrint(
          '❌ [FCM REGISTER XATO] Server qabul qilmadi! Status: ${response.statusCode} | Javob: ${response.data} | Tel: $cleanPhone',
        );
      }
    } catch (e) {
      debugPrint('❌ [FCM REGISTER TARMOQ XATOSI]: $e');
    }
  }

  /// Deactivates FCM token on backend on logout:
  /// DELETE /api/bot/staff/fcm-token
  static Future<void> deleteTokenFromBackend({
    String? phone,
    int? staffId,
    String? token,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final staffPhone =
          phone ?? prefs.getString('phone') ?? prefs.getString('staff_phone');
      if (staffPhone == null || staffPhone.isEmpty) return;

      final fcmToken = token ?? await _messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      final id = staffId ?? prefs.getInt('staff_id');

      var cleanPhone = staffPhone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length == 9) {
        cleanPhone = '998$cleanPhone';
      }

      final deleteBody = <String, dynamic>{
        'phone': cleanPhone,
        if (id != null && id > 0) 'id': id,
        'fcm_token': fcmToken,
        'token': fcmToken,
      };

      final dio = Dio();
      final url = '${ApiConstants.baseUrl}${ApiConstants.staffFcmToken}';
      await dio.delete(
        url,
        data: jsonEncode(deleteBody),
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 600,
        ),
      );
    } catch (_) {}
  }
}
