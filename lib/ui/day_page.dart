import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'group_form.dart';
import 'student_page.dart';
import 'theme.dart';

class DayPage extends StatelessWidget {
  const DayPage({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final lessons = d.lessonsOn(day);
    final active = lessons.where((l) => !l.cancelled).toList();
    final students = {for (final l in active) ...d.studentsOf(l.group).map((s) => s.id)}.length;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtDate(day)),
            Text(
              '${lessonsCount(active.length)} · ${studentsCount(students)}',
              style: TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => openGroupForm(context, weekday: day.weekday),
        icon: const Icon(Icons.add),
        label: Text('حصة يوم ${weekdayName(day.weekday)}'),
      ),
      body: lessons.isEmpty
          ? const EmptyState(icon: Icons.free_breakfast_outlined, text: 'مفيش حصص في اليوم ده')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: lessons.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => LessonCard(lesson: lessons[i]),
            ),
    );
  }
}

class LessonCard extends StatelessWidget {
  const LessonCard({super.key, required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final l = lesson;
    final g = l.group;
    final now = DateTime.now();
    final members = d.studentsOf(g);
    final happened = !l.start.isAfter(now);
    final upcoming = d.nextLesson(now)?.key == l.key;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: upcoming && !l.cancelled ? Border.all(color: AppColors.primary, width: 2) : null,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fmtTime(l.startMin)} – ${fmtTime(l.startMin + l.durationMin)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: l.cancelled ? AppColors.muted : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      g.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        decoration: l.cancelled ? TextDecoration.lineThrough : null,
                        color: l.cancelled ? AppColors.muted : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        KindPill(g),
                        if (g.stage.isNotEmpty) Pill(g.stage, fg: AppColors.ink, bg: AppColors.soft),
                        if (l.extra) Pill('حصة زيادة', fg: AppColors.primary, bg: AppColors.primarySoft),
                        if (l.cancelled) Pill('ملغية', fg: AppColors.unpaid, bg: AppColors.unpaidSoft),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'خيارات',
                onSelected: (v) => lessonAction(context, l, v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'cancel', child: Text(l.cancelled ? 'إرجاع الحصة' : 'إلغاء حصة اليوم ده بس')),
                  const PopupMenuItem(value: 'move', child: Text('نقل الحصة ليوم أو معاد تاني')),
                  const PopupMenuItem(value: 'extra', child: Text('إضافة حصة زيادة (تعويض)')),
                  if (l.extra) const PopupMenuItem(value: 'remove', child: Text('حذف الحصة الزيادة دي')),
                  CheckedPopupMenuItem(
                    value: 'remindStart',
                    checked: g.remindStart,
                    child: const Text('تذكير البداية'),
                  ),
                  CheckedPopupMenuItem(value: 'remindEnd', checked: g.remindEnd, child: const Text('تذكير النهاية')),
                  const PopupMenuItem(value: 'edit', child: Text('تعديل المواعيد الثابتة')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (members.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('مفيش طلاب في الحصة دي لسه', style: TextStyle(color: AppColors.muted)),
            ),
          for (final s in members)
            _StudentRow(
              student: s,
              absent: d.isAbsent(l, s.id),
              showAttendance: happened && !l.cancelled,
              onToggleAbsent: () => store.toggleAbsent(l, s.id),
            ),
        ],
      ),
    );
  }
}

/// Runs a lesson menu choice: cancel, move, add an extra lesson, remove an extra one, edit the class.
Future<void> lessonAction(BuildContext context, Lesson l, String v) async {
  final store = StoreScope.read(context);
  switch (v) {
    case 'remindStart':
      await store.setGroupReminder(l.group, start: !l.group.remindStart);
    case 'remindEnd':
      await store.setGroupReminder(l.group, end: !l.group.remindEnd);
    case 'edit':
      await openGroupForm(context, group: l.group);
    case 'cancel':
      await store.setCancelled(l, !l.cancelled);
    case 'move':
      final p = await pickDayAndTime(context, 'تنقل الحصة لإمتى؟', l.date, l.startMin);
      if (p == null) return;
      await store.moveLesson(l, p.$1, p.$2);
      if (context.mounted) toast(context, 'الحصة اتنقلت ليوم ${weekdayName(p.$1.weekday)} ${fmtShortDate(p.$1)}');
    case 'extra':
      final p = await pickDayAndTime(context, 'الحصة الزيادة إمتى؟', l.date, l.startMin);
      if (p == null) return;
      await store.addExtraLesson(l.group, p.$1, p.$2, l.durationMin);
      if (context.mounted) toast(context, 'اتضافت حصة يوم ${weekdayName(p.$1.weekday)} ${fmtShortDate(p.$1)}');
    case 'remove':
      if (await confirm(context, 'حذف الحصة الزيادة؟', 'الحصة دي بس هتتشال من الجدول.', ok: 'حذف', danger: true)) {
        await store.removeExtraLesson(l);
      }
  }
}

/// Asks for a date, then a start time. Returns null if either is dismissed.
Future<(DateTime, int)?> pickDayAndTime(BuildContext context, String title, DateTime date, int startMin) async {
  final d = await showDatePicker(
    context: context,
    helpText: title,
    initialDate: date,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(
    context: context,
    helpText: 'الساعة كام؟',
    initialTime: TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60),
  );
  if (t == null) return null;
  return (dateOnly(d), t.hour * 60 + t.minute);
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.absent,
    required this.showAttendance,
    required this.onToggleAbsent,
  });

  final Student student;
  final bool absent;
  final bool showAttendance;
  final VoidCallback onToggleAbsent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentPage(studentId: student.id))),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 6, bottom: 6, end: 8),
        child: Row(
          children: [
            Avatar(student.name, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: const TextStyle(fontSize: 15)),
                  if (student.family.isNotEmpty)
                    Text('إخوات: ${student.family}', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            if (showAttendance) ...[
              TextButton(
                onPressed: onToggleAbsent,
                style: TextButton.styleFrom(
                  foregroundColor: absent ? AppColors.unpaid : AppColors.paid,
                  minimumSize: const Size(56, 36),
                ),
                child: Text(absent ? 'غاب' : 'حضر'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
