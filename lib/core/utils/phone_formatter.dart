import 'package:flutter/services.dart';

/// O'zbekiston telefon raqamlari (+998 XX XXX XX XX) uchun mukammal formatter.
/// - Maksimal 9 ta abonent raqami (ortiqcha raqam kiritishni 100% cheklaydi, surilib ketmaydi)
/// - Uzmobile (99 8xx xx xx) prefiksini noto'g'ri o'chirib yubormaydi
/// - Probel o'chirilganda undan oldingi raqamni to'g'ri o'chiradi (backspace qotib qolmaydi)
/// - Har qanday copy-paste (998..., +998..., 8..., qavs, chiziqcha) variantlarini toza formatlaydi
/// - Kursor kutilmaganda oxiriga sakrab ketmaydi
class UzbekPhoneInputFormatter extends TextInputFormatter {
  static const String prefix = '+998 ';
  static const int maxSubscriberDigits = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Agar butunlay bo'sh bo'lsa
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final isDeleting = oldValue.text.length > newValue.text.length;
    String textToProcess = newValue.text;
    int selectionIndex = newValue.selection.baseOffset;

    // 2. Probelni o'chirganda: avtomatik undan oldingi raqamni ham o'chirish
    // Masalan: "+998 90 " da backspace bosilganda "+998 90" bo'lib qolmasdan "+998 9" bo'ladi
    if (isDeleting &&
        oldValue.text.endsWith(' ') &&
        !newValue.text.endsWith(' ')) {
      if (textToProcess.length > prefix.length) {
        textToProcess = textToProcess.substring(0, textToProcess.length - 1);
        selectionIndex = textToProcess.length;
      }
    }

    // 3. Prefiks ichiga kirib ketishni oldini olish
    if (isDeleting && textToProcess.length < prefix.length) {
      if (oldValue.text == prefix || oldValue.text.trim() == '+998') {
        return const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
      }
      return const TextEditingValue(
        text: prefix,
        selection: TextSelection.collapsed(offset: 5),
      );
    }

    // 4. Faqat raqamlarni ajratib olish
    final String allDigits = textToProcess.replaceAll(RegExp(r'\D'), '');

    // 5. Xalqaro kod (998) ni to'g'ri ajratish:
    String subscriberDigits = allDigits;
    if (subscriberDigits.startsWith('998')) {
      if (subscriberDigits.length > maxSubscriberDigits) {
        subscriberDigits = subscriberDigits.substring(3);
      } else if (textToProcess.startsWith(prefix) ||
          textToProcess.startsWith('+998')) {
        subscriberDigits = subscriberDigits.substring(3);
      }
    } else if (subscriberDigits.startsWith('8') &&
        subscriberDigits.length > maxSubscriberDigits) {
      subscriberDigits = subscriberDigits.substring(1);
    }

    // 6. QAT'IY CHEKLOV: Faqat 9 ta abonent raqami kiritish mumkin!
    // 9 tadan ortiq raqam kiritilganda birinchi raqamlar surilib yo'qolib ketmaydi,
    // ortiqcha raqamlar qabul qilinmaydi.
    if (subscriberDigits.length > maxSubscriberDigits) {
      final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
      final oldSubDigits = oldDigits.startsWith('998') && oldDigits.length > 3
          ? oldDigits.substring(3)
          : oldDigits;

      if (oldSubDigits.length >= maxSubscriberDigits && !isDeleting) {
        return oldValue;
      }
      subscriberDigits = subscriberDigits.substring(0, maxSubscriberDigits);
    }

    if (subscriberDigits.isEmpty) {
      return const TextEditingValue(
        text: prefix,
        selection: TextSelection.collapsed(offset: 5),
      );
    }

    // 7. Kursor joylashuvini aniq hisoblash
    int digitsBeforeCursor = 0;
    final rawCursor = selectionIndex.clamp(0, textToProcess.length);
    final textBeforeCursor = textToProcess.substring(0, rawCursor);
    final String digitsBeforeCursorStr = textBeforeCursor.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (digitsBeforeCursorStr.startsWith('998') &&
        (textToProcess.startsWith(prefix) || allDigits.startsWith('998'))) {
      digitsBeforeCursor = (digitsBeforeCursorStr.length - 3).clamp(
        0,
        subscriberDigits.length,
      );
    } else {
      digitsBeforeCursor = digitsBeforeCursorStr.length.clamp(
        0,
        subscriberDigits.length,
      );
    }

    // 8. Chiroyli formatlash: +998 XX XXX XX XX
    final buffer = StringBuffer(prefix);
    int newCursorPos = prefix.length;
    int placedDigits = 0;

    for (int i = 0; i < subscriberDigits.length; i++) {
      buffer.write(subscriberDigits[i]);
      placedDigits++;
      if (placedDigits == digitsBeforeCursor) {
        newCursorPos = buffer.length;
      }
      // 2, 5 va 7-raqamdan keyin probel qo'yish
      if ((i == 1 || i == 4 || i == 6) && i < subscriberDigits.length - 1) {
        buffer.write(' ');
        if (placedDigits == digitsBeforeCursor) {
          newCursorPos = buffer.length;
        }
      }
    }

    final formatted = buffer.toString();
    if (digitsBeforeCursor >= subscriberDigits.length) {
      newCursorPos = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newCursorPos.clamp(prefix.length, formatted.length),
      ),
    );
  }
}

class PhoneFormatter {
  /// Faqat 9 xonali abonent raqamini ajratib oladi (masalan: 901234567)
  static String extractSubscriberDigits(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    while (digits.startsWith('998') && digits.length > 9) {
      digits = digits.substring(3);
    }
    if ((digits.startsWith('0') || digits.startsWith('8')) &&
        digits.length > 9) {
      digits = digits.substring(1);
    }
    if (digits.length > 9) {
      digits = digits.substring(0, 9);
    }
    return digits;
  }

  /// Telefon raqamini toza 998XXXXXXXXX formatga keltiradi
  static String normalizePhone(String phone) {
    final digits = extractSubscriberDigits(phone);
    return '998$digits';
  }
}
