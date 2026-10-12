import 'package:dorosi/demo.dart';
import 'package:dorosi/main.dart';
import 'package:dorosi/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final tab in ['الجدول', 'الطلاب', 'الحصص', 'الدفع', 'التذكيرات']) {
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
        await t.tap(find.text(tab).last);
        await t.pump(const Duration(seconds: 1));
      });
    }
  }
}
