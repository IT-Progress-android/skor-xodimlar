import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String title;
  final String description;
  final List<String> releaseNotes;
  final bool isMandatory;
  final String? playStoreUrl;
  final String? appStoreUrl;

  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    this.title = '',
    this.description = '',
    this.releaseNotes = const [],
    this.isMandatory = false,
    this.playStoreUrl,
    this.appStoreUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    List<String> parseNotes(dynamic notes) {
      if (notes is List) {
        return notes
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (notes is String && notes.trim().isNotEmpty) {
        return [notes.trim()];
      }
      return [];
    }

    // Backend endi platformalarni ajratib beradi: javobda `android` va `ios`
    // alohida bloklar bo'ladi. Android va iOS build raqamlari hech qachon bir
    // xil bo'lmaydi, shuning uchun o'z platformamizning blokini o'qiymiz.
    // Eski backend bunday bloklarni yubormaydi — u holda top-level maydonlar
    // ishlatiladi (orqaga moslik).
    final platformKey = Platform.isIOS ? 'ios' : 'android';
    final platformBlock = json[platformKey] is Map
        ? Map<String, dynamic>.from(json[platformKey] as Map)
        : const <String, dynamic>{};

    dynamic pick(String key) => platformBlock[key] ?? json[key];

    return AppUpdateInfo(
      version: (pick('version') ?? json['latest_version'] ?? '1.0.8')
          .toString(),
      buildNumber: (pick('build_number') ?? json['build'] ?? 15) as int? ?? 15,
      title: (pick('title') ?? '').toString(),
      description: pick('description')?.toString() ?? '',
      releaseNotes: parseNotes(
        pick('release_notes') ?? json['notes'] ?? json['changes'],
      ),
      isMandatory: pick('is_mandatory') == true || json['force_update'] == true,
      playStoreUrl:
          pick('play_store_url')?.toString() ??
          'https://play.google.com/store/apps/details?id=uz.skor.hodimlar',
      appStoreUrl:
          pick('app_store_url')?.toString() ??
          'https://apps.apple.com/app/id6797519944',
    );
  }
}

class AppUpdateBottomSheet extends StatelessWidget {
  final AppUpdateInfo updateInfo;

  const AppUpdateBottomSheet({super.key, required this.updateInfo});

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
  }) async {
    await showModalBottomSheet(
      context: context,
      isDismissible: !updateInfo.isMandatory,
      enableDrag: !updateInfo.isMandatory,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => PopScope(
        canPop: !updateInfo.isMandatory,
        child: AppUpdateBottomSheet(updateInfo: updateInfo),
      ),
    );
  }

  Future<void> _openStore() async {
    final String storeUrl;
    if (Platform.isIOS) {
      storeUrl =
          updateInfo.appStoreUrl ?? 'https://apps.apple.com/app/id6797519944';
    } else {
      storeUrl =
          updateInfo.playStoreUrl ??
          'https://play.google.com/store/apps/details?id=uz.skor.hodimlar';
    }

    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        bottomPadding > 0 ? bottomPadding + 16 : 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          if (!updateInfo.isMandatory)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
          else
            const SizedBox(height: 12),

          // Top 3D Update Picture / Badge
          Center(
            child: Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D6E6E).withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/images/app_update_icon.png',
                  width: 116,
                  height: 116,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildFallbackBadge(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title: "Ilovani yangilang"
          Text(
            updateInfo.title.isNotEmpty
                ? updateInfo.title
                : context.tr('app_update_default_title'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),

          // Description: "Iltimos, barcha funksiyalardan foydalanish uchun..."
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              updateInfo.description.isNotEmpty
                  ? updateInfo.description
                  : context.tr('app_update_default_desc'),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                height: 1.45,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Action Button: "Yangilash"
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _openStore,
              icon: const Icon(
                Icons.sync_rounded,
                size: 22,
                color: Colors.white,
              ),
              label: Text(
                context.tr('app_update_button'),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Optional cancel button if update is not mandatory
          if (!updateInfo.isMandatory) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  context.tr('app_update_later'),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackBadge() {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D6E6E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Center(
        child: Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 54),
      ),
    );
  }
}
