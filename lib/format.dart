// Arabic display helpers. Numbers are shown with Arabic-Indic digits.

const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String arDigits(String s) => s.replaceAllMapped(RegExp(r'[0-9]'), (m) => _digits[int.parse(m[0]!)]);

String arNum(num n) => arDigits(n is double && n == n.roundToDouble() ? n.toInt().toString() : n.toString());

/// Parses a number typed with Arabic-Indic or Western digits.
double? parseArNum(String s) {
  var t = s.trim().replaceAll('٫', '.').replaceAll(',', '.');
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(_digits[i], '$i');
  }
  return double.tryParse(t);
}

String fmtMoney(double v, String currency) {
  final whole = v == v.roundToDouble();
  final s = whole ? v.toInt().toString() : v.toStringAsFixed(1);
  final grouped = s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${arDigits(grouped)} $currency';
}

/// 18:30 -> ٦:٣٠ م
String fmtTime(int minutes) {
  final m = minutes % (24 * 60);
  final h = m ~/ 60;
  final mm = m % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final suffix = h < 12 ? 'ص' : 'م';
  return '${arDigits('$h12:${mm.toString().padLeft(2, '0')}')} $suffix';
}

String fmtDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${arNum(m)} دقيقة';
  final hs = h == 1 ? 'ساعة' : h == 2 ? 'ساعتين' : '${arNum(h)} ساعات';
  if (m == 0) return hs;
  if (m == 30) return '$hs ونص';
  return '$hs و${arNum(m)} دقيقة';
}

const weekdayNames = {
  DateTime.saturday: 'السبت',
  DateTime.sunday: 'الأحد',
  DateTime.monday: 'الاثنين',
  DateTime.tuesday: 'الثلاثاء',
  DateTime.wednesday: 'الأربعاء',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
};

/// Week order used in Egypt: Saturday first.
const weekOrder = [
  DateTime.saturday,
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
];

String weekdayName(int weekday) => weekdayNames[weekday]!;

const _months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String monthName(DateTime d, {bool withYear = false}) =>
    withYear ? '${_months[d.month - 1]} ${arNum(d.year)}' : _months[d.month - 1];

String fmtDate(DateTime d) => '${weekdayName(d.weekday)} ${arNum(d.day)} ${_months[d.month - 1]}';

String fmtShortDate(DateTime d) => '${arNum(d.day)} ${_months[d.month - 1]}';

/// Saturday that starts the week containing [d].
DateTime weekStart(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  final back = (day.weekday - DateTime.saturday + 7) % 7;
  return DateTime(day.year, day.month, day.day - back);
}

/// "اليوم", "بكرة" or the weekday name.
String dayLabel(DateTime day, DateTime now) {
  final a = DateTime(day.year, day.month, day.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'بكرة';
  return weekdayName(day.weekday);
}

/// "بعد ساعة و٢٠ دقيقة"
String fmtCountdown(Duration d) {
  final mins = d.inMinutes;
  if (mins < 1) return 'دلوقتي';
  if (mins < 60) return 'بعد ${arNum(mins)} دقيقة';
  final h = mins ~/ 60;
  final m = mins % 60;
  if (h >= 24) {
    final days = (h / 24).round();
    return days == 1 ? 'بعد يوم' : days == 2 ? 'بعد يومين' : 'بعد ${arNum(days)} أيام';
  }
  final hs = h == 1 ? 'ساعة' : h == 2 ? 'ساعتين' : '${arNum(h)} ساعات';
  return m == 0 ? 'بعد $hs' : 'بعد $hs و${arNum(m)} دقيقة';
}

String plural(int n, String one, String two, String few, String many) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n >= 3 && n <= 10) return '${arNum(n)} $few';
  return '${arNum(n)} $many';
}

String studentsCount(int n) => n == 0 ? 'بدون طلاب' : plural(n, 'طالب واحد', 'طالبين', 'طلاب', 'طالب');

String lessonsCount(int n) => n == 0 ? 'لا حصص' : plural(n, 'حصة واحدة', 'حصتين', 'حصص', 'حصة');

/// Converts Arabic-Indic digits to Western ones (for phone numbers and links).
String westernDigits(String s) {
  var t = s;
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(_digits[i], '$i');
  }
  return t;
}

String minutesCount(int n) => plural(n, 'دقيقة', 'دقيقتين', 'دقائق', 'دقيقة');
