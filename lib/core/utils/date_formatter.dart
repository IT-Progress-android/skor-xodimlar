class DateFormatter {
  /// Serverdan keladigan kechikish qiymatini ("95", "95 min") o'zbekcha
  /// "1 soat 35 minut" ko'rinishiga o'giradi.
  static String formatDelayToHours(String? rawDelay) {
    if (rawDelay == null || rawDelay.trim().isEmpty) return '';

    final text = rawDelay.trim();
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return text;

    final totalMinutes = int.tryParse(digits);
    if (totalMinutes == null || totalMinutes <= 0) return text;

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '$hours soat $minutes minut';
    } else if (hours > 0 && minutes == 0) {
      return '$hours soat';
    } else {
      return '$minutes minut';
    }
  }
}
