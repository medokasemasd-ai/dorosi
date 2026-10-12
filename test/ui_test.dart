import 'package:dorosi/data.dart';
import 'package:dorosi/main.dart';
import 'package:dorosi/models.dart';
import 'package:dorosi/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppStore> _open(WidgetTester t) async {
  t.view.physicalSize = const Size(900, 2000);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  final store = AppStore(MemoryStorage());
  store.data = AppData(
    students: [Student(id: 's1', name: 'أحمد', joinedAt: DateTime(2026, 1, 1))],
  );
  store.loaded = true;
  await t.pumpWidget(DorosiApp(store: store));
  await t.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('currency can be changed to riyal and dollar', (t) async {
    final store = await _open(t);
    await t.tap(find.text('التذكيرات'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.textContaining('دولار'), 200, scrollable: find.byType(Scrollable).last);
    await t.ensureVisible(find.textContaining('دولار'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('دولار'));
    await t.pumpAndSettle();
    expect(store.data.settings.currency, r'$');
    await t.tap(find.textContaining('ريال'));
    await t.pumpAndSettle();
    expect(store.data.settings.currency, 'ر.س');
  });

  testWidgets('a student can be renamed and deleted from the students list', (t) async {
    final store = await _open(t);
    await t.tap(find.text('الطلاب'));
    await t.pumpAndSettle();
    await t.longPress(find.text('أحمد'));
    await t.pumpAndSettle();
    await t.tap(find.text('تعديل الاسم والبيانات'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'اسم الطالب'), 'أحمد علي');
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    expect(store.data.students.single.name, 'أحمد علي');

    await t.tap(find.text('أحمد علي'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('حذف الطالب'), 200, scrollable: find.byType(Scrollable).last);
    await t.ensureVisible(find.text('حذف الطالب'));
    await t.pumpAndSettle();
    await t.tap(find.text('حذف الطالب'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'حذف'));
    await t.pumpAndSettle();
    expect(store.data.students, isEmpty);
  });

  testWidgets('student page shows the month lessons week by week', (t) async {
    final store = await _open(t);
    final now = DateTime.now();
    store.data.groups.add(
      Group(
        id: 'g',
        name: 'أحمد رياضيات',
        kind: GroupKind.individual,
        prices: [PriceChange(fromMonth: '0000-00', amount: 300)],
        slots: [
          WeeklySlot(weekday: DateTime.saturday, startMin: 17 * 60, durationMin: 60),
          WeeklySlot(weekday: DateTime.tuesday, startMin: 17 * 60, durationMin: 60),
        ],
        studentIds: ['s1'],
        createdAt: DateTime(now.year, now.month),
      ),
    );
    await store.saveGroup(store.data.groups.single);
    await t.tap(find.text('الطلاب'));
    await t.pumpAndSettle();
    await t.tap(find.text('أحمد'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('الحضور'), 200, scrollable: find.byType(Scrollable).last);
    await t.ensureVisible(find.text('الحضور'));
    await t.pumpAndSettle();
    expect(find.textContaining('أسبوع'), findsWidgets);
  });

  testWidgets('payments tab lists who owes in lessons', (t) async {
    final store = await _open(t);
    final now = DateTime.now();
    store.data.students.single.joinedAt = DateTime(now.year, now.month, now.day - 6);
    store.data.groups.add(
      Group(
        id: 'g',
        name: 'رياضيات',
        payType: PayType.perLesson,
        prices: [PriceChange(fromMonth: '0000-00', amount: 100)],
        slots: [for (var w = 1; w <= 7; w++) WeeklySlot(weekday: w, startMin: 0, durationMin: 60)],
        studentIds: ['s1'],
        createdAt: DateTime(now.year, now.month - 1),
      ),
    );
    store.data.payments.add(Payment(id: 'p', studentId: 's1', month: monthKey(now), amount: 300));
    await store.saveGroup(store.data.groups.single);
    await t.tap(find.text('الدفع'));
    await t.pumpAndSettle();
    expect(find.text('أحمد'), findsOneWidget);
    // Seven lessons taken (six days ago up to today), three paid: four left, 400.
    expect(find.text('٤٠٠'), findsWidgets);
    expect(find.text('٤'), findsWidgets);
    await t.tap(find.text('أحمد'));
    await t.pumpAndSettle();
    expect(find.text('تسجيل دفع'), findsOneWidget);
  });
}
