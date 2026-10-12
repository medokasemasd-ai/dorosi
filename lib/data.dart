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

  /// What [s] owes and has paid for [month] (yyyy-MM), as of [today], plus
  /// whatever is still unpaid from earlier months.
  MonthBill billFor(Student s, String month, DateTime today) {
    final bill = _monthBill(s, month, today);
    final first = parseMonthKey(month);
    if (first.isAfter(dateOnly(today))) return bill;
    var m = DateTime(s.joinedAt.year, s.joinedAt.month);
    // Payments for earlier months count too, even ones recorded before joining.
    final earlierPayments = payments
        .where((p) => p.studentId == s.id && p.month.compareTo(month) < 0)
        .fold<double>(0, (a, p) => a + p.amount);
    var earlierDue = 0.0;
    final owed = <String, double>{};
    for (; m.isBefore(first); m = DateTime(m.year, m.month + 1)) {
      final b = _monthBill(s, monthKey(m), today);
      earlierDue += b.due;
      if (b.due - b.paid > 0) owed[monthKey(m)] = b.due - b.paid;
    }
    bill.previous = earlierDue - earlierPayments;
    if (bill.previous > 0) bill.previousMonths = owed;
    return bill;
  }

  /// One month on its own, without earlier months.
  MonthBill _monthBill(Student s, String month, DateTime today) {
    final first = parseMonthKey(month);
    final last = DateTime(first.year, first.month + 1, 0);
    final todayD = dateOnly(today);
    final lines = <BillLine>[];
    final isFutureMonth = first.isAfter(todayD);

    final mine = groupsOf(s, includeArchived: true);
    if (!isFutureMonth && mine.isNotEmpty && !dateOnly(s.joinedAt).isAfter(last)) {
      final ids = {for (final g in mine) g.id};
      final count = <String, int>{};
      final hours = <String, double>{};
      final anyInMonth = <String>{};
      for (var d = first; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
        for (final l in lessonsOn(d, forBilling: true)) {
          if (!ids.contains(l.group.id) || l.cancelled) continue;
          anyInMonth.add(l.group.id);
          if (l.group.payType != PayType.perLesson) continue;
          if (d.isAfter(todayD) || d.isBefore(dateOnly(s.joinedAt))) continue;
          if (isAbsent(l, s.id)) continue;
          count[l.group.id] = (count[l.group.id] ?? 0) + 1;
          hours[l.group.id] = (hours[l.group.id] ?? 0) + l.hours;
        }
      }
      for (final g in mine) {
        final price = s.priceOverrides[g.id] ?? g.priceFor(month);
        if (g.payType == PayType.monthly) {
          if (anyInMonth.contains(g.id)) lines.add(BillLine(g, price, 1, price));
        } else {
          final n = count[g.id] ?? 0;
          final h = hours[g.id] ?? 0;
          if (n > 0) lines.add(BillLine(g, price, n, price * h, hours: h));
        }
      }
    }
    final paid = payments.where((p) => p.studentId == s.id && p.month == month).fold<double>(0, (a, p) => a + p.amount);
    return MonthBill(lines, paid);
  }
}

// ---- running account ----

extension Accounts on AppData {
  /// Everything [s] has taken since joining and everything paid, with the
  /// payments covering the oldest lessons first.
  Account accountFor(Student s, DateTime now) {
    final charges = <Charge>[];
    final ids = {for (final g in groupsOf(s, includeArchived: true)) g.id};
    final monthsCharged = <String>{};
    final today = dateOnly(now);
    var attended = 0;
    var hours = 0.0;
    for (var d = dateOnly(s.joinedAt); !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1)) {
      for (final l in lessonsOn(d, forBilling: true)) {
        if (!ids.contains(l.group.id) || l.cancelled) continue;
        final g = l.group;
        final month = monthKey(d);
        final price = s.priceOverrides[g.id] ?? g.priceFor(month);
        final took = !l.start.isAfter(now) && !isAbsent(l, s.id);
        final h = studentHours(s, l);
        if (took) {
          attended++;
          hours += h;
        }
        if (g.payType == PayType.monthly) {
          // A monthly class is one charge for the month, from its first lesson.
          if (monthsCharged.add('${g.id}|$month')) charges.add(Charge(g, d, price, month: month));
          continue;
        }
        if (took) charges.add(Charge(g, d, price * h, lesson: l, hours: h));
      }
    }
    final paid = payments.where((p) => p.studentId == s.id).fold<double>(0, (a, p) => a + p.amount);
    var left = paid;
    for (final c in charges) {
      final take = left < c.amount ? left : c.amount;
      c.paid = take < 0 ? 0 : take;
      left -= c.paid;
    }
    return Account(charges, paid, attended: attended, hours: hours);
  }
}

