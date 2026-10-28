import 'dart:convert';

import 'package:dorosi/data.dart';
import 'package:dorosi/demo.dart';
import 'package:dorosi/format.dart';
import 'package:dorosi/models.dart';
import 'package:dorosi/phone.dart';
import 'package:dorosi/services/reminders.dart';
import 'package:dorosi/store.dart';
import 'package:flutter_test/flutter_test.dart';

Group _group(
  String id,
  PayType pay,
  double price, {
  List<WeeklySlot>? slots,
  List<DatedSession>? sessions,
  List<String>? students,
}) => Group(
  id: id,
  name: id,
  payType: pay,
  prices: [PriceChange(fromMonth: '0000-00', amount: price)],
  slots: slots,
  sessions: sessions,
  studentIds: students,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  // October 2026: Saturdays are 3, 10, 17, 24, 31.
  final s = Student(id: 's1', name: 'أحمد', joinedAt: DateTime(2026, 10, 1));

  group('billing', () {
    test('monthly class bills the month price once', () {
      final d = AppData(
        students: [s],
        groups: [
          _group(
            'g',
            PayType.monthly,
            400,
            slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 18 * 60, durationMin: 90)],
            students: ['s1'],
          ),
        ],
      );
      final bill = d.billFor(s, '2026-10', DateTime(2026, 10, 10, 12));
      expect(bill.due, 400);
      expect(bill.status, PayStatus.unpaid);
      d.payments.add(Payment(id: 'p', studentId: 's1', month: '2026-10', amount: 150));
      expect(d.billFor(s, '2026-10', DateTime(2026, 10, 10)).status, PayStatus.partial);
      d.payments.add(Payment(id: 'p2', studentId: 's1', month: '2026-10', amount: 250));
      expect(d.billFor(s, '2026-10', DateTime(2026, 10, 10)).status, PayStatus.paid);
    });

    test('future months are not billed', () {
      final d = AppData(
        students: [s],
        groups: [
          _group(
            'g',
            PayType.monthly,
            400,
            slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 18 * 60, durationMin: 90)],
            students: ['s1'],
          ),
        ],
      );
      expect(d.billFor(s, '2026-11', DateTime(2026, 10, 10)).status, PayStatus.none);
    });

    test('per-lesson counts held lessons up to today, minus absences and cancellations', () {
      final g = _group(
        'g',
        PayType.perLesson,
        100,
        slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 18 * 60, durationMin: 60)],
        students: ['s1'],
      );
      final d = AppData(students: [s], groups: [g]);
      // Up to Oct 17: lessons on 3, 10, 17.
      expect(d.billFor(s, '2026-10', DateTime(2026, 10, 17, 23)).due, 300);
      final oct10 = d.lessonsOn(DateTime(2026, 10, 10)).single;
      d.absences.add(absenceKey(oct10, 's1'));
      expect(d.billFor(s, '2026-10', DateTime(2026, 10, 17, 23)).due, 200);
      final oct3 = d.lessonsOn(DateTime(2026, 10, 3)).single;
      d.cancelled.add(oct3.key);
      expect(d.billFor(s, '2026-10', DateTime(2026, 10, 17, 23)).due, 100);
      // Whole month once it is over: 3 (cancelled), 10 (absent), 17, 24, 31.
      expect(d.billFor(s, '2026-10', DateTime(2026, 11, 5)).due, 300);
    });

    test('price change applies from its month only', () {
      final g = _group(
        'g',
        PayType.monthly,
        300,
        slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 18 * 60, durationMin: 90)],
        students: ['s1'],
      );
      g.setPrice(350, now: DateTime(2026, 10, 5));
      final old = Student(id: 's1', name: 'أحمد', joinedAt: DateTime(2026, 1, 1));
      final d = AppData(students: [old], groups: [g]);
      expect(d.billFor(old, '2026-09', DateTime(2026, 10, 10)).due, 300);
      expect(d.billFor(old, '2026-10', DateTime(2026, 10, 10)).due, 350);
    });

    test('a student special price beats the class price', () {
      final sib = Student(
        id: 's2',
        name: 'مريم',
        family: 'محمود',
        joinedAt: DateTime(2026, 1, 1),
        priceOverrides: {'g': 250},
      );
      final d = AppData(
        students: [sib],
        groups: [
          _group(
            'g',
            PayType.monthly,
            300,
            slots: [WeeklySlot(weekday: DateTime.monday, startMin: 17 * 60, durationMin: 90)],
            students: ['s2'],
          ),
        ],
      );
      expect(d.billFor(sib, '2026-10', DateTime(2026, 10, 10)).due, 250);
    });

    test('review lessons bill per dated session', () {
      final g = _group(
        'r',
        PayType.perLesson,
        200,
        sessions: [
          DatedSession(date: DateTime(2026, 10, 12), startMin: 20 * 60, durationMin: 60),
          DatedSession(date: DateTime(2026, 10, 14), startMin: 20 * 60, durationMin: 60),
        ],
        students: ['s1'],
      );
      final d = AppData(students: [s], groups: [g]);
      expect(d.billFor(s, '2026-10', DateTime(2026, 10, 13)).due, 200);
      expect(d.billFor(s, '2026-10', DateTime(2026, 10, 20)).due, 400);
    });
  });

  group('schedule', () {
    test('next lesson is the ongoing or the next one', () {
      final d = AppData(
        groups: [
          _group(
            'a',
            PayType.monthly,
            1,
            slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 18 * 60, durationMin: 90)],
          ),
          _group(
            'b',
            PayType.monthly,
            1,
            slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 20 * 60, durationMin: 60)],
          ),
        ],
      );
      expect(d.nextLesson(DateTime(2026, 10, 10, 12))!.group.id, 'a');
      expect(d.nextLesson(DateTime(2026, 10, 10, 19))!.group.id, 'a'); // still running
      expect(d.nextLesson(DateTime(2026, 10, 10, 19, 45))!.group.id, 'b');
      final after = d.nextLesson(DateTime(2026, 10, 10, 22))!;
      expect(after.date, DateTime(2026, 10, 17));
    });

    test('week starts on Saturday', () {
      expect(weekStart(DateTime(2026, 10, 14)), DateTime(2026, 10, 10));
      expect(weekStart(DateTime(2026, 10, 10)), DateTime(2026, 10, 10));
      expect(weekStart(DateTime(2026, 10, 16)), DateTime(2026, 10, 10));
    });
  });

  group('reminders', () {
    test('start and end reminders follow the switches', () {
      final g = _group(
        'a',
        PayType.monthly,
        1,
        slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 18 * 60, durationMin: 90)],
      );
      final d = AppData(groups: [g]);
      d.settings.remindPayment = false;
      var plan = planReminders(d, DateTime(2026, 10, 10, 12), days: 6);
      expect(plan.where((r) => r.channel == 'start').single.at, DateTime(2026, 10, 10, 17, 50));
      expect(plan.where((r) => r.channel == 'end').single.at, DateTime(2026, 10, 10, 19, 30));
      g.remindEnd = false;
      plan = planReminders(d, DateTime(2026, 10, 10, 12), days: 6);
      expect(plan.where((r) => r.channel == 'end'), isEmpty);
      d.settings.remindStart = false;
      plan = planReminders(d, DateTime(2026, 10, 10, 12), days: 6);
      expect(plan.where((r) => r.channel == 'start'), isEmpty);
    });

    test('payment reminder lands on the last day of the month', () {
      final d = AppData();
      final plan = planReminders(d, DateTime(2026, 2, 10), days: 6);
      final pay = plan.where((r) => r.id >= 900000 && r.id < 999999).toList();
      expect(pay.first.at, DateTime(2026, 2, 28, 20));
    });

    test('ids are unique', () {
      final store = AppData.fromJson(jsonDecode(demoJson()) as Map<String, dynamic>);
      final plan = planReminders(store, DateTime.now());
      expect(plan.map((r) => r.id).toSet().length, plan.length);
    });
  });

  group('format', () {
    test('arabic time and numbers', () {
      expect(fmtTime(18 * 60), '٦:٠٠ م');
      expect(fmtTime(9 * 60 + 5), '٩:٠٥ ص');
      expect(fmtTime(12 * 60), '١٢:٠٠ م');
      expect(parseArNum('٢٥٠'), 250);
      expect(fmtMoney(1500, 'ج.م'), '١,٥٠٠ ج.م');
      expect(westernDigits('٠١٠١٢٣'), '010123');
    });
  });

  group('store', () {
    test('saves, reloads and keeps class membership in sync', () async {
      final mem = MemoryStorage();
      final store = AppStore(mem);
      await store.load();
      final g = _group(
        'g',
        PayType.monthly,
        100,
        slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 600, durationMin: 60)],
      );
      await store.saveGroup(g);
      final st = Student(id: 'x', name: 'طالب');
      await store.saveStudent(st, {'g'});
      expect(store.data.group('g')!.studentIds, ['x']);
      await store.saveStudent(st, {});
      expect(store.data.group('g')!.studentIds, isEmpty);
      await store.addPayment('x', '2026-10', 100);

      final again = AppStore(mem);
      await again.load();
      expect(again.data.students.single.name, 'طالب');
      expect(again.data.payments.single.amount, 100);

      await again.importJson(store.exportJson());
      expect(again.data.groups.single.id, 'g');
      expect(() => again.importJson('{"x":1}'), throwsFormatException);
    });
  });

  test('moving Saturday to Tuesday keeps the count and bills per lesson', () async {
    // Saturday and Tuesday, per lesson. October 2026: Sat 3, Tue 6, Sat 10, Tue 13.
    final g = _group(
      'g',
      PayType.perLesson,
      100,
      slots: [
        WeeklySlot(weekday: DateTime.saturday, startMin: 17 * 60, durationMin: 60),
        WeeklySlot(weekday: DateTime.tuesday, startMin: 17 * 60, durationMin: 60),
      ],
      students: ['s1'],
    );
    final store = AppStore(MemoryStorage());
    store.data = AppData(students: [s], groups: [g]);
    final sat10 = store.data.lessonsOn(DateTime(2026, 10, 10)).single;
    await store.moveLesson(sat10, DateTime(2026, 10, 13), 19 * 60);
    final tue13 = store.data.lessonsOn(DateTime(2026, 10, 13));
    expect(tue13.length, 2);
    expect(tue13.last.extra, isTrue);
    expect(store.data.lessonsOn(DateTime(2026, 10, 10)).single.cancelled, isTrue);
    // Up to Oct 14: Sat 3, Tue 6, Tue 13 twice; Sat 10 cancelled.
    expect(store.data.billFor(s, '2026-10', DateTime(2026, 10, 14, 23)).due, 400);
    final all = store.data.lessonsOfStudent(s, DateTime(2026, 10, 1), DateTime(2026, 10, 14));
    expect(all.where((l) => !l.cancelled).length, 4);
    await store.removeExtraLesson(tue13.last);
    expect(store.data.lessonsOn(DateTime(2026, 10, 13)).length, 1);
  });

  test('a two-hour lesson costs double', () {
    final g = _group(
      'g',
      PayType.perLesson,
      100,
      slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 17 * 60, durationMin: 120)],
      students: ['s1'],
    );
    final d = AppData(students: [s], groups: [g]);
    // Oct 3 and Oct 10, two hours each.
    final bill = d.billFor(s, '2026-10', DateTime(2026, 10, 10, 23));
    expect(bill.lines.single.count, 2);
    expect(bill.lines.single.hours, 4);
    expect(bill.due, 400);
  });

  test('the bill carries what is left from earlier months', () {
    final joined = Student(id: 's1', name: 'أحمد', joinedAt: DateTime(2026, 8, 1));
    final g = _group(
      'g',
      PayType.monthly,
      400,
      slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 17 * 60, durationMin: 60)],
      students: ['s1'],
    );
    final d = AppData(students: [joined], groups: [g]);
    d.payments.add(Payment(id: 'a', studentId: 's1', month: '2026-08', amount: 400));
    d.payments.add(Payment(id: 'b', studentId: 's1', month: '2026-09', amount: 150));
    var bill = d.billFor(joined, '2026-10', DateTime(2026, 10, 10));
    expect(bill.due, 400);
    expect(bill.previous, 250);
    expect(bill.previousMonths, {'2026-09': 250});
    expect(bill.remaining, 650);
    expect(bill.status, PayStatus.unpaid);
    // Paying everything now clears both months.
    d.payments.add(Payment(id: 'c', studentId: 's1', month: '2026-10', amount: 650));
    bill = d.billFor(joined, '2026-10', DateTime(2026, 10, 10));
    expect(bill.remaining, 0);
    expect(bill.status, PayStatus.paid);
    expect(d.billFor(joined, '2026-11', DateTime(2026, 11, 10)).previous, 0);
  });

  test('the account counts lessons taken, paid and unpaid, oldest paid first', () {
    // October 2026: Sat 3, Tue 6, Sat 10, Tue 13. Saturday is one hour, Tuesday two.
    final g = _group(
      'g',
      PayType.perLesson,
      100,
      slots: [
        WeeklySlot(weekday: DateTime.saturday, startMin: 17 * 60, durationMin: 60),
        WeeklySlot(weekday: DateTime.tuesday, startMin: 17 * 60, durationMin: 120),
      ],
      students: ['s1'],
    );
    final d = AppData(students: [s], groups: [g]);
    final now = DateTime(2026, 10, 13, 23);
    var a = d.accountFor(s, now);
    expect(a.lessonsTaken, 4);
    expect(a.hours, 6);
    expect(a.due, 600);
    expect(a.status, PayStatus.unpaid);
    // Paying 300 covers Sat 3 and Tue 6.
    d.payments.add(Payment(id: 'p', studentId: 's1', month: '2026-10', amount: 300));
    a = d.accountFor(s, now);
    expect(a.lessonsPaid, 2);
    expect(a.lessonsUnpaid, 2);
    expect(a.remaining, 300);
    expect(a.unpaid.map((c) => c.date.day), [10, 13]);
    // An absence is not charged; a future lesson is not charged yet.
    d.absences.add(absenceKey(d.lessonsOn(DateTime(2026, 10, 13)).single, 's1'));
    a = d.accountFor(s, now);
    expect(a.remaining, 100);
    expect(d.accountFor(s, DateTime(2026, 10, 2)).due, 0);
  });

  test('lessons are counted again after everything owed is paid', () {
    // October 2026: Sat 3, 10, 17, 24, one hour at 100.
    final g = _group(
      'g',
      PayType.perLesson,
      100,
      slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 17 * 60, durationMin: 60)],
      students: ['s1'],
    );
    final d = AppData(students: [s], groups: [g]);
    final now = DateTime(2026, 10, 24, 23);
    // Paid the first two on the 12th: counting starts after that.
    d.payments.add(Payment(id: 'p', studentId: 's1', month: '2026-10', amount: 200, paidAt: DateTime(2026, 10, 12)));
    var a = d.accountFor(s, now);
    expect(a.since, DateTime(2026, 10, 12));
    expect(a.lessonsTaken, 2);
    expect(a.lessonsUnpaid, 2);
    expect(a.currentDue, 200);
    expect(a.currentPaid, 0);
    // Paying part of it does not start a new count.
    d.payments.add(
      Payment(id: 'q', studentId: 's1', month: '2026-10', amount: 100, paidAt: DateTime(2026, 10, 24, 20)),
    );
    a = d.accountFor(s, now);
    expect(a.since, DateTime(2026, 10, 12));
    expect(a.lessonsPaid, 1);
    // Paying it all does, even mid-month.
    d.payments.add(
      Payment(id: 'r', studentId: 's1', month: '2026-10', amount: 100, paidAt: DateTime(2026, 10, 24, 21)),
    );
    a = d.accountFor(s, now);
    expect(a.since, DateTime(2026, 10, 24, 21));
    expect(a.lessonsTaken, 0);
    expect(a.currentDue, 0);
    expect(a.remaining, 0);
    // Paid in full on the morning of a lesson day: that evening's lesson starts the new count.
    d.payments.clear();
    d.payments.add(Payment(id: 'p', studentId: 's1', month: '2026-10', amount: 300, paidAt: DateTime(2026, 10, 24, 9)));
    a = d.accountFor(s, now);
    expect(a.lessonsTaken, 1);
    expect(a.lessonsUnpaid, 1);
  });

  test('a monthly class still counts the lessons attended', () {
    final g = _group(
      'g',
      PayType.monthly,
      83,
      slots: [
        WeeklySlot(weekday: DateTime.saturday, startMin: 19 * 60 + 30, durationMin: 60),
        WeeklySlot(weekday: DateTime.monday, startMin: 19 * 60 + 30, durationMin: 60),
      ],
      students: ['s1'],
    );
    final d = AppData(students: [s], groups: [g]);
    // Sat 3, Mon 5, Sat 10, Mon 12.
    final a = d.accountFor(s, DateTime(2026, 10, 12, 23));
    expect(a.lessonsTaken, 4);
    expect(a.due, 83);
  });

  test('siblings sharing a three-hour lesson pay for their own hour', () {
    final g = _group(
      'g',
      PayType.perLesson,
      100,
      slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 19 * 60 + 30, durationMin: 180)],
      students: ['s1', 's2'],
    );
    final malak = Student(id: 's2', name: 'ملك', joinedAt: DateTime(2026, 10, 1), hoursOverrides: {'g': 1});
    final d = AppData(students: [s, malak], groups: [g]);
    final now = DateTime(2026, 10, 10, 23);
    // Sat 3 and Sat 10.
    expect(d.accountFor(malak, now).due, 200);
    expect(d.accountFor(malak, now).hours, 2);
    expect(d.accountFor(s, now).due, 600);
  });

  test('a holiday stops lessons, charges and reminders until it ends', () async {
    final store = AppStore(MemoryStorage());
    store.data = AppData(
      students: [s],
      groups: [
        _group(
          'g',
          PayType.perLesson,
          100,
          slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 18 * 60, durationMin: 60)],
          students: ['s1'],
        ),
      ],
    );
    final now = DateTime(2026, 10, 20, 12);
    expect(store.data.accountFor(s, now).due, 300); // 3, 10, 17 October
    await store.addBreak(DateTime(2026, 10, 9), DateTime(2026, 10, 18));
    expect(store.data.lessonsOn(DateTime(2026, 10, 10)), isEmpty);
    expect(store.data.accountFor(s, now).due, 100);
    expect(store.data.upcoming(DateTime(2026, 10, 9), days: 9), isEmpty);

    // An open-ended stop lasts until the teacher brings the lessons back.
    await store.addBreak(DateTime(2026, 10, 19), null);
    expect(store.data.lessonsOn(DateTime(2027, 3, 6)), isEmpty);
    await store.endBreak(store.data.breaks.last, DateTime(2026, 10, 31));
    expect(store.data.lessonsOn(DateTime(2026, 10, 24)), isEmpty);
    expect(store.data.lessonsOn(DateTime(2026, 10, 31)), hasLength(1));

    final reloaded = AppData.fromJson(jsonDecode(jsonEncode(store.data.toJson())) as Map<String, dynamic>);
    expect(reloaded.breaks.map((b) => b.to), [DateTime(2026, 10, 18), DateTime(2026, 10, 30)]);

    await store.archiveAllGroups();
    expect(store.data.groups.every((g) => g.archived), isTrue);
  });

  test('phone numbers keep their country code', () {
    expect(splitPhone('01012345678'), ('20', '1012345678'));
    expect(splitPhone('٠١٠١٢٣٤٥٦٧٨'), ('20', '1012345678'));
    expect(splitPhone('+966 50 123 4567'), ('966', '501234567'));
    expect(splitPhone('00971501234567'), ('971', '501234567'));
    expect(splitPhone('0501234567', fallback: '966'), ('966', '501234567'));
    expect(joinPhone('20', '010 1234 5678'), '+201012345678');
    expect(joinPhone('966', '0501234567'), '+966501234567');
    expect(joinPhone('20', ''), '');
  });

  test('siblings with a family price share one account and pay it once per lesson', () {
    Student kid(String id) => Student(id: id, name: id, family: 'محمود', joinedAt: DateTime(2026, 10, 1));
    final a = kid('a'), b = kid('b'), c = kid('c'), other = kid('o')..family = '';
    final d = AppData(
      students: [a, b, c, other],
      groups: [
        _group(
          'shared',
          PayType.perLesson,
          100,
          slots: [WeeklySlot(weekday: DateTime.saturday, startMin: 17 * 60, durationMin: 180)],
          students: ['a', 'b', 'c', 'o'],
        ),
        _group(
          'alone',
          PayType.perLesson,
          50,
          slots: [WeeklySlot(weekday: DateTime.monday, startMin: 17 * 60, durationMin: 60)],
          students: ['a'],
        ),
      ],
      familyPrices: {'محمود': 200},
    );
    final now = DateTime(2026, 10, 13, 12); // Saturdays 3 and 10, Monday 5 and 12
    d.absences.add(absenceKey(d.lessonsOn(DateTime(2026, 10, 10)).first, 'b'));
    final acc = d.accountFor(b, now);
    expect(acc.family, 'محمود');
    expect(acc.label, 'عيلة محمود');
    expect(acc.members.map((m) => m.id), ['b', 'a', 'c']);
    // Two shared Saturdays at 200 each, plus a's two lessons alone at 50.
    expect(acc.due, 2 * 200 + 2 * 50);
    expect(acc.attended, 1); // b missed the 10th
    d.payments.add(Payment(id: 'p', studentId: 'c', month: '2026-10', amount: 450));
    expect(d.accountFor(a, now).remaining, 50);
    expect(d.accountFor(b, now).remaining, 50);
    // Without the family price each child pays their own hours as before.
    d.familyPrices.clear();
    expect(d.accountFor(b, now).family, isNull);
    expect(d.accountFor(other, now).due, 2 * 300);
    final reloaded = AppData.fromJson(
      jsonDecode(jsonEncode((d..familyPrices['محمود'] = 200).toJson())) as Map<String, dynamic>,
    );
    expect(reloaded.familyPrices, {'محمود': 200.0});
  });
}
