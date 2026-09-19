import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/services/network_connectivity_service.dart';
import 'package:skore_hodimlar/core/widgets/offline_info_bottom_sheet.dart';

/// Butun ilova bo'ylab internet yo'qolganda yuqoridan zamonaviy tarzda
/// tushadigan va aloqa tiklanganda yashil bo'lib avtomatik yo'qoladigan
/// Dynamic Island uslubidagi suzuvchi banner.
class GlobalOfflineBanner extends StatefulWidget {
  final Widget child;

  const GlobalOfflineBanner({required this.child, super.key});

  @override
  State<GlobalOfflineBanner> createState() => _GlobalOfflineBannerState();
}

class _GlobalOfflineBannerState extends State<GlobalOfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _restoredHideTimer;
  bool _wasOffline = false;
  bool _showRestoredState = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    NetworkConnectivityService.instance.isOnlineNotifier.addListener(
      _handleConnectivityChange,
    );

    // Initial check
    if (NetworkConnectivityService.instance.isOffline) {
      _wasOffline = true;
      _animController.forward();
    }
  }

  void _handleConnectivityChange() {
    final isOnline = NetworkConnectivityService.instance.isOnline;

    if (!isOnline) {
      // Internet uzildi -> darhol qizil bannerni chiqaramiz
      _restoredHideTimer?.cancel();
      setState(() {
        _wasOffline = true;
        _showRestoredState = false;
      });
      _animController.forward();
    } else if (_wasOffline) {
      // Internet tiklandi -> 2.5 soniya yashil ko'rsatib keyin yashiramiz
      setState(() {
        _showRestoredState = true;
      });

      _restoredHideTimer?.cancel();
      _restoredHideTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          _animController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _wasOffline = false;
                _showRestoredState = false;
              });
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _restoredHideTimer?.cancel();
    NetworkConnectivityService.instance.isOnlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        // Asosiy ilova ekrani
        widget.child,

        // Suzuvchi Dynamic Island banneri
        Positioned(
          top: topPadding > 0 ? topPadding + 6 : 14,
          left: 14,
          right: 14,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  // Foydalanuvchi tepaga siljitib qo'lda yashira oladi
                  if (details.primaryDelta != null &&
                      details.primaryDelta! < -4) {
                    _animController.reverse();
                  }
                },
                onTap: () {
                  if (!_showRestoredState) {
                    OfflineInfoBottomSheet.show(context);
                  }
                },
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _showRestoredState
                                ? const [Color(0xFF16A34A), Color(0xFF0D9488)]
                                : const [Color(0xFFDC2626), Color(0xFF991B1B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_showRestoredState
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFDC2626))
                                      .withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Icon container
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _showRestoredState
                                    ? Icons.wifi_rounded
                                    : Icons.wifi_off_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Matnlar
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _showRestoredState
                                        ? context.tr(
                                            'offline_banner_restored_title',
                                          )
                                        : context.tr(
                                            'offline_banner_offline_title',
                                          ),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    _showRestoredState
                                        ? context.tr(
                                            'offline_banner_restored_desc',
                                          )
                                        : context.tr(
                                            'offline_banner_offline_desc',
                                          ),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Amallar (Faqat offline holatda ko'rinadi)
                            if (!_showRestoredState) ...[
                              ValueListenableBuilder<bool>(
                                valueListenable: NetworkConnectivityService
                                    .instance
                                    .isCheckingNotifier,
                                builder: (context, isChecking, _) {
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: isChecking
                                        ? null
                                        : NetworkConnectivityService
                                              .instance
                                              .checkConnection,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: isChecking
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.refresh_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                    ),
                                  );
                                },
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () =>
                                    OfflineInfoBottomSheet.show(context),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
