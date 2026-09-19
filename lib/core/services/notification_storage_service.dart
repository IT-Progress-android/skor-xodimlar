import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/models/notification_model.dart';

class NotificationStorageService {
  static const String _storageKey = 'in_app_notifications_list';
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Initializes the service and purges any legacy sample notifications.
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final realNotifications = decoded.where((item) {
          final id = item['id']?.toString() ?? '';
          return !id.startsWith('default_');
        }).toList();
        await prefs.setString(_storageKey, jsonEncode(realNotifications));
      }
      await refreshUnreadCount();
    } catch (_) {}
  }

  /// Recalculates unread notifications count and notifies listeners
  static Future<int> refreshUnreadCount() async {
    try {
      final list = await getNotifications();
      final count = list.where((n) => !n.isRead).length;
      unreadCountNotifier.value = count;
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Returns all stored notifications sorted newest first
  static Future<List<NotificationItem>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return [];
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .map(
            (item) => NotificationItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Adds a new notification to the top of the list and updates unread badge
  static Future<void> addNotification(NotificationItem item) async {
    try {
      final list = await getNotifications();
      // Prepend the new notification
      list.insert(0, item);
      // Keep up to 100 recent notifications
      if (list.length > 100) {
        list.removeRange(100, list.length);
      }
      await _saveList(list);
      await refreshUnreadCount();
    } catch (_) {}
  }

  /// Marks a specific notification as read
  static Future<void> markAsRead(String id) async {
    try {
      final list = await getNotifications();
      final index = list.indexWhere((n) => n.id == id);
      if (index != -1 && !list[index].isRead) {
        list[index] = list[index].copyWith(isRead: true);
        await _saveList(list);
        await refreshUnreadCount();
      }
    } catch (_) {}
  }

  /// Marks all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final list = await getNotifications();
      final updated = list.map((n) => n.copyWith(isRead: true)).toList();
      await _saveList(updated);
      unreadCountNotifier.value = 0;
    } catch (_) {}
  }

  /// Deletes a specific notification by ID
  static Future<void> deleteNotification(String id) async {
    try {
      final list = await getNotifications();
      list.removeWhere((n) => n.id == id);
      await _saveList(list);
      await refreshUnreadCount();
    } catch (_) {}
  }

  /// Clears all notifications
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      unreadCountNotifier.value = 0;
    } catch (_) {}
  }

  static Future<void> _saveList(List<NotificationItem> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
