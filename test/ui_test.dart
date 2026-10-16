import 'package:dorosi/data.dart';
import 'package:dorosi/main.dart';
import 'package:dorosi/models.dart';
import 'package:dorosi/store.dart';
import 'package:dorosi/ui/settings_page.dart';
import 'package:dorosi/ui/theme.dart';
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
    await t.scrollUntilVisible(
      find.textContaining('دولار'),
      200,
      scrollable: find.descendant(of: find.byType(SettingsPage), matching: find.byType(Scrollable)).first,
    );
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

  testWidgets('colour and dark mode can be changed from settings', (t) async {
    final store = await _open(t);
    await t.tap(find.text('التذكيرات'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('accent-2')));
    await t.pumpAndSettle();
    await t.tap(find.text('ليلي'));
    await t.pumpAndSettle();
    expect(store.data.settings.themeColor, 2);
    expect(store.data.settings.themeMode, 2);
    expect(AppColors.dark, isTrue);
    expect(Theme.of(t.element(find.text('ليلي'))).brightness, Brightness.dark);
    await t.enterText(find.widgetWithText(TextField, 'اسمك (للترحيب في الجدول)'), 'أستاذ محمد');
    await t.tap(find.text('الجدول'));
    await t.pumpAndSettle();
    expect(find.textContaining('يا أستاذ محمد'), findsOneWidget);
  });

  testWidgets('showcase mode hides the real students and saves nothing', (t) async {
    final store = await _open(t);
    var reminders = 0;
    store.onChanged = (_) => reminders++;
    await t.tap(find.text('التذكيرات'));
    await t.pumpAndSettle();
    await t.tap(find.text('اعرض بيانات تجريبية'));
    await t.pumpAndSettle();
    expect(store.showcase, isTrue);
    expect(find.text('وضع العرض: دي بيانات تجريبية'), findsOneWidget);
    await t.tap(find.text('الطلاب'));
    await t.pumpAndSettle();
    expect(find.text('أحمد'), findsNothing);
    expect(find.text('سارة إبراهيم'), findsOneWidget);
    expect(store.exportJson(), contains('"أحمد"'));
    await t.tap(find.text('خروج'));
    await t.pumpAndSettle();
    expect(store.showcase, isFalse);
    expect(find.text('أحمد'), findsOneWidget);
    expect(reminders, 0);
  });

  testWidgets('schedule switches to a list and every tab explains itself', (t) async {
    final store = await _open(t);
    for (final (i, tab) in ['الجدول', 'الطلاب', 'الحصص', 'الدفع', 'التذكيرات'].indexed) {
      await t.tap(find.text(tab).last);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('شرح').hitTestable().first);
      await t.pumpAndSettle();
      expect(find.text('تبويب $tab'), findsOneWidget, reason: 'tab $i');
      await t.tap(find.text('تمام'));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('الجدول').last);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('عرض قائمة'));
    await t.pumpAndSettle();
    expect(store.data.settings.scheduleView, 1);
    await t.scrollUntilVisible(find.text('النهارده'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('النهارده'), findsOneWidget);
  });

  testWidgets('a phone number is saved with the chosen country code', (t) async {
    final store = await _open(t);
    await t.tap(find.text('الطلاب'));
    await t.pumpAndSettle();
    await t.longPress(find.text('أحمد'));
    await t.pumpAndSettle();
    await t.tap(find.text('تعديل الاسم والبيانات'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('country')));
    await t.pumpAndSettle();
    await t.tap(find.text('السعودية'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'رقم الموبايل (اختياري)'), '0501234567');
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    expect(store.data.students.single.phone, '+966501234567');
  });
}
