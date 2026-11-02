import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/services/network_diagnostics_service.dart';

/// Shows recorded API failures (external IP, exact time, API error, TCP test)
/// and lets the user run a live check, then copy everything to send to the
/// hosting support.
class NetworkDiagnosticsSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _DiagnosticsContent(),
    );
  }
}

class _DiagnosticsContent extends StatefulWidget {
  const _DiagnosticsContent();

  @override
  State<_DiagnosticsContent> createState() => _DiagnosticsContentState();
}

class _DiagnosticsContentState extends State<_DiagnosticsContent> {
  final _service = NetworkDiagnosticsService.instance;
  List<NetworkIncident> _incidents = [];
  NetworkIncident? _liveCheck;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _service.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _service.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await _service.load();
    if (mounted) setState(() => _incidents = list);
  }

  Future<void> _runCheck() async {
    setState(() => _checking = true);
    final result = await _service.runManualCheck();
    if (mounted) {
      setState(() {
        _liveCheck = result;
        _checking = false;
      });
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('diag_copied')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String get _allReports => [
    if (_liveCheck != null) _liveCheck!.toReport(),
    ..._incidents.map((e) => e.toReport()),
  ].join('\n\n────────────\n\n');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.network_check_rounded,
                      color: c.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('diag_title'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('diag_desc'),
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _checking ? null : _runCheck,
                      icon: _checking
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.textHint,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        context.tr(
                          _checking ? 'diag_checking' : 'diag_run_check',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _liveCheck == null && _incidents.isEmpty
                          ? null
                          : () => _copy(_allReports),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(context.tr('diag_copy_all')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (_liveCheck != null) ...[
                      _SectionTitle(context.tr('diag_live_check')),
                      _ReportCard(
                        incident: _liveCheck!,
                        onCopy: () => _copy(_liveCheck!.toReport()),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _SectionTitle(
                            '${context.tr('diag_recorded')} '
                            '(${_incidents.length})',
                          ),
                        ),
                        if (_incidents.isNotEmpty)
                          TextButton(
                            onPressed: _service.clear,
                            child: Text(context.tr('diag_clear')),
                          ),
                      ],
                    ),
                    if (_incidents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          context.tr('diag_empty'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.textHint),
                        ),
                      ),
                    for (final incident in _incidents)
                      _ReportCard(
                        incident: incident,
                        onCopy: () => _copy(incident.toReport()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final NetworkIncident incident;
  final VoidCallback onCopy;

  const _ReportCard({required this.incident, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final probe = incident.probe;
    final blocked = probe.internetOk && !probe.tcpOk;
    final accent = !probe.internetOk
        ? c.textHint
        : blocked
        ? c.error
        : (incident.statusCode ?? 0) >= 400
        ? c.warning
        : c.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 44, 12),
            child: SelectableText(
              incident.toReport(),
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                fontFamily: 'monospace',
                color: c.textPrimary,
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              onPressed: onCopy,
              tooltip: context.tr('diag_copy'),
              icon: Icon(Icons.copy_rounded, size: 18, color: c.primary),
            ),
          ),
        ],
      ),
    );
  }
}
