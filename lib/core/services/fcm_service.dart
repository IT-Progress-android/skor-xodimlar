import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_cubit.dart';
import 'package:skore_hodimlar/core/models/notification_model.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';
import 'package:skore_hodimlar/core/services/notification_storage_service.dart';
import 'package:skore_hodimlar/core/services/push_dedup.dart';
import 'package:skore_hodimlar/features/applications/presentation/ariza_refresh.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/rahbar_map_focus.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_refresh.dart';
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
    debugPrint(
      '[PUSH] ${DateTime.now().toIso8601String()} keldi (fon) '
      'rol=$role id=${message.messageId} '
      'title="${message.notification?.title}" '
      'channel=${message.notification?.android?.channelId} '
      'data=${jsonEncode(message.data)} '
      'korsatiladi=${FcmService.shouldHandle(role, message.data['type']?.toString())}',
    );
    if (!FcmService.shouldHandle(role, message.data['type']?.toString())) {
      return;
    }

    // Bu alohida background izolyator — LanguageCubit hech qachon ishga
    // tushmaydi, shuning uchun saqlangan tilni qo'lda yuklaymiz.
    AppLocalizations.setCurrentLanguage(
      AppLanguage.fromCode(prefs.getString(LanguageCubit.prefKey)),
    );

    // Server sessiyani yopdi — fon GPS servisi keyingi tikda o'zi to'xtaydi.
    if (message.data['type']?.toString() == 'auto_ketdi') {
      await FlutterForegroundTask.saveData(key: workSessionUntilKey, value: 0);
    }

    // Matnsiz push (faqat signal) ko'rsatilmaydi — ilova o'zidan tayyor
    // matn qo'ymaydi. Bir xil davomat eslatmasi kuniga bir marta.
    if (!FcmService.hasDisplayText(message) ||
        !await claimPushDisplay(message.data['type']?.toString())) {
      debugPrint('[PUSH] takroriy/ko\'rsatilmaydigan — e\'tiborsiz');
      return;
    }

    final bool hasNotificationPayload = message.notification != null;
    final rawTitle =
        message.notification?.title ?? message.data['title']?.toString() ?? '';
    final rawBody =
        message.notification?.body ?? message.data['body']?.toString() ?? '';

    // 2. Android Notification Kanallarini background izolatorida KAFOLATLI yaratish (Skor Maktab kabi)
    final FlutterLocalNotificationsPlugin flnp =
        FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@drawable/ic_stat_skor');
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
      for (final ch in FcmService.allChannels) {
        await androidImpl.createNotificationChannel(ch);
      }
    }

    final title = rawTitle;
    final body = rawBody;

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
    await flnp.show(
      id: FcmService.notificationIdFor(message.data, DateTime.now()),
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

  /// Topshiriq pushlari davomat eslatmasi kabi to'liq bildirishnoma:
  /// maksimal muhimlik, ovoz, tebranish, ekran tepasida chiqadi — ilova
  /// yopiq bo'lsa ham (Android tizimi `channel_id` bo'yicha shu kanalni
  /// ishlatadi). Hamma topshiriq pushlari `task_channel` ga tushadi.
  /// `task_channel_quiet` faqat backend eski kelishuv bo'yicha shu ID'ni
  /// yuborsa ham bildirishnoma jim qolmasligi uchun xuddi shunday sozlangan.
  /// Server avtomatik "Ketdi" qilganda (`data.type: auto_ketdi`) — oddiy
  /// ustuvorlik, ovozsiz tebranish yo'q.
  static AndroidNotificationChannel get autoKetdiChannel =>
      AndroidNotificationChannel(
        'auto_ketdi_channel',
        AppLocalizations.trStatic('notif_channel_auto_ketdi_name'),
        description: AppLocalizations.trStatic('notif_channel_auto_ketdi_desc'),
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: false,
      );

  /// Davomatdan o'tishdan boshqa barcha xabarlar (eslatmalar, xodimga
  /// lokatsiya/batareya ogohlantirishi va h.k.) — telefonning standart
  /// ovozi bilan. Maxsus `davomat_sound` faqat davomat xabarida.
  static AndroidNotificationChannel get generalChannel =>
      AndroidNotificationChannel(
        'general_channel',
        AppLocalizations.trStatic('notif_channel_general_name'),
        description: AppLocalizations.trStatic('notif_channel_general_desc'),
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  /// Rahbarga "xodim lokatsiyani o'chirdi/yoqdi". ID backend pushdagi
  /// `android.channel_id` bilan bir xil — ilova yopiq bo'lsa ham tizim shu
  /// kanalni (standart ovoz) ishlatadi.
  static AndroidNotificationChannel get locationAlertChannel =>
      AndroidNotificationChannel(
        'location_alert_channel',
        AppLocalizations.trStatic('notif_channel_location_name'),
        description: AppLocalizations.trStatic('notif_channel_location_desc'),
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  /// Ilova yaratadigan barcha kanallar (asosiy va fon izolyatorlari).
  static List<AndroidNotificationChannel> get allChannels => [
    _channel,
    _reviewChannel,
    autoKetdiChannel,
    generalChannel,
    locationAlertChannel,
    ...taskChannels,
  ];

  /// Maxsus `davomat_sound` faqat davomatdan o'tish xabarida (`type`
  /// berilmagan yoki `attendance`).
  static bool isAttendancePush(String? type) =>
      type == null || type.isEmpty || type == 'attendance';

  static List<AndroidNotificationChannel> get taskChannels => [
    AndroidNotificationChannel(
      'task_channel',
      AppLocalizations.trStatic('notif_channel_task_name'),
      description: AppLocalizations.trStatic('notif_channel_task_desc'),
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
    AndroidNotificationChannel(
      'task_channel_quiet',
      AppLocalizations.trStatic('notif_channel_task_quiet_name'),
      description: AppLocalizations.trStatic('notif_channel_task_quiet_desc'),
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
  ];

  /// Rahbarga mo'ljallangan push turlari.
  static const _rahbarTypes = {
    'task_done',
    'location_alert',
    'ariza_new',
    'absent_alert',
  };

  /// Rahbar (admin) faqat o'ziga mo'ljallangan pushlarni ("xodim bajardi",
  /// "xodim lokatsiyasi uzildi") oladi; xodim esa ulardan tashqari hammasini.
  static bool shouldHandle(String? role, String? type) {
    if (role == 'admin') return _rahbarTypes.contains(type);
    return !_rahbarTypes.contains(type);
  }

  /// Ilova o'zi ko'rsatadigan bildirishnoma ID'si. Bitta xodimning GPS
  /// xabarlari (`location_alert`) bitta ID'da — yangisi eskisining o'rnini
  /// oladi. Aks holda ular to'planib, Android'ning ilova uchun 50 ta
  /// chegarasiga yetadi va keyingi (masalan, ariza) bildirishnomalar umuman
  /// ko'rsatilmaydi.
  static int notificationIdFor(Map<String, dynamic> data, DateTime now) {
    if (data['type'] == 'location_alert') {
      final staffId = int.tryParse('${data['staff_id']}');
      if (staffId != null) return 1000000000 + staffId % 100000000;
    }
    return now.microsecondsSinceEpoch.remainder(1000000000);
  }

  /// Xabar turiga qarab mos bildirishnoma sozlamasini tanlaydi.
  /// Backend `data.type` da `manual_review` yuborsa — sokin kanal.
  static NotificationDetails detailsFor(String? type) {
    if (type != null && type.startsWith('task_')) {
      final ch = taskChannels.first;
      return NotificationDetails(
        android: AndroidNotificationDetails(
          ch.id,
          ch.name,
          channelDescription: ch.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@drawable/ic_stat_skor',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
    }
    if (type == 'auto_ketdi') {
      final ch = autoKetdiChannel;
      return NotificationDetails(
        android: AndroidNotificationDetails(
          ch.id,
          ch.name,
          channelDescription: ch.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_stat_skor',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
    }
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
          icon: '@drawable/ic_stat_skor',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
    }
    if (!isAttendancePush(type)) {
      final ch = type == 'location_alert'
          ? locationAlertChannel
          : generalChannel;
      return NotificationDetails(
        android: AndroidNotificationDetails(
          ch.id,
          ch.name,
          channelDescription: ch.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_stat_skor',
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
        icon: '@drawable/ic_stat_skor',
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
      final settings = await _messaging.getNotificationSettings();
      final enabled = await androidImplementation?.areNotificationsEnabled();
      debugPrint(
        '[PUSH] ruxsat=${settings.authorizationStatus.name} '
        'android_yoqilgan=$enabled',
      );

      // 2. Setup Local Notifications for Foreground display
      const androidInit = AndroidInitializationSettings(
        '@drawable/ic_stat_skor',
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

      // Ilova hech qanday mahalliy (rejalashtirilgan) bildirishnoma
      // qo'ymaydi — eski versiyadan qolgan bo'lsa, o'chiriladi.
      await _localNotifications.cancelAllPendingNotifications();

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

      // Kanallar: davomat (maxsus ovoz) va qolganlari (standart ovoz).
      final androidChannels = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      for (final ch in allChannels) {
        await androidChannels?.createNotificationChannel(ch);
      }

      // 3. Set foreground presentation options (iOS)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 5. Eski `hodimlar` topic obunasini bekor qilish — kutmaymiz: FCM
      // ro'yxatdan o'tolmagan telefonda topic so'rovi qotib qolishi mumkin.
      unawaited(syncUserRole());

      // 7. Listen to token refreshes and auto-update on backend
      _messaging.onTokenRefresh.listen((newToken) {
        registerTokenOnBackend(token: newToken);
        registerRahbarTokenOnBackend(token: newToken);
      });

      // 8. Handle notification tap when app opened from background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (message.data['type']?.toString().startsWith('task_') ?? false) {
          debugPrint(
            '[TOPSHIRIQ PUSH] bosildi (fon) data=${jsonEncode(message.data)}',
          );
        }
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
        final msgType = message.data['type']?.toString();
        // Server sessiyani avtomatik yopdi — GPS'ni keyingi ping'ni
        // kutmasdan to'xtatamiz.
        if (msgType == 'auto_ketdi') {
          unawaited(
            GpsLiveTrackerService.instance.syncWorkSession(active: false),
          );
        }
        debugPrint(
          '[PUSH] ${DateTime.now().toIso8601String()} keldi '
          '(ilova ochiq) rol=$role id=${message.messageId} '
          'title="${message.notification?.title}" '
          'channel=${message.notification?.android?.channelId} '
          'data=${jsonEncode(message.data)} '
          'korsatiladi=${shouldHandle(role, msgType)}',
        );
        if (!shouldHandle(role, msgType)) {
          return;
        }
        // Ochiq topshiriq sahifasi darhol yangilansin.
        if (msgType?.startsWith('task_') ?? false) {
          final taskId = int.tryParse('${message.data['task_id'] ?? ''}');
          if (taskId != null) taskPushes.add(taskId);
        }
        // Ochiq ariza ro'yxati darhol yangilansin.
        if (msgType == 'ariza_new' || msgType == 'manual_review') {
          arizaPushes.add(msgType!);
        }
        // Matnsiz push (faqat signal) ko'rsatilmaydi — ilova o'zidan tayyor
        // matn qo'ymaydi. Bir xil davomat eslatmasi kuniga bir marta.
        if (!hasDisplayText(message) || !await claimPushDisplay(msgType)) {
          debugPrint('[PUSH] takroriy/ko\'rsatilmaydigan — e\'tiborsiz');
          return;
        }

        final notification = message.notification;
        final title =
            notification?.title ?? message.data['title']?.toString() ?? '';
        final body =
            notification?.body ?? message.data['body']?.toString() ?? '';

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
        // iOS `setForegroundNotificationPresentationOptions(alert: true)`
        // tufayli `notification` payload'li xabarni ilova ochiq paytda ham
        // o'zi ko'rsatadi — qo'lda ham ko'rsatsak, ikkitalab chiqadi.
        if (hasNotificationPayload && Platform.isIOS) {
          return;
        }

        await _localNotifications.show(
          id: notificationIdFor(message.data, DateTime.now()),
          title: title,
          body: body,
          payload: jsonEncode(message.data),
          notificationDetails: detailsFor(message.data['type']?.toString()),
        );
      });
      debugPrint('[PUSH] tinglovchilar ulandi (onMessage, onMessageOpenedApp)');

      // 6. Token olish va serverga yozish ENG OXIRIDA: bu tarmoq so'rovlari
      // uzoq qotishi yoki xato berishi mumkin. Ilgari ular tinglovchilardan
      // oldin edi — xato bo'lsa catch onMessage ulanmasdan chiqib ketardi va
      // ilova ochiq paytda kelgan pushlar jim yo'qolardi.
      final currentToken = await printToken();
      debugPrint(
        '[PUSH] joriy token: ${currentToken == null ? 'YO\'Q' : '…${currentToken.substring(currentToken.length - 12)}'}',
      );
      if (currentToken != null) {
        await registerTokenOnBackend(token: currentToken);
        await registerRahbarTokenOnBackend(token: currentToken);
      }
    } catch (e, st) {
      debugPrint('[PUSH] ❌ FcmService.init xatosi: $e\n$st');
    }
  }

  /// Eski `hodimlar` topic obunasini bekor qiladi (rol almashganda ham
  /// chaqiriladi, shuning uchun nomi o'zgartirilmadi).
  static Future<void> syncUserRole() async {
    try {
      // Backend `hodimlar` topic'iga hech qachon yubormaydi (barcha pushlar
      // shaxsiy tokenga ketadi). Eski versiyalardagi obunani bekor qilamiz.
      await _messaging
          .unsubscribeFromTopic('hodimlar')
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// FCM token, qotib qolmasligi uchun vaqt chegarasi bilan. Olinmasa `null`.
  static Future<String?> _safeToken() async {
    try {
      return await _messaging.getToken().timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('⚠️ [FCM] Token olinmadi: $e');
      return null;
    }
  }

  /// Fetches the current FCM Token
  static Future<String?> printToken() async {
    try {
      if (Platform.isIOS) {
        String? apns = await _messaging.getAPNSToken().timeout(
          const Duration(seconds: 5),
        );
        if (apns == null) {
          await Future.delayed(const Duration(seconds: 2));
          apns = await _messaging.getAPNSToken().timeout(
            const Duration(seconds: 5),
          );
        }
      }

      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 15),
      );
      return token;
    } catch (e) {
      debugPrint('⚠️ [FCM] Token olinmadi: $e');
      return null;
    }
  }

  /// Push'da server yuborgan sarlavha yoki matn bormi.
  static bool hasDisplayText(RemoteMessage m) {
    String t(String? v) => (v ?? '').trim();
    return t(m.notification?.title).isNotEmpty ||
        t(m.notification?.body).isNotEmpty ||
        t(m.data['title']?.toString()).isNotEmpty ||
        t(m.data['body']?.toString()).isNotEmpty;
  }

  static bool hasPendingCheckIn = false;

  /// Hisobdan chiqishda `prefs.clear()` o'rniga chaqiriladi: `device_id`
  /// saqlanib qoladi. Aks holda keyingi kirishda yangi id yaratiladi va
  /// backend bitta telefonni yangi qurilma deb, eski tokenini o'chirmaydi.
  static Future<void> clearPrefsKeepingDeviceId(SharedPreferences prefs) async {
    final deviceId = prefs.getString('device_id');
    await prefs.clear();
    if (deviceId != null && deviceId.isNotEmpty) {
      await prefs.setString('device_id', deviceId);
    }
  }

  /// Handles notification tap action.
  /// If action is 'open_attendance' or type is 'attendance_reminder':
  /// - If logged in: navigates directly to the Attendance / Check-In screen.
  /// - If not logged in: redirects directly to Login screen (/login).
  static Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    final action = data['action']?.toString();

    if (action == 'open_task' || (type?.startsWith('task_') ?? false)) {
      await openTaskFromData(data);
      return;
    }

    // Rahbarga: xodim lokatsiyasi uzildi / tiklandi — xaritada o'sha xodim.
    if (type == 'location_alert') {
      final staffId = int.tryParse('${data['staff_id'] ?? ''}');
      if (staffId != null) rahbarMapFocusStaff.value = staffId;
      try {
        AppRouter.router.go('/rahbar');
      } catch (_) {}
      return;
    }

    // Xodimga: arizasi tasdiqlandi / rad etildi — arizalar ro'yxati.
    if (type == 'manual_review' && data['ariza_id'] != null) {
      try {
        AppRouter.router.go('/applications');
      } catch (_) {}
      return;
    }

    // Rahbarga: yangi ariza / smenada kelmagan xodimlar — bosh sahifa
    // tegishli ro'yxatni ochadi.
    if (rahbarOpenRequestFor(data) case final request?) {
      rahbarOpenRequest.value = request;
      try {
        AppRouter.router.go('/rahbar');
      } catch (_) {}
      return;
    }

    // Xodimga: "lokatsiyani yoqing" / "telefonni quvvatlang" — ilova
    // ochilganda lokatsiya ekrani o'zi kerakli tugmani ko'rsatadi.
    if (type == 'location_warning' || type == 'battery_low') {
      try {
        AppRouter.router.go('/');
      } catch (_) {}
      return;
    }

    // Smena tugashi eslatmasi va avto-ketdi: bosh sahifa ochiladi, u yerda
    // davomat yangilanadi va kerak bo'lsa xodim "Keldim" bosadi.
    if (type == 'shift_end_reminder' || type == 'auto_ketdi') {
      try {
        AppRouter.router.go('/');
      } catch (_) {}
      return;
    }

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
  }) {
    // Chaqiruvlar ketma-ket bajariladi: init, splash va home bir vaqtda
    // chaqirganda bitta so'rov ketadi, qolganlari [_staffRegisteredKey]
    // bo'yicha o'tkazib yuboriladi.
    final next = _staffRegisterQueue.then(
      (_) =>
          _registerTokenOnBackend(phone: phone, staffId: staffId, token: token),
    );
    _staffRegisterQueue = next;
    return next;
  }

  static Future<void> _staffRegisterQueue = Future.value();

  /// Shu sessiyada muvaffaqiyatli yozilgan `telefon|token` jufti.
  static String? _staffRegisteredKey;

  static Future<void> _registerTokenOnBackend({
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
          'ℹ️ [FCM REGISTER] Xodim hali kirmagan — token xodim kirgandan keyin avtomatik yoziladi',
        );
        return;
      }

      final fcmToken = token ?? await _safeToken();
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

      final registeredKey = '$cleanPhone|$fcmToken';
      if (_staffRegisteredKey == registeredKey) return;

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
        if (deviceId.isNotEmpty) 'device_id': deviceId,
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
          if (deviceId.isNotEmpty) 'device_id': deviceId,
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
        _staffRegisteredKey = registeredKey;
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

  /// Push `data` sidagi `task_id` bo'yicha topshiriqni ochadi: rahbarga
  /// rahbar tafsiloti, xodimga xodim tafsiloti. Bildirishnomalar ro'yxatidan
  /// ham chaqiriladi.
  static Future<void> openTaskFromData(Map<String, dynamic> data) async {
    final id = int.tryParse(data['task_id']?.toString() ?? '');
    // Shu topshiriq sahifasi allaqachon ochiq bo'lsa — yangilansin.
    if (id != null) taskPushes.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAdmin =
          prefs.getString('user_role') == 'admin' &&
          (prefs.getString('rahbar_token') ?? '').isNotEmpty;
      final phone = prefs.getString('phone');
      if (!isAdmin && (phone == null || phone.isEmpty)) {
        AppRouter.router.go('/login');
        return;
      }
      if (id == null || id <= 0) {
        if (!isAdmin) AppRouter.router.go('/tasks');
        return;
      }
      unawaited(
        AppRouter.router.push(isAdmin ? '/rahbar/topshiriq/$id' : '/tasks/$id'),
      );
    } catch (_) {}
  }

  /// Rahbar FCM tokenini saqlaydi: POST /rahbar/fcm-token.
  /// Rahbar bo'lmasa hech narsa qilmaydi.
  static Future<void> registerRahbarTokenOnBackend({String? token}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rahbarToken = prefs.getString('rahbar_token') ?? '';
      if (prefs.getString('user_role') != 'admin' || rahbarToken.isEmpty) {
        return;
      }
      final fcmToken = token ?? await _safeToken();
      if (fcmToken == null || fcmToken.isEmpty) return;
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId =
            'dev_${DateTime.now().millisecondsSinceEpoch}_${fcmToken.hashCode.abs()}';
        await prefs.setString('device_id', deviceId);
      }
      final res = await _rahbarDio(rahbarToken).post(
        '${ApiConstants.baseUrl}${ApiConstants.rahbarFcmToken}',
        data: jsonEncode({
          'fcm_token': fcmToken,
          'device_type': Platform.isIOS ? 'ios' : 'android',
          'device_id': deviceId,
        }),
      );
      debugPrint(
        '[TOPSHIRIQ API] 📡 [RAHBAR FCM REGISTER] Status: ${res.statusCode} | Javob: ${res.data}',
      );
      if (kDebugMode) {
        debugPrint('[TOPSHIRIQ API] 🔑 [RAHBAR FCM FULL TOKEN] $fcmToken');
      }
    } catch (e) {
      debugPrint('[TOPSHIRIQ API] ❌ [RAHBAR FCM REGISTER XATOSI]: $e');
    }
  }

  /// Rahbar chiqishida tokenni o'chiradi: DELETE /rahbar/fcm-token.
  /// `rahbar_token` hali tozalanmagan paytda chaqirilishi kerak.
  static Future<void> deleteRahbarTokenFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rahbarToken = prefs.getString('rahbar_token') ?? '';
      if (rahbarToken.isEmpty) return;
      final fcmToken = await _safeToken();
      if (fcmToken == null || fcmToken.isEmpty) return;
      await _rahbarDio(rahbarToken).delete(
        '${ApiConstants.baseUrl}${ApiConstants.rahbarFcmToken}',
        data: jsonEncode({'fcm_token': fcmToken}),
      );
    } catch (_) {}
  }

  static Dio _rahbarDio(String rahbarToken) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      validateStatus: (status) => status != null && status < 600,
      contentType: Headers.jsonContentType,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $rahbarToken',
      },
    ),
  );

  /// Deactivates FCM token on backend on logout:
  /// DELETE /api/bot/staff/fcm-token
  static Future<void> deleteTokenFromBackend({
    String? phone,
    int? staffId,
    String? token,
  }) async {
    _staffRegisteredKey = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final staffPhone =
          phone ?? prefs.getString('phone') ?? prefs.getString('staff_phone');
      if (staffPhone == null || staffPhone.isEmpty) return;

      final fcmToken = token ?? await _safeToken();
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
