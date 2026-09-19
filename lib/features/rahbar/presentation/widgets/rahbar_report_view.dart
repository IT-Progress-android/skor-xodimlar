import 'package:flutter/material.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/dio_retry_helper.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';

/// Fetches a rahbar report and handles the four cross-cutting concerns from the
/// guide: loading, error, the `malumot` empty-state block (§1.3), and refresh.
/// The [builder] only runs when there is real data to draw.
class RahbarReportView extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() fetch;
  final Widget Function(BuildContext context, Map<String, dynamic> data)
  builder;
  // Optional: jump to the last date that has data ("{oxirgi_sana} ga o'tish").
  final void Function(String sana)? onGoToDate;

  const RahbarReportView({
    super.key,
    required this.fetch,
    required this.builder,
    this.onGoToDate,
  });

  @override
  State<RahbarReportView> createState() => RahbarReportViewState();
}

class RahbarReportViewState extends State<RahbarReportView> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.fetch();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = DioRetryHelper.formatErrorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D6E6E)),
      );
    }

    if (_error != null) {
      return RahbarEmptyStateWidget(
        icon: Icons.wifi_off_rounded,
        title: context.tr('error'),
        subtitle: _error!,
        onRefresh: _load,
      );
    }

    final data = _data ?? const {};
    final malumot = data['malumot'] is Map
        ? Map<String, dynamic>.from(data['malumot'] as Map)
        : null;

    // No attendance data in the requested range — explain why, per §1.3.
    if (malumot != null && malumot['bor'] == false) {
      final oxirgi = malumot['oxirgi_sana']?.toString();
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            RahbarEmptyStateWidget(
              icon: oxirgi == null
                  ? Icons.sensors_off_rounded
                  : Icons.event_busy_rounded,
              title: oxirgi == null
                  ? context.tr('rahbar_terminal_not_connected')
                  : context.tr('rahbar_no_data_this_date'),
              subtitle: (malumot['izoh']?.toString().isNotEmpty ?? false)
                  ? malumot['izoh'].toString()
                  : context.tr('rahbar_no_attendance_data_generic'),
            ),
            if (oxirgi != null && widget.onGoToDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 8,
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6E6E),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () => widget.onGoToDate!(oxirgi),
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: Text(
                    context.tr('rahbar_go_to_date', {'date': oxirgi}),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: widget.builder(context, data),
    );
  }
}
