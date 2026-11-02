import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/utils/money_input_formatter.dart';

TextEditingValue _type(String text, [int? cursor]) =>
    ThousandsDotFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor ?? text.length),
      ),
    );

void main() {
  test('minglar nuqta bilan ajratiladi', () {
    expect(_type('4000000').text, '4.000.000');
    expect(_type('15000').text, '15.000');
    expect(_type('999').text, '999');
    expect(_type('').text, '');
    expect(_type('00150').text, '150');
  });

  test('kursor oxirida qoladi', () {
    final v = _type('1.5000');
    expect(v.text, '15.000');
    expect(v.selection.baseOffset, 6);
  });

  test('o\'rtada tahrirlaganda kursor siljimaydi', () {
    // "1.000" ning boshiga 2 yozildi: "21.000", kursor 2 dan keyin.
    final v = _type('21.000', 2);
    expect(v.text, '21.000');
    expect(v.selection.baseOffset, 2);
  });

  test('qiymatni o\'qish va ko\'rsatish', () {
    expect(parseMoneyInput('4.000.000'), 4000000);
    expect(parseMoneyInput(''), isNull);
    expect(formatMoneyInput(1290000), '1.290.000');
    expect(formatMoneyInput(0), '');
    expect(formatMoneyInput(null), '');
  });
}
