import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data.dart';
import '../format.dart';

/// One reminder the app wants the phone to show.
class PlannedReminder {
  PlannedReminder(this.id, this.at, this.title, this.body, this.channel);

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String channel;
}

/// Works out every reminder for the coming [days] days. Pure, so it can be tested.
List<PlannedReminder> planReminders(AppData d, DateTime now, {int days = 28}) {
  final s = d.settings;
  final out = <PlannedReminder>[];
  var id = 1;
  for (final l in d.upcoming(now, days: days)) {
    final members = d.studentsOf(l.group);
    final who = members.length == 1 ? members.first.name : studentsCount(members.length);
    if (s.remindStart && l.group.remindStart) {
      final at = l.start.subtract(Duration(minutes: s.startLeadMin));
      if (at.isAfter(now)) {
        final lead = s.startLeadMin == 0 ? 'الآن' : 'بعد ${minutesCount(s.startLeadMin)}';
        out.add(
          PlannedReminder(id, at, 'تبدأ الحصة $lead', '${l.group.name} · ${fmtTime(l.startMin)} · $who', 'start'),
        );
      }
    }
    id++;
    if (s.remindEnd && l.group.remindEnd && l.end.isAfter(now)) {
      out.add(
        PlannedReminder(id, l.end, 'انتهت الحصة', '${l.group.name} · ${fmtTime(l.startMin + l.durationMin)}', 'end'),
      );
    }
    id++;
  }

  if (s.remindPayment) {
    for (var i = 0; i < 3; i++) {
      final m = DateTime(now.year, now.month + i);
      final lastDay = DateTime(m.year, m.month + 1, 0).day;
      final day = s.paymentDay <= 0 || s.paymentDay > lastDay ? lastDay : s.paymentDay;
      final at = DateTime(m.year, m.month, day, s.paymentHour);
      if (at.isAfter(now)) {
        out.add(
          PlannedReminder(
            900000 + i,
            at,
            'مراجعة مدفوعات ${monthName(m)}',
            'افتح دروسي وشوف مين دفع ومين لسه',
            'payment',
          ),
        );
      }
    }
  }

  // Reminders are planned a few weeks ahead; nudge the user to open the app
  // before they run out.
  out.add(
    PlannedReminder(
      999999,
      now.add(Duration(days: days - 1)),
      'افتح دروسي',
      'افتح التطبيق مرة عشان التذكيرات تفضل شغالة',
      'payment',
    ),
  );
  return out;
}

class Reminders {
  Reminders._();
  static final instance = Reminders._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channels = {
    'start': ('بداية الحصة', 'تذكير قبل بداية كل حصة'),
    'end': ('نهاية الحصة', 'تنبيه عند انتهاء الحصة'),
    'payment': ('المدفوعات', 'تذكير مراجعة المدفوعات آخر الشهر'),
  };

  Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notification')),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> _queue = Future.value();

  /// Replaces all scheduled reminders. Calls are run one after another.
  Future<void> reschedule(AppData d) {
    if (!_ready) return Future.value();
    return _queue = _queue.then((_) => _reschedule(d)).catchError((Object e) {
      debugPrint('reschedule failed: $e');
    });
  }

  Future<void> _reschedule(AppData d) async {
    await _plugin.cancelAll();
    var mode = AndroidScheduleMode.exactAllowWhileIdle;
    for (final r in planReminders(d, DateTime.now())) {
      final ch = _channels[r.channel]!;
      Future<void> schedule() => _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            r.channel,
            ch.$1,
            channelDescription: ch.$2,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
          ),
        ),
        androidScheduleMode: mode,
      );
      try {
        await schedule();
      } catch (e) {
        // Exact alarms can be switched off by the user; fall back to inexact ones.
        if (mode == AndroidScheduleMode.inexactAllowWhileIdle) rethrow;
        mode = AndroidScheduleMode.inexactAllowWhileIdle;
        await schedule();
      }
    }
  }

  Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 1,
      title: 'تجربة التذكير',
      body: 'التذكيرات شغالة تمام',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'start',
          'بداية الحصة',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }
}
