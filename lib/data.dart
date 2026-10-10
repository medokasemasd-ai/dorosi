// The whole app state plus the pure logic over it: which lessons happen
// when, and what each student owes. Kept free of Flutter so it is easy to test.

import 'models.dart';

class AppData {
  AppData({
    List<Group>? groups,
    List<Student>? students,
    List<Payment>? payments,
    Set<String>? absences,
    Set<String>? cancelled,
    Settings? settings,
  }) : groups = groups ?? [],
       students = students ?? [],
       payments = payments ?? [],
       absences = absences ?? {},
       cancelled = cancelled ?? {},
       settings = settings ?? Settings();

  List<Group> groups;
  List<Student> students;
  List<Payment> payments;

  /// Keys of [absenceKey]: a student missed one lesson.
  Set<String> absences;

  /// Keys of [Lesson.key]: a lesson that did not take place.
  Set<String> cancelled;
  Settings settings;

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'groups': groups.map((e) => e.toJson()).toList(),
    'students': students.map((e) => e.toJson()).toList(),
    'payments': payments.map((e) => e.toJson()).toList(),
    'absences': absences.toList(),
    'cancelled': cancelled.toList(),
    'settings': settings.toJson(),
  };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
    groups: ((j['groups'] ?? []) as List).map((e) => Group.fromJson(e as Map<String, dynamic>)).toList(),
    students: ((j['students'] ?? []) as List).map((e) => Student.fromJson(e as Map<String, dynamic>)).toList(),
    payments: ((j['payments'] ?? []) as List).map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList(),
    absences: ((j['absences'] ?? []) as List).cast<String>().toSet(),
    cancelled: ((j['cancelled'] ?? []) as List).cast<String>().toSet(),
    settings: Settings.fromJson((j['settings'] ?? <String, dynamic>{}) as Map<String, dynamic>),
  );

  Student? student(String id) {
    for (final s in students) {
      if (s.id == id) return s;
    }
    return null;
  }

  Group? group(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  List<Student> studentsOf(Group g) =>
      g.studentIds.map(student).whereType<Student>().where((s) => !s.archived).toList();

  List<Group> groupsOf(Student s, {bool includeArchived = false}) =>
      groups.where((g) => g.studentIds.contains(s.id) && (includeArchived || !g.archived)).toList();

  /// Other students with the same family name.
  List<Student> siblingsOf(Student s) {
    final f = s.family.trim();
    if (f.isEmpty) return [];
    return students.where((o) => o.id != s.id && !o.archived && o.family.trim() == f).toList();
  }

  // ---- schedule ----

  /// Lessons on [day]. With [forBilling], lessons before a class started or
  /// after it was archived are left out.
  List<Lesson> lessonsOn(DateTime day, {bool forBilling = false, bool includeArchived = false}) {
    final d = dateOnly(day);
    final out = <Lesson>[];
    for (final g in groups) {
      if (forBilling) {
        if (d.isBefore(dateOnly(g.createdAt))) continue;
        if (g.archived && g.archivedAt != null && d.isAfter(g.archivedAt!)) continue;
      } else if (g.archived && !includeArchived) {
        continue;
      }
      for (final s in g.slots) {
        if (s.weekday == d.weekday) out.add(Lesson(g, d, s.startMin, s.durationMin));
      }
      for (final s in g.sessions) {
        // On a weekly class a dated session is an extra or make-up lesson.
        if (dateOnly(s.date) == d) out.add(Lesson(g, d, s.startMin, s.durationMin, extra: g.slots.isNotEmpty));
      }
    }
    for (final l in out) {
      l.cancelled = cancelled.contains(l.key);
    }
    out.sort((a, b) => a.startMin.compareTo(b.startMin));
    return out;
  }

  /// Lessons that have not ended yet, starting from [now], over [days] days.
  List<Lesson> upcoming(DateTime now, {int days = 28}) {
    final out = <Lesson>[];
    final today = dateOnly(now);
    for (var i = 0; i <= days; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      for (final l in lessonsOn(day)) {
        if (!l.cancelled && l.end.isAfter(now)) out.add(l);
      }
    }
    return out;
  }

  Lesson? nextLesson(DateTime now) {
    final u = upcoming(now, days: 8);
    return u.isEmpty ? null : u.first;
  }

  bool isAbsent(Lesson l, String studentId) => absences.contains(absenceKey(l, studentId));

  /// Every lesson of [s]'s classes from [from] to [to] (dates, inclusive),
  /// from the day the student joined.
  List<Lesson> lessonsOfStudent(Student s, DateTime from, DateTime to) {
    final ids = {for (final g in groupsOf(s, includeArchived: true)) g.id};
    var d = dateOnly(from);
    final joined = dateOnly(s.joinedAt);
    if (d.isBefore(joined)) d = joined;
    final out = <Lesson>[];
    for (; !d.isAfter(dateOnly(to)); d = DateTime(d.year, d.month, d.day + 1)) {
      out.addAll(lessonsOn(d, forBilling: true).where((l) => ids.contains(l.group.id)));
    }
    return out;
  }

  // ---- billing ----

  /// What [s] owes and has paid for [month] (yyyy-MM), as of [today].
  MonthBill billFor(Student s, String month, DateTime today) {
    final first = parseMonthKey(month);
    final last = DateTime(first.year, first.month + 1, 0);
    final todayD = dateOnly(today);
    final lines = <BillLine>[];
    final isFutureMonth = first.isAfter(todayD);

    final mine = groupsOf(s, includeArchived: true);
    if (!isFutureMonth && mine.isNotEmpty && !dateOnly(s.joinedAt).isAfter(last)) {
      final ids = {for (final g in mine) g.id};
      final count = <String, int>{};
      final anyInMonth = <String>{};
      for (var d = first; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
        for (final l in lessonsOn(d, forBilling: true)) {
          if (!ids.contains(l.group.id) || l.cancelled) continue;
          anyInMonth.add(l.group.id);
          if (l.group.payType != PayType.perLesson) continue;
          if (d.isAfter(todayD) || d.isBefore(dateOnly(s.joinedAt))) continue;
          if (isAbsent(l, s.id)) continue;
          count[l.group.id] = (count[l.group.id] ?? 0) + 1;
        }
      }
      for (final g in mine) {
        final price = s.priceOverrides[g.id] ?? g.priceFor(month);
        if (g.payType == PayType.monthly) {
          if (anyInMonth.contains(g.id)) lines.add(BillLine(g, price, 1, price));
        } else {
          final n = count[g.id] ?? 0;
          if (n > 0) lines.add(BillLine(g, price, n, price * n));
        }
      }
    }
    final paid = payments.where((p) => p.studentId == s.id && p.month == month).fold<double>(0, (a, p) => a + p.amount);
    return MonthBill(lines, paid);
  }
}

