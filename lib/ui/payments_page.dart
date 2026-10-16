import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'payment_sheet.dart';
import 'student_page.dart';
import 'help.dart';
import 'theme.dart';

enum _Show { owing, all, paid }

/// Who paid what and who still owes, counted in lessons since each student joined.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _Row {
  _Row(this.student, this.bill);

  final Student student;
  final Account bill;
}

class _PaymentsPageState extends State<PaymentsPage> {
  _Show _show = _Show.owing;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final now = DateTime.now();
    final currency = d.settings.currency;

    final all = [for (final s in d.students) _Row(s, d.accountFor(s, now))]
        .where((r) => r.bill.remaining > 0 || (!r.student.archived && r.bill.status != PayStatus.none))
        .toList();
    final owing = all.where((r) => r.bill.remaining > 0).toList();
    final rows =
        switch (_show) {
          _Show.owing => owing,
          _Show.paid => all.where((r) => r.bill.remaining <= 0).toList(),
          _Show.all => all,
        }..sort((a, b) {
          final c = b.bill.remaining.compareTo(a.bill.remaining);
          return c != 0 ? c : a.student.name.compareTo(b.student.name);
        });

    double sum(Iterable<_Row> rs, double Function(Account b) f) => rs.fold<double>(0, (a, r) => a + f(r.bill));
    final remaining = sum(all, (b) => b.remaining);
    final unpaidLessons = sum(all, (b) => b.lessonsUnpaid);
    final thisMonth = monthKey(now);
    final paidThisMonth = d.payments
        .where((p) => monthKey(p.paidAt) == thisMonth)
        .fold<double>(0, (a, p) => a + p.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('الدفع'), actions: const [HelpButton(3)]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الباقي على الطلاب كله', style: TextStyle(color: AppColors.navyText, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  fmtMoney(remaining, currency),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                ),
                Text(
                  owing.isEmpty ? 'كل الطلاب دافعين' : 'على ${studentsCount(owing.length)}',
                  style: TextStyle(color: AppColors.navyText, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _Figure('حصص لسه مدفوعتش', unitsCount(unpaidLessons))),
                    Expanded(child: _Figure('اتدفع ${monthName(now)}', fmtMoney(paidThisMonth, currency))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in _Show.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            label: Text(switch (s) {
                              _Show.owing => 'عليهم فلوس (${arNum(owing.length)})',
                              _Show.all => 'الكل',
                              _Show.paid => 'خلّصوا',
                            }),
                            selected: _show == s,
                            showCheckmark: false,
                            selectedColor: AppColors.ink,
                            labelStyle: TextStyle(
                              color: _show == s ? AppColors.onPrimary : AppColors.ink,
                              fontFamily: 'Plex',
                            ),
                            onSelected: (_) => setState(() => _show = s),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'مشاركة كشف الحساب',
                onPressed: owing.isEmpty ? null : () => _shareReport(owing, currency),
                icon: const Icon(Icons.ios_share),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                const _TableRow(header: true, name: 'الطالب', due: 'اتدفع', paid: 'لسه (حصص)', left: 'الباقي'),
                const Divider(height: 1),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _show == _Show.owing ? 'محدش عليه فلوس 👌' : 'مفيش طلاب هنا',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                for (final r in rows)
                  InkWell(
                    onTap: () => _actions(r, currency),
                    child: _TableRow(
                      name: r.student.name,
                      note: _note(r.bill),
                      due: arMoney(r.bill.paid),
                      paid: _units(r.bill.lessonsUnpaid),
                      left: arMoney(r.bill.remaining),
                      leftColor: r.bill.remaining > 0 ? AppColors.unpaid : AppColors.paid,
                    ),
                  ),
                if (rows.length > 1) ...[
                  const Divider(height: 1),
                  _TableRow(
                    header: true,
                    name: 'الإجمالي',
                    due: arMoney(sum(rows, (b) => b.paid)),
                    paid: _units(sum(rows, (b) => b.lessonsUnpaid)),
                    left: arMoney(sum(rows, (b) => b.remaining)),
                    leftColor: AppColors.unpaid,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'المبالغ بالـ$currency. دوس على أي طالب عشان تسجّل دفع أو تبعتله تذكير على واتساب.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          const SectionTitle('الدخل في آخر ٦ شهور'),
          _Income(month: DateTime(now.year, now.month), payments: d.payments, currency: currency),
          const SizedBox(height: 20),
          const SectionTitle('آخر المدفوعات'),
          _Recent(payments: d.payments, data: d, currency: currency),
        ],
      ),
    );
  }

  /// What the student has taken so far, under their name.
  String? _note(Account b) {
    final parts = <String>[
      if (b.lessonsTaken > 0) 'خد ${unitsCount(b.lessonsTaken)}',
      if (b.unpaid.any((c) => c.month != null)) 'فيه شهري',
      if (b.credit > 0) 'دافع مقدم ${arMoney(b.credit)}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _units(double n) => n <= 0 ? '–' : arNum(double.parse(n.toStringAsFixed(1)));

  Future<void> _actions(_Row r, String currency) async {
    final s = r.student;
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(
              r.bill.remaining > 0 ? 'الباقي ${fmtMoney(r.bill.remaining, currency)}' : 'مفيش عليه حاجة',
              style: TextStyle(color: r.bill.remaining > 0 ? AppColors.unpaid : AppColors.paid),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('تسجيل دفع'),
              onTap: () => Navigator.pop(c, 'pay'),
            ),
            if (s.billingPhone.isNotEmpty && r.bill.remaining > 0)
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('تذكير بالمبلغ على واتساب'),
                onTap: () => Navigator.pop(c, 'whatsapp'),
              ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('صفحة الطالب'),
              onTap: () => Navigator.pop(c, 'open'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (v) {
      case 'pay':
        await showPaymentSheet(context, s);
      case 'whatsapp':
        final text =
            'السلام عليكم، تذكير بمصاريف دروس ${s.name}: '
            '${r.bill.lessonsUnpaid > 0 ? '${unitsCount(r.bill.lessonsUnpaid)} لسه مدفوعتش، ' : ''}'
            'الباقي ${fmtMoney(r.bill.remaining, currency)}. شكرًا';
        await launchUrl(
          Uri.parse('https://wa.me/${whatsappNumber(s.billingPhone)}?text=${Uri.encodeComponent(text)}'),
          mode: LaunchMode.externalApplication,
        );
      case 'open':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => StudentPage(studentId: s.id)));
    }
  }

  Future<void> _shareReport(List<_Row> owing, String currency) async {
    final total = owing.fold<double>(0, (a, r) => a + r.bill.remaining);
    final lines = [
      'الباقي على الطلاب (${fmtDate(DateTime.now())})',
      for (final r in owing)
        '• ${r.student.name}: ${fmtMoney(r.bill.remaining, currency)}'
            '${r.bill.lessonsUnpaid > 0 ? ' (${unitsCount(r.bill.lessonsUnpaid)})' : ''}',
      'الإجمالي: ${fmtMoney(total, currency)}',
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }
}

/// A money amount without the currency, for the table.
String arMoney(double v) => fmtMoney(v, '').trim();

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.navyText, fontSize: 11)),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.name,
    required this.due,
    required this.paid,
    required this.left,
    this.note,
    this.header = false,
    this.leftColor,
  });

  final String name;
  final String? note;
  final String due;
  final String paid;
  final String left;
  final bool header;
  final Color? leftColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: header ? 12 : 14,
      fontWeight: header ? FontWeight.w600 : FontWeight.w400,
      color: header ? AppColors.muted : AppColors.ink,
    );
    Widget num(String v, {Color? color, bool bold = false}) => SizedBox(
      width: 64,
      child: Text(
        v,
        textAlign: TextAlign.center,
        style: style.copyWith(color: color, fontWeight: bold ? FontWeight.w700 : null),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(fontWeight: header ? null : FontWeight.w600),
                ),
                if (note != null) Text(note!, style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          num(due),
          num(paid, color: header ? null : AppColors.paid),
          num(left, color: header && leftColor == null ? null : leftColor, bold: !header || leftColor != null),
        ],
      ),
    );
  }
}

