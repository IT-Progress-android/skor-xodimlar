import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/models/notification_model.dart';
import 'package:skore_hodimlar/core/services/notification_storage_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'attendance', 'system'

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final items = await NotificationStorageService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    }
  }

  List<NotificationItem> get _filteredNotifications {
    if (_selectedFilter == 'all') return _notifications;
    return _notifications.where((n) => n.type == _selectedFilter).toList();
  }

  int _countFor(String filter) {
    if (filter == 'all') return _notifications.length;
    return _notifications.where((n) => n.type == filter).length;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return context.tr('notif_just_now');
    } else if (difference.inMinutes < 60) {
      return context.tr('notif_minutes_ago', {
        'minutes': '${difference.inMinutes}',
      });
    } else if (difference.inHours < 24 && dt.day == now.day) {
      return context.tr('notif_today_at', {
        'time': DateFormat('HH:mm').format(dt),
      });
    } else if (difference.inDays == 1 ||
        (difference.inHours < 48 && dt.day == now.day - 1)) {
      return context.tr('notif_yesterday_at', {
        'time': DateFormat('HH:mm').format(dt),
      });
    } else {
      return DateFormat('dd.MM.yyyy, HH:mm').format(dt);
    }
  }

  Future<void> _markAllAsRead() async {
    await NotificationStorageService.markAllAsRead();
    await _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('notif_all_marked_read'),
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF0D6E6E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('notif_clear_all_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.tr('notif_clear_all_confirm'),
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr('cancel'),
              style: GoogleFonts.outfit(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.tr('notif_clear'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationStorageService.clearAll();
      await _loadNotifications();
    }
  }

  Future<void> _handleNotificationTap(NotificationItem item) async {
    if (!item.isRead) {
      await NotificationStorageService.markAsRead(item.id);
      await _loadNotifications();
    }

    if (!mounted) return;

    // Show details modal bottom sheet
    unawaited(
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => _buildDetailBottomSheet(item, ctx),
      ),
    );
  }

  Widget _buildDetailBottomSheet(NotificationItem item, BuildContext ctx) {
    final isAttendance = item.type == 'attendance';
    final bottomPadding = MediaQuery.of(ctx).padding.bottom;
    final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.9),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: bottomInset > 0
                    ? bottomInset + 16
                    : (bottomPadding > 0 ? bottomPadding + 14 : 24),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isAttendance
                                ? const Color(
                                    0xFF0D6E6E,
                                  ).withValues(alpha: 0.12)
                                : const Color(
                                    0xFF3B82F6,
                                  ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isAttendance
                                ? Icons.alarm_rounded
                                : Icons.info_outline_rounded,
                            color: isAttendance
                                ? const Color(0xFF0D6E6E)
                                : const Color(0xFF3B82F6),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(item.timestamp),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        item.body,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          height: 1.5,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isAttendance ||
                        (item.data != null &&
                            item.data?['action'] == 'open_attendance')) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D6E6E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push('/check-in', extra: true);
                          },
                          icon: const Icon(Icons.touch_app_rounded, size: 20),
                          label: Text(
                            context.tr('notif_go_to_attendance'),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await NotificationStorageService.deleteNotification(
                            item.id,
                          );
                          unawaited(_loadNotifications());
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: Color(0xFFEF4444),
                        ),
                        label: Text(
                          context.tr('notif_delete'),
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredNotifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0D6E6E),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('notif_title'),
          style: GoogleFonts.outfit(
            color: const Color(0xFF0D6E6E),
            fontWeight: FontWeight.w900,
            fontSize: 19,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0D6E6E)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (val) {
              if (val == 'read_all') _markAllAsRead();
              if (val == 'clear_all') _clearAll();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'read_all',
                child: Row(
                  children: [
                    const Icon(
                      Icons.done_all_rounded,
                      size: 18,
                      color: Color(0xFF0D6E6E),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.tr('notif_mark_all_read'),
                      style: GoogleFonts.outfit(fontSize: 13),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_sweep_rounded,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.tr('notif_clear_all_menu'),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // Filter Tabs
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _buildFilterChip(
                      'all',
                      context.tr('notif_filter_all'),
                      _countFor('all'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'attendance',
                      context.tr('notif_filter_attendance'),
                      _countFor('attendance'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'system',
                      context.tr('notif_filter_system'),
                      _countFor('system'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Content List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0D6E6E),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        color: const Color(0xFF0D6E6E),
                        child: list.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(14),
                                itemCount: list.length,
                                separatorBuilder: (ctx, idx) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = list[index];
                                  return _buildNotificationCard(item);
                                },
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, int count) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D6E6E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    final isAttendance = item.type == 'attendance';

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
      onDismissed: (_) async {
        await NotificationStorageService.deleteNotification(item.id);
        unawaited(_loadNotifications());
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleNotificationTap(item),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !item.isRead
                  ? const Color(0xFF0D6E6E).withValues(alpha: 0.35)
                  : const Color(0xFFE2E8F0),
              width: !item.isRead ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isAttendance
                      ? const Color(0xFF0D6E6E).withValues(alpha: 0.1)
                      : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAttendance
                      ? Icons.alarm_rounded
                      : Icons.notifications_rounded,
                  color: isAttendance
                      ? const Color(0xFF0D6E6E)
                      : const Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Title and body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.outfit(
                              fontWeight: !item.isRead
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 15,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(item.timestamp),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                    if (isAttendance) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0D6E6E,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.tr('notif_go_to_attendance'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D6E6E),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 12,
                                  color: Color(0xFF0D6E6E),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Unread indicator dot
              if (!item.isRead) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D6E6E),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0D6E6E).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 42,
                color: Color(0xFF0D6E6E),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('notif_empty_title'),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('notif_empty_desc'),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
