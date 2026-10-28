import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../data.dart';
import 'common.dart';
import 'day_page.dart';
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
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final s = d.student(widget.studentId);
    if (s == null) return const Scaffold(body: SizedBox());
    final currency = d.settings.currency;
    final account = d.accountFor(s, DateTime.now());
    final unpaid = account.unpaid.reversed.toList();
    final groups = d.groupsOf(s);
    final siblings = d.siblingsOf(s);
    final payments = d.payments.where((p) => p.studentId == s.id).toList()
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    final special = groups.any((g) => s.priceOverrides.containsKey(g.id) || s.hoursOverrides.containsKey(g.id));

    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
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
                      if (s.stage.isNotEmpty) Text(s.stage, style: TextStyle(color: AppColors.muted)),
                      if (s.archived) Pill('من الطلاب السابقين', fg: AppColors.muted, bg: AppColors.soft),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle(account.family == null ? 'الحساب' : 'حساب ${account.label}'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (account.family != null) ...[
                  Text(
                    'حساب واحد لـ ${account.members.map((m) => m.name).join(' و')}. '
                    'الحصة اللي بياخدوها مع بعض بـ ${fmtMoney(d.familyPrices[account.family] ?? 0, currency)}.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                ],
                if (account.since != null) ...[
                  Text(
                    'الحصص بتتعد من بعد ${fmtShortDate(account.since!)} ${arNum(account.since!.year)}، '
                    'آخر مرة خلّص فيها كل اللي عليه.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _Count(
                        'حضر',
                        unitsCount(account.lessonsTaken),
                        AppColors.ink,
                        sub: account.hours == account.attended ? null : hoursCount(account.hours),
                      ),
                    ),
                    Expanded(child: _Count('اتدفع', unitsCount(account.lessonsPaid), AppColors.paid)),
                    Expanded(
                      child: _Count(
                        'لسه',
                        unitsCount(account.lessonsUnpaid),
                        account.lessonsUnpaid > 0 ? AppColors.unpaid : AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _line('المطلوب', fmtMoney(account.currentDue, currency)),
                _line('المدفوع', fmtMoney(account.currentPaid, currency), color: AppColors.paid),
                _line(
                  account.credit > 0 ? 'دافع مقدم' : 'الباقي عليه',
                  fmtMoney(account.credit > 0 ? account.credit : account.remaining, currency),
                  color: account.remaining > 0 ? AppColors.unpaid : AppColors.paid,
                  bold: true,
                ),
                if (unpaid.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'الحصص اللي لسه مدفوعتش',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
                  ),
                  for (final c in unpaid.take(_showAll ? unpaid.length : 6))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(chargeText(c), style: const TextStyle(fontSize: 13))),
                          Text(
                            c.paid > 0 ? 'باقي ${fmtMoney(c.amount - c.paid, currency)}' : fmtMoney(c.amount, currency),
                            style: TextStyle(fontSize: 13, color: AppColors.unpaid, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  if (unpaid.length > 6 && !_showAll)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => setState(() => _showAll = true),
                        child: Text('عرض الكل (${arNum(unpaid.length)})'),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => showPaymentSheet(context, s),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('تسجيل دفع'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('البيانات'),
          Text('دوس على ✏️ جنب أي معلومة عشان تعدّلها.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 8),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                _InfoRow(
                  label: 'الاسم',
                  value: s.name,
                  onEdit: () => editStudentText(
                    context,
                    s,
                    title: 'اسم الطالب',
                    initial: s.name,
                    apply: (v) {
                      if (v.isNotEmpty) s.name = v;
                    },
                  ),
                ),
                _InfoRow(
                  label: 'رقم الطالب',
                  value: s.phone.isEmpty ? '' : arDigits(s.phone),
                  ltr: true,
                  phone: s.phone,
                  onEdit: () => editStudentPhone(context, s),
                ),
                _InfoRow(
                  label: 'رقم ولي الأمر',
                  value: s.parentPhone.isEmpty ? '' : arDigits(s.parentPhone),
                  ltr: true,
                  phone: s.parentPhone,
                  onEdit: () => editStudentPhone(context, s, parent: true),
                ),
                _InfoRow(
                  label: 'الحصص',
                  value: groups.map((g) => g.name).join('، '),
                  empty: 'مش مسجل في أي حصة',
                  onEdit: () => editStudentClasses(context, s),
                ),
                if (groups.isNotEmpty)
                  _InfoRow(
                    label: 'السعر',
                    value: special ? 'سعر خاص' : 'سعر الحصة العادي',
                    onEdit: () => editStudentPrices(context, s),
                  ),
                _InfoRow(
                  label: 'المرحلة',
                  value: s.stage,
                  onEdit: () => editStudentText(
                    context,
                    s,
                    title: 'المرحلة',
                    initial: s.stage,
                    apply: (v) => s.stage = v,
                    suggestions: {for (final o in d.students) o.stage.trim()}..remove(''),
                  ),
                ),
                _InfoRow(
                  label: 'الإخوات',
                  value: s.family.isEmpty ? '' : 'عيلة ${s.family}',
                  empty: 'مش متسجل مع إخواته',
                  onEdit: () => editStudentFamily(context, s),
                ),
                _InfoRow(
                  label: 'بداية الحساب',
                  value: '${fmtShortDate(s.joinedAt)} ${arNum(s.joinedAt.year)}',
                  onEdit: () => editStudentStart(context, s),
                ),
                _InfoRow(
                  label: 'ملاحظات',
                  value: s.notes,
                  last: true,
                  onEdit: () => editStudentText(
                    context,
                    s,
                    title: 'ملاحظات',
                    initial: s.notes,
                    multiline: true,
                    apply: (v) => s.notes = v,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle(
            'الحضور',
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
          _LessonLog(student: s, month: _month),
          if (siblings.isNotEmpty) ...[
            const SizedBox(height: 16),
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
                      StatusPill(d.accountFor(o, DateTime.now()).status),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          const SectionTitle('سجل المدفوعات'),
          if (payments.isEmpty)
            Text('لسه مفيش مدفوعات', style: TextStyle(color: AppColors.muted))
          else
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final p in payments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(fmtMoney(p.amount, currency), style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'اتدفع ${weekdayName(p.paidAt.weekday)} ${fmtShortDate(p.paidAt)}'
                        '${p.note.isNotEmpty ? ' · ${p.note}' : ''}',
                      ),
                      trailing: IconButton(
                        tooltip: 'حذف الدفعة',
                        icon: Icon(Icons.delete_outline),
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
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => store.setStudentArchived(s, !s.archived),
                  icon: Icon(s.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
                  label: Text(s.archived ? 'رجّعه للحاليين' : 'نقله للسابقين'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.unpaid),
                  onPressed: () async {
                    if (await deleteStudentAsk(context, s) && context.mounted) Navigator.pop(context);
                  },
                  icon: Icon(Icons.delete_outline),
                  label: Text('حذف الطالب'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {Color? color, bool bold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: AppColors.muted)),
        ),
        Text(
          value,
          style: TextStyle(color: color ?? AppColors.ink, fontWeight: bold ? FontWeight.w700 : FontWeight.w600),
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

/// "حضر حصتين (٦ ساعات)": lessons, with the hours when they are not one hour each.
String _taken(Student s, Iterable<Lesson> ls) {
  if (ls.isEmpty) return 'محضرش ولا حصة';
  final h = ls.fold<double>(0, (a, l) => a + studentHours(s, l));
  return 'حضر ${lessonsCount(ls.length)}${h == ls.length ? '' : ' (${hoursCount(h)})'}';
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
    int count(_Mark m) => lessons.where((l) => marks[l.key] == m).length;
    final weeks = <DateTime, List<Lesson>>{};
    for (final l in lessons) {
      weeks.putIfAbsent(weekStart(l.date), () => []).add(l);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lessons.isEmpty)
                Text('مفيش حصص في الشهر ده', style: TextStyle(color: AppColors.muted))
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
                    'أسبوع ${fmtShortDate(w.key)} · ${_taken(student, w.value.where((l) => marks[l.key] == _Mark.taken))}',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.muted),
                  ),
                  for (final l in w.value) _row(context, store, l, marks[l.key]!),
                ],
                const SizedBox(height: 8),
                Text(
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

class _Count extends StatelessWidget {
  const _Count(this.label, this.value, this.color, {this.sub});

  final String label;
  final String value;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
        ),
        if (sub != null) Text(sub!, style: TextStyle(fontSize: 12, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

/// One detail of the student with a ✏️ button, and call and WhatsApp buttons for numbers.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.onEdit,
    this.empty = 'مش مكتوب',
    this.phone = '',
    this.ltr = false,
    this.last = false,
  });

  final String label;
  final String value;
  final VoidCallback onEdit;
  final String empty;
  final String phone;
  final bool ltr;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  Text(
                    value.isEmpty ? empty : value,
                    textDirection: ltr && value.isNotEmpty ? TextDirection.ltr : null,
                    style: value.isEmpty
                        ? TextStyle(color: AppColors.muted, fontSize: 14)
                        : const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
            ),
            if (phone.isNotEmpty) ...[
              IconButton(
                tooltip: 'اتصال ب$label',
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                icon: Icon(Icons.call_outlined, color: AppColors.primary),
              ),
              IconButton(
                tooltip: 'واتساب $label',
                onPressed: () => launchUrl(
                  Uri.parse('https://wa.me/${whatsappNumber(phone)}'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: Icon(Icons.chat_outlined, color: AppColors.primary),
              ),
            ],
            IconButton(
              tooltip: 'تعديل $label',
              onPressed: onEdit,
              icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
    if (last) return row;
    return Column(children: [row, const Divider(height: 1)]);
  }
}
