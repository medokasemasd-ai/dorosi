import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data.dart';
import '../format.dart';

const _provider = 'com.aboelkasem.dorosi.NextLessonWidget';

/// The lessons the home-screen widget can show, in the form the Android side reads.
List<Map<String, dynamic>> widgetLessons(AppData d, DateTime now, {int days = 14}) => [
      for (final l in d.upcoming(now, days: days))
        {
          'start': l.start.millisecondsSinceEpoch,
          'end': l.end.millisecondsSinceEpoch,
          'title': l.group.name,
          'time': '${fmtTime(l.startMin)} – ${fmtTime(l.startMin + l.durationMin)}',
          'dayName': weekdayName(l.date.weekday),
          'who': _who(d, l),
        }
    ];

String _who(AppData d, Lesson l) {
  final s = d.studentsOf(l.group);
  if (s.isEmpty) return '';
  if (s.length == 1) return s.first.name;
  return studentsCount(s.length);
}

/// Sends the coming lessons to the widget and asks Android to redraw it at
/// each lesson start and end, so it always shows the right one.
Future<void> syncHomeWidget(AppData d) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final now = DateTime.now();
    final lessons = widgetLessons(d, now);
    await HomeWidget.saveWidgetData<String>('lessons', jsonEncode(lessons));
    await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    final times = <DateTime>{
      for (final l in lessons) ...[
        DateTime.fromMillisecondsSinceEpoch(l['start'] as int),
        DateTime.fromMillisecondsSinceEpoch(l['end'] as int),
      ],
      DateTime(now.year, now.month, now.day + 1),
    }.where((t) => t.isAfter(now)).toList()
      ..sort();
    await HomeWidget.scheduleWidgetUpdates(times.take(60).toList(), qualifiedAndroidName: _provider);
  } catch (e) {
    debugPrint('widget sync failed: $e');
  }
}
