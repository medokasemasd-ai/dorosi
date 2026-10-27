import 'package:dorosi/demo.dart';
import 'package:dorosi/main.dart';
import 'package:dorosi/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final tab in ['الجدول', 'الطلاب', 'المواعيد الثابتة', 'الدفع', 'الإعدادات', 'الأسبوع كله']) {
      testWidgets('tab $tab fits a small phone${dark ? ' in dark mode' : ''}', (t) async {
        t.view.physicalSize = const Size(900, 2000);
        t.view.devicePixelRatio = 2.5;
        addTearDown(t.view.reset);
        final store = AppStore(MemoryStorage(demoJson()));
        await store.load();
        store.data.settings
          ..themeMode = dark ? 2 : 1
          ..themeColor = dark ? 3 : 0;
        await t.pumpWidget(DorosiApp(store: store));
        await t.pump(const Duration(seconds: 1));
        if (tab == 'الإعدادات') {
          await t.tap(find.byTooltip(tab));
          for (var i = 0; i < 10; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
          await t.drag(find.byType(ListView).last, const Offset(0, -1200));
          await t.pump(const Duration(seconds: 1));
          await t.tap(find.text('المزيد'));
        } else if (tab == 'المواعيد الثابتة') {
          await t.scrollUntilVisible(find.text(tab), 300, scrollable: find.byType(Scrollable).first);
          await t.tap(find.text(tab));
        } else {
          await t.tap(find.text(tab).last);
        }
        await t.pump(const Duration(seconds: 1));
      });
    }
  }
}
