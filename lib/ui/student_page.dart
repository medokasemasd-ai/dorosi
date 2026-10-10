import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
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
          IconButton(tooltip: 'تعديل', onPressed: () => openStudentForm(context, student: s), icon: const Icon(Icons.edit_outlined)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'archive') {
                await store.setStudentArchived(s, !s.archived);
              } else if (v == 'delete') {
                final ok = await confirm(context, 'حذف ${s.name}؟', 'هيتمسح الطالب وكل مدفوعاته نهائيًا.',
                    ok: 'حذف', danger: true);
                if (ok) {
                  await store.deleteStudent(s);
                  if (context.mounted) Navigator.pop(context);
                }
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
            child: Row(children: [
              Avatar(s.name, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  if (s.stage.isNotEmpty) Text(s.stage, style: const TextStyle(color: AppColors.muted)),
                  if (s.phone.isNotEmpty)
                    Text(arDigits(s.phone), textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.muted)),
                  if (s.archived) const Pill('من الطلاب السابقين', fg: AppColors.muted, bg: AppColors.soft),
                ]),
              ),
              if (s.phone.isNotEmpty) ...[
                IconButton.filledTonal(
                  tooltip: 'اتصال',
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: s.phone)),
                  icon: const Icon(Icons.call_outlined),
                ),
                IconButton.filledTonal(
                  tooltip: 'واتساب',
                  onPressed: () => launchUrl(Uri.parse('https://wa.me/${whatsappNumber(s.phone)}'),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.chat_outlined),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          SectionTitle(
            'حساب الشهر',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
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
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('الحالة', style: TextStyle(color: AppColors.muted))),
                StatusPill(bill.status),
              ]),
              const SizedBox(height: 10),
              if (bill.lines.isEmpty)
                const Text('مفيش مستحق في الشهر ده', style: TextStyle(color: AppColors.muted)),
              for (final l in bill.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(
                      child: Text(l.group.payType == PayType.perLesson
                          ? '${l.group.name} (${lessonsCount(l.count)} × ${fmtMoney(l.price, currency)})'
                          : '${l.group.name} (شهري)'),
                    ),
                    Text(fmtMoney(l.amount, currency), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              const Divider(height: 20),
              _line('المستحق', fmtMoney(bill.due, currency)),
              _line('المدفوع', fmtMoney(bill.paid, currency), color: AppColors.paid),
              _line('الباقي', fmtMoney(bill.remaining, currency),
                  color: bill.remaining > 0 ? AppColors.unpaid : AppColors.ink, bold: true),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showPaymentSheet(context, s, month),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('تسجيل دفع'),
              ),
            ]),
          ),
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
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        Text(scheduleSummary(g), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      ]),
                    ),
                    Text(
                      '${fmtMoney(s.priceOverrides[g.id] ?? g.currentPrice, currency)}'
                      '${g.payType == PayType.perLesson ? ' / حصة' : ' / شهر'}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ]),
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
                  child: Row(children: [
                    Avatar(o.name, size: 36),
                    const SizedBox(width: 12),
                    Expanded(child: Text(o.stage.isEmpty ? o.name : '${o.name} · ${o.stage}')),
                    StatusPill(d.billFor(o, month, DateTime.now()).status),
                  ]),
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
              child: Column(children: [
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
                        if (await confirm(context, 'حذف الدفعة؟', 'هتتشال الدفعة دي من الحساب.', ok: 'حذف', danger: true)) {
                          await store.deletePayment(p);
                        }
                      },
                    ),
                  ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {Color color = AppColors.ink, bool bold = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ]),
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
