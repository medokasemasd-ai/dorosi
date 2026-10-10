import 'dart:convert';

import 'data.dart';
import 'models.dart';

/// Sample data for the web preview only. The phone app starts empty.
String demoJson() {
  final now = DateTime.now();
  final month = DateTime(now.year, now.month);
  var n = 0;
  String id() => 'demo${n++}';

  Student st(String name, String stage, {String family = '', String phone = ''}) =>
      Student(id: id(), name: name, stage: stage, family: family, phone: phone, joinedAt: month);

  final ahmed = st('أحمد محمود', 'الثالث الثانوي', family: 'محمود', phone: '01000000000');
  final mariam = st('مريم محمود', 'الأول الثانوي', family: 'محمود');
  final youssef = st('يوسف علي', 'الثالث الثانوي');
  final sara = st('سارة إبراهيم', 'الثالث الثانوي');
  final omar = st('عمر خالد', 'الثاني الثانوي');
  final salma = st('سلمى طارق', 'الثاني الثانوي');
  final nour = st('نور الدين صالح', 'الأول الثانوي');
  final karim = st('كريم سامي', 'الثالث الثانوي');

  Group g(String name, String stage, GroupKind kind, PayType pay, double price, List<WeeklySlot> slots,
          List<Student> students, {List<DatedSession>? sessions}) =>
      Group(
        id: id(),
        name: name,
        stage: stage,
        kind: kind,
        payType: pay,
        prices: [PriceChange(fromMonth: '0000-00', amount: price)],
        slots: slots,
        sessions: sessions,
        studentIds: students.map((s) => s.id).toList(),
        createdAt: month,
      );

  final groups = [
    g('الثالث الثانوي · مجموعة أ', 'الثالث الثانوي', GroupKind.group, PayType.monthly, 400, [
      WeeklySlot(weekday: DateTime.saturday, startMin: 18 * 60, durationMin: 90),
      WeeklySlot(weekday: DateTime.tuesday, startMin: 18 * 60, durationMin: 90),
    ], [ahmed, youssef, sara]),
    g('الأول الثانوي · مجموعة ج', 'الأول الثانوي', GroupKind.group, PayType.monthly, 300, [
      WeeklySlot(weekday: DateTime.saturday, startMin: 19 * 60 + 45, durationMin: 90),
      WeeklySlot(weekday: DateTime.wednesday, startMin: 17 * 60, durationMin: 90),
    ], [mariam, nour]),
    g('عمر خالد (فردي)', 'الثاني الثانوي', GroupKind.individual, PayType.perLesson, 150, [
      WeeklySlot(weekday: DateTime.sunday, startMin: 17 * 60, durationMin: 60),
      WeeklySlot(weekday: DateTime.thursday, startMin: 17 * 60, durationMin: 60),
    ], [omar]),
    g('الثاني الثانوي · مجموعة ب', 'الثاني الثانوي', GroupKind.group, PayType.monthly, 350, [
      WeeklySlot(weekday: DateTime.monday, startMin: 18 * 60, durationMin: 90),
    ], [salma, omar]),
    g('مراجعة نهائية · كريم', 'الثالث الثانوي', GroupKind.review, PayType.perLesson, 200, [], [karim], sessions: [
      DatedSession(date: DateTime(now.year, now.month, now.day + 2), startMin: 20 * 60, durationMin: 120),
      DatedSession(date: DateTime(now.year, now.month, now.day + 4), startMin: 20 * 60, durationMin: 120),
    ]),
  ];
  // Sibling discount for Mariam.
  mariam.priceOverrides[groups[1].id] = 250;

  final data = AppData(
    groups: groups,
    students: [ahmed, mariam, youssef, sara, omar, salma, nour, karim],
    payments: [
      Payment(id: id(), studentId: ahmed.id, month: monthKey(now), amount: 400),
      Payment(id: id(), studentId: youssef.id, month: monthKey(now), amount: 400),
      Payment(id: id(), studentId: nour.id, month: monthKey(now), amount: 150),
      Payment(id: id(), studentId: salma.id, month: monthKey(now), amount: 350),
    ],
  );
  return jsonEncode(data.toJson());
}
