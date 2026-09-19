import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/services/notification_storage_service.dart';

class NotificationBellButton extends StatelessWidget {
  final VoidCallback? onCustomTap;

  const NotificationBellButton({super.key, this.onCustomTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationStorageService.unreadCountNotifier,
      builder: (context, unreadCount, _) {
        return Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Tooltip(
            message: context.tr('notif_title'),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () async {
                if (onCustomTap != null) {
                  onCustomTap!();
                } else {
                  await context.push('/notifications');
                  unawaited(NotificationStorageService.refreshUnreadCount());
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: unreadCount > 0
                        ? const Color(0xFF0D6E6E).withValues(alpha: 0.2)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      unreadCount > 0
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: const Color(0xFF0D6E6E),
                      size: 22,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
