import 'package:flutter/services.dart';

/// Summa maydoni: faqat raqam, minglar nuqta bilan ajratiladi —
/// `4000000` → `4.000.000`.
class ThousandsDotFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final text = formatMoneyDigits(digits);
    // Kursor o'ngdan sanaganda shuncha raqamdan keyin turadi.
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsAfter = newValue.text
        .substring(cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    var offset = text.length;
    for (var seen = 0; offset > 0 && seen < digitsAfter; offset--) {
      if (text[offset - 1] != '.') seen++;
    }
    while (offset > 0 && text[offset - 1] == '.') {
      offset--;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

String formatMoneyDigits(String digits) {
  final d = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write('.');
    b.write(d[i]);
  }
  return b.toString();
}

/// Maydonning boshlang'ich qiymati: `0` yoki `null` — bo'sh.
String formatMoneyInput(double? v) =>
    (v == null || v <= 0) ? '' : formatMoneyDigits(v.toStringAsFixed(0));

/// `4.000.000` → `4000000`; bo'sh bo'lsa `null`.
double? parseMoneyInput(String text) =>
    double.tryParse(text.replaceAll(RegExp(r'\D'), ''));
