import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/security/app_lock_gate.dart';
import 'package:skore_hodimlar/core/security/app_lock_service.dart';
import 'package:skore_hodimlar/core/security/pin_pad.dart';

/// Profil (xodim) va rahbar panelidan ochiladi: PIN-kodni o'zgartirish va
/// barmoq izi / Face ID bilan ochishni yoqish-o'chirish.
class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SecuritySettingsPage()));

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final _lock = AppLockService.instance;
  bool? _bioAvailable;
  String _bioLabel = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await _lock.biometricAvailable();
    if (!mounted) return;
    final label = await biometricLabel(context);
    if (mounted) {
      setState(() {
        _bioAvailable = available;
        _bioLabel = label;
      });
    }
  }

  Future<void> _toggleBio(bool value) async {
    if (value) {
      final ok = await _lock.authenticateBiometric(
        context.tr('lock_bio_reason'),
      );
      if (!ok) return;
    }
    await _lock.setBiometricEnabled(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('security_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: c.primary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.pin_outlined, color: c.primary),
                  title: Text(context.tr('security_change_pin')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _ChangePinPage(),
                    ),
                  ),
                ),
                Divider(height: 1, color: c.border),
                SwitchListTile(
                  secondary: Icon(
                    _bioLabel == context.tr('lock_face')
                        ? Icons.face_retouching_natural_rounded
                        : Icons.fingerprint_rounded,
                    color: c.primary,
                  ),
                  title: Text(
                    context.tr('security_bio_switch', {
                      'method': _bioLabel.isEmpty
                          ? context.tr('lock_fingerprint')
                          : _bioLabel,
                    }),
                  ),
                  subtitle: _bioAvailable == false
                      ? Text(context.tr('security_bio_unavailable'))
                      : null,
                  value: _lock.biometricEnabled && _bioAvailable != false,
                  onChanged: _bioAvailable == true ? _toggleBio : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              context.tr('security_lock_note'),
              style: GoogleFonts.outfit(fontSize: 13, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Joriy PIN → yangi PIN → tasdiqlash.
class _ChangePinPage extends StatefulWidget {
  const _ChangePinPage();

  @override
  State<_ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<_ChangePinPage> {
  final _lock = AppLockService.instance;
  int _step = 0; // 0 — joriy, 1 — yangi, 2 — tasdiqlash
  String? _newPin;
  String? _error;

  Future<bool> _onPin(String pin) async {
    switch (_step) {
      case 0:
        if (!_lock.verifyPin(pin)) {
          setState(() => _error = context.tr('lock_wrong_pin'));
          return false;
        }
        setState(() {
          _step = 1;
          _error = null;
        });
      case 1:
        setState(() {
          _newPin = pin;
          _step = 2;
        });
      default:
        if (pin != _newPin) {
          setState(() {
            _step = 1;
            _newPin = null;
            _error = context.tr('lock_mismatch');
          });
          return false;
        }
        await _lock.setPin(pin);
        if (!mounted) return true;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('security_pin_changed'))),
        );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = switch (_step) {
      0 => 'security_current_pin',
      1 => 'security_new_pin',
      _ => 'lock_confirm_title',
    };
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: PinPad(
              key: ValueKey(_step),
              title: context.tr(title),
              error: _error,
              onCompleted: _onPin,
            ),
          ),
        ),
      ),
    );
  }
}
