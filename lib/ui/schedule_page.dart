import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'day_page.dart';
import 'group_form.dart';
import 'breaks.dart';
import 'help.dart';
import 'settings_page.dart';
import 'theme.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

/// The home page: today's lessons with attendance, and the other days of the week a tap away.
class _SchedulePageState extends State<SchedulePage> {
  DateTime? _picked;
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
    final today = dateOnly(now);
    final day = _picked ?? today;
    final week = weekStart(today);
    final days = [for (var i = 0; i < 7; i++) DateTime(week.year, week.month, week.day + i)];
    final lessons = d.lessonsOn(day);
    final isToday = day == today;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => openGroupForm(context),
        icon: const Icon(Icons.add),
        label: const Text('حصة جديدة'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          now.hour < 12 ? 'صباح الخير' : 'مساء الخير',
                          if (d.settings.teacherName.trim().isNotEmpty) 'يا ${d.settings.teacherName.trim()}',
                        ].join(' '),
                        style: TextStyle(color: AppColors.muted, fontSize: 14),
                      ),
                      Text(fmtDate(now), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const HelpButton(0),
                IconButton(
                  tooltip: 'الإعدادات',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const BreakBanner(),
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
            else ...[
              _NextLessonCard(lesson: d.nextLesson(now), now: now),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final x in days)
                    Expanded(
                      child: _DayChip(
                        day: x,
                        selected: x == day,
                        isToday: x == today,
                        busy: d.lessonsOn(x).any((l) => !l.cancelled),
                        onTap: () => setState(() => _picked = x),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isToday ? 'حصص النهارده' : 'حصص ${dayLabel(day, now)}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeekPage())),
                    icon: const Icon(Icons.calendar_view_week_outlined, size: 18),
                    label: const Text('الأسبوع كله'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (lessons.isEmpty)
                Panel(
                  child: Text(
                    d.onBreak(day) != null ? 'إجازة 🏖️' : 'مفيش حصص في اليوم ده',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                for (final l in lessons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LessonCard(lesson: l),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One day of this week in the strip above today's lessons.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.busy,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onPrimary : (isToday ? AppColors.primary : AppColors.ink);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  weekdayName(day.weekday).replaceAll('ال', ''),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(fontSize: 11, color: fg),
                ),
                Text(
                  arNum(day.day),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 2),
                CircleAvatar(
                  radius: 2.5,
                  backgroundColor: busy ? (selected ? AppColors.onPrimary : AppColors.primary) : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The whole week, as day cards or a list.
class WeekPage extends StatefulWidget {
  const WeekPage({super.key});

  @override
  State<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> {
  late DateTime _week = weekStart(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final now = DateTime.now();
    final days = [for (var i = 0; i < 7; i++) DateTime(_week.year, _week.month, _week.day + i)];
    final perDay = {for (final day in days) day: d.lessonsOn(day).where((l) => !l.cancelled).toList()};
    final totalLessons = perDay.values.fold<int>(0, (a, l) => a + l.length);
    final isThisWeek = _week == weekStart(now);
    final listView = d.settings.scheduleView == 1;

    return Scaffold(
      appBar: AppBar(title: const Text('الأسبوع')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
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
                visualDensity: VisualDensity.compact,
                tooltip: listView ? 'عرض مربعات' : 'عرض قائمة',
                onPressed: () => store.updateSettings((x) => x.scheduleView = listView ? 0 : 1),
                icon: Icon(listView ? Icons.grid_view_outlined : Icons.view_agenda_outlined),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'الأسبوع السابق',
                onPressed: () => setState(() => _week = DateTime(_week.year, _week.month, _week.day - 7)),
                icon: const Icon(Icons.chevron_left),
              ),
              if (!isThisWeek)
                TextButton(onPressed: () => setState(() => _week = weekStart(now)), child: const Text('الحالي')),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'الأسبوع التالي',
                onPressed: () => setState(() => _week = DateTime(_week.year, _week.month, _week.day + 7)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (listView)
            for (final day in days) _DayRow(day: day, lessons: perDay[day]!, data: d, now: now)
          else
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
                Text(data.onBreak(day) != null ? 'إجازة' : 'لا حصص', style: TextStyle(color: sub, fontSize: 13))
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

/// One day in the list view: the day, then each lesson with its time.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.lessons, required this.data, required this.now});

  final DateTime day;
  final List<Lesson> lessons;
  final AppData data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isToday = dateOnly(day) == dateOnly(now);
    void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => DayPage(day: day)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: lessons.isEmpty ? Colors.transparent : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isToday
              ? BorderSide(color: AppColors.primary, width: 2)
              : (lessons.isEmpty ? BorderSide(color: AppColors.line) : BorderSide.none),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 62,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekdayName(day.weekday),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isToday ? AppColors.primary : AppColors.ink,
                        ),
                      ),
                      Text(
                        isToday ? 'النهارده' : fmtShortDate(day),
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: lessons.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            data.onBreak(day) != null ? 'إجازة' : 'لا حصص',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : Column(
                          children: [
                            for (final l in lessons)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        fmtTime(l.startMin),
                                        style: TextStyle(
                                          color: AppColors.onPrimarySoft,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(l.group.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    Text(
                                      studentsCount(data.studentsOf(l.group).length),
                                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
