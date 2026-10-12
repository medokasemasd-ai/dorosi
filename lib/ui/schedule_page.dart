import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'day_page.dart';
import 'group_form.dart';
import 'theme.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.onOpenTab});

  final void Function(int tab) onOpenTab;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _week = weekStart(DateTime.now());
  late Timer _tick;

  @override
  void initState() {
    super.initState();
    // Keeps the countdown on the next-lesson card current.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final now = DateTime.now();
    final next = d.nextLesson(now);
    final days = [for (var i = 0; i < 7; i++) DateTime(_week.year, _week.month, _week.day + i)];
    final perDay = {for (final day in days) day: d.lessonsOn(day).where((l) => !l.cancelled).toList()};
    final totalLessons = perDay.values.fold<int>(0, (a, l) => a + l.length);
    final isThisWeek = _week == weekStart(now);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => openGroupForm(context),
        icon: const Icon(Icons.add),
        label: const Text('حصة جديدة'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            Text(
              [
                now.hour < 12 ? 'صباح الخير' : 'مساء الخير',
                if (d.settings.teacherName.trim().isNotEmpty) 'يا ${d.settings.teacherName.trim()}',
              ].join(' '),
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            Text(fmtDate(now), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (d.groups.isEmpty)
              Panel(
                child: EmptyState(
                  icon: Icons.event_note_outlined,
                  text: 'لسه مفيش حصص.\nابدأ بإضافة أول حصة أو مجموعة، وبعدها ضيف الطلاب.',
                  action: FilledButton.icon(
                    onPressed: () => openGroupForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة حصة'),
                  ),
                ),
              )
            else
              _NextLessonCard(lesson: next, now: now),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isThisWeek ? 'أيام الأسبوع' : 'أسبوع ${fmtShortDate(_week)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${fmtShortDate(days.first)} – ${fmtShortDate(days.last)} · ${lessonsCount(totalLessons)}',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'الأسبوع السابق',
                  onPressed: () => setState(() => _week = DateTime(_week.year, _week.month, _week.day - 7)),
                  icon: const Icon(Icons.chevron_left),
                ),
                if (!isThisWeek)
                  TextButton(onPressed: () => setState(() => _week = weekStart(now)), child: const Text('الحالي')),
                IconButton(
                  tooltip: 'الأسبوع التالي',
                  onPressed: () => setState(() => _week = DateTime(_week.year, _week.month, _week.day + 7)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < 7; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _DayCard(day: days[i], lessons: perDay[days[i]]!, data: d, now: now),
                      ),
                      if (i + 1 < 7) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DayCard(day: days[i + 1], lessons: perDay[days[i + 1]]!, data: d, now: now),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NextLessonCard extends StatelessWidget {
  const _NextLessonCard({required this.lesson, required this.now});

  final Lesson? lesson;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final d = StoreScope.of(context).data;
    final l = lesson;
    return Material(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: l == null
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => DayPage(day: l.date))),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: l == null
              ? const Text('مفيش حصص في الأيام الجاية', style: TextStyle(color: Colors.white, fontSize: 16))
              : _content(d, l),
        ),
      ),
    );
  }

  Widget _content(AppData d, Lesson l) {
    final ongoing = !l.start.isAfter(now);
    final members = d.studentsOf(l.group);
    final reminderOn = d.settings.remindStart && l.group.remindStart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ongoing ? 'الحصة الحالية' : 'الحصة القادمة',
                style: TextStyle(color: AppColors.navyText, fontSize: 13),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    reminderOn ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    reminderOn ? 'التذكير مفعّل' : 'التذكير مقفول',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          l.group.name,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${dayLabel(l.date, now)} · ${fmtTime(l.startMin)} – ${fmtTime(l.startMin + l.durationMin)} · '
          '${members.length == 1 ? members.first.name : studentsCount(members.length)}',
          style: TextStyle(color: AppColors.navyText, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Text(
          ongoing ? 'تنتهي ${fmtCountdown(l.end.difference(now))}' : 'تبدأ ${fmtCountdown(l.start.difference(now))}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.lessons, required this.data, required this.now});

  final DateTime day;
  final List<Lesson> lessons;
  final AppData data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isToday = dateOnly(day) == dateOnly(now);
    final students = {for (final l in lessons) ...data.studentsOf(l.group).map((s) => s.id)}.length;
    final hasReview = lessons.any(
      (l) => l.group.sessions.isNotEmpty && l.group.slots.every((s) => s.weekday != day.weekday),
    );
    final fg = isToday ? AppColors.onPrimary : AppColors.ink;
    final sub = isToday ? AppColors.onPrimary.withValues(alpha: 0.8) : AppColors.muted;
    return Material(
      color: isToday ? AppColors.primary : (lessons.isEmpty ? Colors.transparent : AppColors.card),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: lessons.isEmpty && !isToday ? BorderSide(color: AppColors.line) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DayPage(day: day))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      weekdayName(day.weekday),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fg),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.onPrimary, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        'اليوم',
                        style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    Text(arNum(day.day), style: TextStyle(color: sub, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              if (lessons.isEmpty)
                Text('لا حصص', style: TextStyle(color: sub, fontSize: 13))
              else ...[
                Text(
                  '${lessonsCount(lessons.length)} · ${studentsCount(students)}',
                  style: TextStyle(color: sub, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text('من ${fmtTime(lessons.first.startMin)}', style: TextStyle(color: sub, fontSize: 12)),
                if (hasReview) ...[
                  const SizedBox(height: 6),
                  Pill('مراجعة', fg: AppColors.review, bg: AppColors.reviewSoft),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
