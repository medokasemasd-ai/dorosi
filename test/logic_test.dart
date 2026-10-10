import 'dart:convert';

import 'package:dorosi/data.dart';
import 'package:dorosi/demo.dart';
import 'package:dorosi/format.dart';
import 'package:dorosi/models.dart';
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
  final s = Student(id: 's1', name: 'أحمد', joinedAt: DateTime(2026, 1, 1));

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
      final d = AppData(students: [s], groups: [g]);
      expect(d.billFor(s, '2026-09', DateTime(2026, 10, 10)).due, 300);
      expect(d.billFor(s, '2026-10', DateTime(2026, 10, 10)).due, 350);
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
          DatedSession(date: DateTime(2026, 10, 12), startMin: 20 * 60, durationMin: 120),
          DatedSession(date: DateTime(2026, 10, 14), startMin: 20 * 60, durationMin: 120),
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
}
