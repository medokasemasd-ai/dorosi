import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../data.dart';
import 'common.dart';
import 'day_page.dart';
import 'group_form.dart';
import 'payment_sheet.dart';
import 'student_form.dart';
import 'theme.dart';

class StudentPage extends StatefulWidget {
  const StudentPage({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final s = d.student(widget.studentId);
    if (s == null) return const Scaffold(body: SizedBox());
    final currency = d.settings.currency;
    final month = monthKey(_month);
    final bill = d.billFor(s, month, DateTime.now());
    final groups = d.groupsOf(s);
    final siblings = d.siblingsOf(s);
    final payments = d.payments.where((p) => p.studentId == s.id).toList()
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.name),
        actions: [
          IconButton(
            tooltip: 'تعديل',
            onPressed: () => openStudentForm(context, student: s),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'archive') {
                await store.setStudentArchived(s, !s.archived);
              } else if (v == 'delete') {
                if (await deleteStudentAsk(context, s) && context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'archive', child: Text(s.archived ? 'رجّعه للطلاب الحاليين' : 'نقله للسابقين')),
              const PopupMenuItem(value: 'delete', child: Text('حذف الطالب')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            child: Row(
              children: [
                Avatar(s.name, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                      if (s.stage.isNotEmpty) Text(s.stage, style: const TextStyle(color: AppColors.muted)),
                      if (s.phone.isNotEmpty)
                        Text(
                          arDigits(s.phone),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      if (s.archived) const Pill('من الطلاب السابقين', fg: AppColors.muted, bg: AppColors.soft),
                    ],
                  ),
                ),
                if (s.phone.isNotEmpty) ...[
                  IconButton.filledTonal(
                    tooltip: 'اتصال',
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: s.phone)),
                    icon: const Icon(Icons.call_outlined),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'واتساب',
                    onPressed: () => launchUrl(
                      Uri.parse('https://wa.me/${whatsappNumber(s.phone)}'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.chat_outlined),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle(
            'حساب الشهر',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'الشهر السابق',
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(monthName(_month, withYear: true)),
                IconButton(
                  tooltip: 'الشهر التالي',
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('الحالة', style: TextStyle(color: AppColors.muted)),
                    ),
                    StatusPill(bill.status),
                  ],
                ),
                const SizedBox(height: 10),
                if (bill.lines.isEmpty) const Text('مفيش مستحق في الشهر ده', style: TextStyle(color: AppColors.muted)),
                for (final l in bill.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(billLineText(l, currency))),
                        Text(fmtMoney(l.amount, currency), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                if (bill.previous > 0) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('باقي من الشهور اللي قبل كده', style: TextStyle(color: AppColors.unpaid)),
                        ),
                        Text(
                          fmtMoney(bill.previous, currency),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.unpaid),
                        ),
                      ],
                    ),
                  ),
                  for (final e in bill.previousMonths.entries)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 12, bottom: 4),
                      child: Text(
                        '${monthName(parseMonthKey(e.key), withYear: true)}: ${fmtMoney(e.value, currency)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ),
                ],
                if (bill.previous < 0)
                  Text(
                    'مدفوع مقدم من قبل كده: ${fmtMoney(-bill.previous, currency)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.paid),
                  ),
                const Divider(height: 20),
                _line(
                  bill.previous == 0 ? 'المستحق' : 'المستحق كله',
                  fmtMoney(bill.totalDue < 0 ? 0 : bill.totalDue, currency),
                ),
                _line('المدفوع', fmtMoney(bill.paid, currency), color: AppColors.paid),
                _line(
                  'الباقي',
                  fmtMoney(bill.remaining, currency),
                  color: bill.remaining > 0 ? AppColors.unpaid : AppColors.ink,
                  bold: true,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => showPaymentSheet(context, s, month),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('تسجيل دفع'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _LessonLog(student: s, month: _month),
          const SizedBox(height: 16),
          const SectionTitle('الحصص'),
          if (groups.isEmpty)
            const Text('مش مسجل في أي حصة', style: TextStyle(color: AppColors.muted))
          else
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  onTap: () => openGroupForm(context, group: g),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            Text(scheduleSummary(g), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      Text(
                        '${fmtMoney(s.priceOverrides[g.id] ?? g.currentPrice, currency)}'
                        '${g.payType == PayType.perLesson ? ' / ساعة' : ' / شهر'}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          if (siblings.isNotEmpty) ...[
            const SizedBox(height: 8),
            SectionTitle('الإخوات (${s.family})'),
            for (final o in siblings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentPage(studentId: o.id))),
                  child: Row(
                    children: [
                      Avatar(o.name, size: 36),
                      const SizedBox(width: 12),
                      Expanded(child: Text(o.stage.isEmpty ? o.name : '${o.name} · ${o.stage}')),
                      StatusPill(d.billFor(o, month, DateTime.now()).status),
                    ],
                  ),
                ),
              ),
          ],
          if (s.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const SectionTitle('ملاحظات'),
            Panel(child: Text(s.notes)),
          ],
          const SizedBox(height: 8),
          const SectionTitle('سجل المدفوعات'),
          if (payments.isEmpty)
            const Text('لسه مفيش مدفوعات', style: TextStyle(color: AppColors.muted))
          else
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final p in payments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(fmtMoney(p.amount, currency), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'عن شهر ${monthName(parseMonthKey(p.month), withYear: true)} · اتدفع ${fmtShortDate(p.paidAt)}'
                        '${p.note.isNotEmpty ? ' · ${p.note}' : ''}',
                      ),
                      trailing: IconButton(
                        tooltip: 'حذف الدفعة',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirm(
                            context,
                            'حذف الدفعة؟',
                            'هتتشال الدفعة دي من الحساب.',
                            ok: 'حذف',
                            danger: true,
                          )) {
                            await store.deletePayment(p);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openStudentForm(context, student: s),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل البيانات'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.unpaid),
                  onPressed: () async {
                    if (await deleteStudentAsk(context, s) && context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف الطالب'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {Color color = AppColors.ink, bool bold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w600),
        ),
      ],
    ),
  );
}