/// Money received for each of the last six months, as bars.
class _Income extends StatelessWidget {
  const _Income({required this.month, required this.payments, required this.currency});

  final DateTime month;
  final List<Payment> payments;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final months = [for (var i = 5; i >= 0; i--) DateTime(month.year, month.month - i)];
    final totals = {
      for (final m in months)
        m: payments.where((p) => monthKey(p.paidAt) == monthKey(m)).fold<double>(0, (a, p) => a + p.amount),
    };
    final top = totals.values.fold<double>(0, (a, b) => a > b ? a : b);
    return Panel(
      child: Column(
        children: [
          for (final m in months)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 64, child: Text(monthName(m), style: const TextStyle(fontSize: 13))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: top <= 0 ? 0 : totals[m]! / top,
                        minHeight: 12,
                        backgroundColor: AppColors.soft,
                        color: m == month ? AppColors.primary : AppColors.primary.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      fmtMoney(totals[m]!, currency),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.payments, required this.data, required this.currency});

  final List<Payment> payments;
  final AppData data;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final recent = [...payments]..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    if (recent.isEmpty) {
      return Text('لسه مفيش مدفوعات', style: TextStyle(color: AppColors.muted));
    }
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (final p in recent.take(10))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(data.student(p.studentId)?.name ?? 'طالب محذوف'),
              subtitle: Text(
                '${weekdayName(p.paidAt.weekday)} ${fmtShortDate(p.paidAt)}'
                '${p.note.isNotEmpty ? ' · ${p.note}' : ''}',
              ),
              trailing: Text(
                fmtMoney(p.amount, currency),
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.paid),
              ),
              onTap: data.student(p.studentId) == null
                  ? null
                  : () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => StudentPage(studentId: p.studentId))),
            ),
        ],
      ),
    );
  }
}
