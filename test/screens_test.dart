import 'package:dorosi/demo.dart';
import 'package:dorosi/main.dart';
import 'package:dorosi/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final tab in ['الجدول', 'الطلاب', 'الحصص', 'الدفع', 'التذكيرات']) {
    testWidgets('tab $tab fits a small phone', (t) async {
      t.view.physicalSize = const Size(900, 2000);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      final store = AppStore(MemoryStorage(demoJson()));
      await store.load();
      await t.pumpWidget(DorosiApp(store: store));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(tab).last);
      await t.pump(const Duration(seconds: 1));
    });
  }
}