/// One thing a student owes for: a lesson, or a month of a monthly class.
class Charge {
  Charge(this.group, this.date, this.amount, {this.lesson, this.month, this.hours = 0});

  final Group group;
  final DateTime date;
  final double amount;
  final Lesson? lesson;

  /// Set for a month of a monthly class.
  final String? month;

  /// Hours charged for a lesson.
  final double hours;

  /// How much of it the payments cover.
  double paid = 0;

  bool get settled => paid >= amount - 0.001;
}

class Account {
  Account(this.charges, this.paid, {this.attended = 0, this.hours = 0});

  final List<Charge> charges;
  final double paid;

  /// Lessons attended in all classes, monthly ones included, and their hours.
  final int attended;
  final double hours;

  double get due => charges.fold<double>(0, (a, c) => a + c.amount);
  double get remaining => due - paid > 0 ? due - paid : 0;

  /// Paid beyond what is owed so far.
  double get credit => paid - due > 0 ? paid - due : 0;

  Iterable<Charge> get lessons => charges.where((c) => c.lesson != null);
  double get lessonsTaken => attended.toDouble();

  /// Per-lesson charges only: each lesson counts once, whatever its length.
  double get lessonsPaid => lessons.where((c) => c.settled).length.toDouble();
  double get lessonsUnpaid => lessons.where((c) => !c.settled).length.toDouble();
  List<Charge> get unpaid => charges.where((c) => !c.settled).toList();

  PayStatus get status {
    if (due <= 0) return paid > 0 ? PayStatus.paid : PayStatus.none;
    if (paid >= due - 0.001) return PayStatus.paid;
    if (paid > 0) return PayStatus.partial;
    return PayStatus.unpaid;
  }
}

/// Hours [s] is taught in [l]: their own hours in that class, or the whole lesson.
double studentHours(Student s, Lesson l) {
  final h = s.hoursOverrides[l.group.id];
  return h == null || h <= 0 || h > l.hours ? l.hours : h;
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

  /// A lesson is one hour; a two-hour lesson counts as two.
  double get hours => durationMin / 60;
}

class BillLine {
  BillLine(this.group, this.price, this.count, this.amount, {this.hours = 0});

  final Group group;
  final double price;

  /// Number of lessons for per-lesson classes, 1 for monthly ones.
  final int count;
  final double amount;

  /// Hours taught for per-lesson classes; the price is per hour.
  final double hours;
}

enum PayStatus { none, paid, partial, unpaid }

class MonthBill {
  MonthBill(this.lines, this.paid);

  final List<BillLine> lines;
  final double paid;

  /// Still owed from earlier months (negative when paid ahead).
  double previous = 0;

  /// The earlier months with something unpaid, and how much.
  Map<String, double> previousMonths = {};

  /// This month only.
  double get due => lines.fold<double>(0, (a, l) => a + l.amount);

  /// This month plus anything left from earlier months.
  double get totalDue => due + previous;
  double get remaining => (totalDue - paid) < 0 ? 0 : totalDue - paid;

  PayStatus get status {
    if (totalDue <= 0) return paid > 0 || due > 0 ? PayStatus.paid : PayStatus.none;
    if (paid >= totalDue) return PayStatus.paid;
    if (paid > 0) return PayStatus.partial;
    return PayStatus.unpaid;
  }
}