String absenceKey(Lesson l, String studentId) => '${l.key}|$studentId';

class Lesson {
  Lesson(this.group, this.date, this.startMin, this.durationMin, {this.extra = false});

  final Group group;

  /// An extra or make-up lesson added on a date, outside the weekly schedule.
  final bool extra;
  final DateTime date;
  final int startMin;
  final int durationMin;
  bool cancelled = false;

  DateTime get start => DateTime(date.year, date.month, date.day, 0, startMin);
  DateTime get end => DateTime(date.year, date.month, date.day, 0, startMin + durationMin);
  String get key => '${group.id}|${dateKey(date)}|$startMin';
}

class BillLine {
  BillLine(this.group, this.price, this.count, this.amount);

  final Group group;
  final double price;

  /// Number of lessons for per-lesson classes, 1 for monthly ones.
  final int count;
  final double amount;
}

enum PayStatus { none, paid, partial, unpaid }

class MonthBill {
  MonthBill(this.lines, this.paid);

  final List<BillLine> lines;
  final double paid;

  double get due => lines.fold<double>(0, (a, l) => a + l.amount);
  double get remaining => (due - paid) < 0 ? 0 : due - paid;

  PayStatus get status {
    if (due <= 0) return paid > 0 ? PayStatus.paid : PayStatus.none;
    if (paid >= due) return PayStatus.paid;
    if (paid > 0) return PayStatus.partial;
    return PayStatus.unpaid;
  }
}