/// Egyptian numbers like 010... become 2010... for WhatsApp links.
String whatsappNumber(String phone) {
  var p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.startsWith('+')) return p.substring(1);
  if (p.startsWith('00')) return p.substring(2);
  if (p.startsWith('0')) return '20${p.substring(1)}';
  return p;
}

/// A two-hour lesson counts as two lessons.
String _taken(double n) {
  if (n == 0) return 'محضرش ولا حصة';
  return n == n.roundToDouble() ? 'حضر ${lessonsCount(n.toInt())}' : 'حضر ${arNum(n)} حصة';
}

enum _Mark { taken, absent, cancelled, coming }

/// The month's lessons for one student, week by week, with how many were taken.
class _LessonLog extends StatelessWidget {
  const _LessonLog({required this.student, required this.month});

  final Student student;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final now = DateTime.now();
    final lessons = d.lessonsOfStudent(student, month, DateTime(month.year, month.month + 1, 0));
    _Mark mark(Lesson l) {
      if (l.cancelled) return _Mark.cancelled;
      if (l.start.isAfter(now)) return _Mark.coming;
      return d.isAbsent(l, student.id) ? _Mark.absent : _Mark.taken;
    }

    final marks = {for (final l in lessons) l.key: mark(l)};
    double count(_Mark m) => lessons.where((l) => marks[l.key] == m).fold<double>(0, (a, l) => a + l.hours);
    final weeks = <DateTime, List<Lesson>>{};
    for (final l in lessons) {
      weeks.putIfAbsent(weekStart(l.date), () => []).add(l);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('الحصص اللي اتاخدت'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lessons.isEmpty)
                const Text('مفيش حصص في الشهر ده', style: TextStyle(color: AppColors.muted))
              else ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill('حضر ${arNum(count(_Mark.taken))}', fg: AppColors.paid, bg: AppColors.paidSoft),
                    if (count(_Mark.absent) > 0)
                      Pill('غاب ${arNum(count(_Mark.absent))}', fg: AppColors.unpaid, bg: AppColors.unpaidSoft),
                    if (count(_Mark.cancelled) > 0)
                      Pill('اتلغى ${arNum(count(_Mark.cancelled))}', fg: AppColors.muted, bg: AppColors.soft),
                    if (count(_Mark.coming) > 0)
                      Pill('لسه جاي ${arNum(count(_Mark.coming))}', fg: AppColors.primary, bg: AppColors.primarySoft),
                  ],
                ),
                for (final w in weeks.entries) ...[
                  const SizedBox(height: 14),
                  Text(
                    'أسبوع ${fmtShortDate(w.key)} · ${_taken(w.value.where((l) => marks[l.key] == _Mark.taken).fold<double>(0, (a, l) => a + l.hours))}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.muted),
                  ),
                  for (final l in w.value) _row(context, store, l, marks[l.key]!),
                ],
                const SizedBox(height: 8),
                const Text(
                  'دوس على أي حصة عشان تغيّرها: حضر، غاب، اتلغت، أو تنقلها ليوم تاني.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, AppStore store, Lesson l, _Mark m) {
    final (label, fg, bg) = switch (m) {
      _Mark.taken => ('حضر', AppColors.paid, AppColors.paidSoft),
      _Mark.absent => ('غاب', AppColors.unpaid, AppColors.unpaidSoft),
      _Mark.cancelled => ('اتلغت', AppColors.muted, AppColors.soft),
      _Mark.coming => ('جاية', AppColors.primary, AppColors.primarySoft),
    };
    return PopupMenuButton<String>(
      tooltip: 'تغيير',
      onSelected: (v) async {
        switch (v) {
          case 'taken':
            if (l.cancelled) await store.setCancelled(l, false);
            await store.setAbsent(l, student.id, false);
          case 'absent':
            if (l.cancelled) await store.setCancelled(l, false);
            await store.setAbsent(l, student.id, true);
          default:
            if (context.mounted) await lessonAction(context, l, v);
        }
      },
      itemBuilder: (_) => [
        if (m != _Mark.coming && m != _Mark.taken) const PopupMenuItem(value: 'taken', child: Text('حضر')),
        if (m != _Mark.coming && m != _Mark.absent) const PopupMenuItem(value: 'absent', child: Text('غاب')),
        PopupMenuItem(value: 'cancel', child: Text(l.cancelled ? 'إرجاع الحصة' : 'الحصة اتلغت')),
        const PopupMenuItem(value: 'move', child: Text('نقلها ليوم أو معاد تاني')),
        if (l.extra) const PopupMenuItem(value: 'remove', child: Text('حذف الحصة الزيادة دي')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                '${weekdayName(l.date.weekday)} ${fmtShortDate(l.date)}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              child: Text(
                '${fmtTime(l.startMin)} · ${l.group.name}${l.extra ? ' (زيادة)' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  decoration: m == _Mark.cancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Pill(label, fg: fg, bg: bg),
          ],
        ),
      ),
    );
  }
}
