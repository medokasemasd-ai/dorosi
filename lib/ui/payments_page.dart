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
import 'theme.dart';

enum _Show { owing, all, paid }

/// Who paid what and who still owes, for one month, with the old balances added in.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _Row {
  _Row(this.student, this.bill);

  final Student student;
  final MonthBill bill;
}

class _PaymentsPageState extends State<PaymentsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _Show _show = _Show.owing;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final now = DateTime.now();
    final month = monthKey(_month);
    final currency = d.settings.currency;

    final all = [
      for (final s in d.students)
        if (!s.archived || d.billFor(s, month, now).remaining > 0) _Row(s, d.billFor(s, month, now)),
    ].where((r) => r.bill.status != PayStatus.none || r.bill.paid > 0).toList();
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

    double sum(Iterable<_Row> rs, double Function(MonthBill b) f) => rs.fold<double>(0, (a, r) => a + f(r.bill));
    final monthDue = sum(all, (b) => b.due);
    final oldDue = sum(all, (b) => b.previous > 0 ? b.previous : 0);
    final paid = sum(all, (b) => b.paid);
    final remaining = sum(all, (b) => b.remaining);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدفع'),
        actions: [
          IconButton(
            tooltip: 'الشهر السابق',
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(monthName(_month, withYear: true), style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            tooltip: 'الشهر التالي',
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الباقي على الطلاب كله', style: TextStyle(color: AppColors.navyText, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  fmtMoney(remaining, currency),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                ),
                Text(
                  owing.isEmpty ? 'كل الطلاب دافعين' : 'على ${studentsCount(owing.length)}',
                  style: const TextStyle(color: AppColors.navyText, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _Figure('مستحق ${monthName(_month)}', fmtMoney(monthDue, currency))),
                    Expanded(child: _Figure('من شهور قبل كده', fmtMoney(oldDue, currency))),
                    Expanded(child: _Figure('اتدفع', fmtMoney(paid, currency))),
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
                            labelStyle: TextStyle(color: _show == s ? Colors.white : AppColors.ink, fontFamily: 'Plex'),
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
                const _TableRow(header: true, name: 'الطالب', due: 'المستحق', paid: 'المدفوع', left: 'الباقي'),
                const Divider(height: 1),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _show == _Show.owing ? 'محدش عليه فلوس 👌' : 'مفيش طلاب هنا',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                for (final r in rows)
                  InkWell(
                    onTap: () => _actions(r, month, currency),
                    child: _TableRow(
                      name: r.student.name,
                      note: _note(r.bill),
                      due: arMoney(r.bill.totalDue < 0 ? 0 : r.bill.totalDue),
                      paid: arMoney(r.bill.paid),
                      left: arMoney(r.bill.remaining),
                      leftColor: r.bill.remaining > 0 ? AppColors.unpaid : AppColors.paid,
                    ),
                  ),
                if (rows.length > 1) ...[
                  const Divider(height: 1),
                  _TableRow(
                    header: true,
                    name: 'الإجمالي',
                    due: arMoney(sum(rows, (b) => b.totalDue < 0 ? 0 : b.totalDue)),
                    paid: arMoney(sum(rows, (b) => b.paid)),
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
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          const SectionTitle('الدخل في آخر ٦ شهور'),
          _Income(month: _month, payments: d.payments, currency: currency),
          const SizedBox(height: 20),
          const SectionTitle('آخر المدفوعات'),
          _Recent(payments: d.payments, data: d, currency: currency),
        ],
      ),
    );
  }

  /// Why the amount is what it is, under the student's name.
  String? _note(MonthBill b) {
    final parts = <String>[
      for (final l in b.lines)
        if (l.group.payType == PayType.perLesson) hoursCount(l.hours),
      if (b.previous > 0) 'منه ${arMoney(b.previous)} قديم',
      if (b.previous < 0) 'دافع مقدم ${arMoney(-b.previous)}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _actions(_Row r, String month, String currency) async {
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
            if (s.phone.isNotEmpty && r.bill.remaining > 0)
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
        await showPaymentSheet(context, s, month);
      case 'whatsapp':
        final text =
            'السلام عليكم، تذكير بمصاريف دروس ${s.name}: '
            'الباقي ${fmtMoney(r.bill.remaining, currency)}'
            '${r.bill.previous > 0 ? ' (منهم ${fmtMoney(r.bill.previous, currency)} من شهور قبل كده)' : ''}. شكرًا';
        await launchUrl(
          Uri.parse('https://wa.me/${whatsappNumber(s.phone)}?text=${Uri.encodeComponent(text)}'),
          mode: LaunchMode.externalApplication,
        );
      case 'open':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => StudentPage(studentId: s.id)));
    }
  }

  Future<void> _shareReport(List<_Row> owing, String currency) async {
    final total = owing.fold<double>(0, (a, r) => a + r.bill.remaining);
    final lines = [
      'الباقي على الطلاب (${monthName(_month, withYear: true)})',
      for (final r in owing) '• ${r.student.name}: ${fmtMoney(r.bill.remaining, currency)}',
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
        Text(label, style: const TextStyle(color: AppColors.navyText, fontSize: 11)),
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
                if (note != null) Text(note!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
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
      for (final m in months) m: payments.where((p) => p.month == monthKey(m)).fold<double>(0, (a, p) => a + p.amount),
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
      return const Text('لسه مفيش مدفوعات', style: TextStyle(color: AppColors.muted));
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
                '${fmtShortDate(p.paidAt)} · عن ${monthName(parseMonthKey(p.month))}'
                '${p.note.isNotEmpty ? ' · ${p.note}' : ''}',
              ),
              trailing: Text(
                fmtMoney(p.amount, currency),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.paid),
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
