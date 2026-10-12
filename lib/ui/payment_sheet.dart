import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'theme.dart';

/// Asks for an amount and records a payment by [student]. Payments cover the
/// oldest unpaid lessons first.
Future<void> showPaymentSheet(BuildContext context, Student student) async {
  final store = StoreScope.read(context);
  final now = DateTime.now();
  final account = store.data.accountFor(student, now);
  final amount = TextEditingController(text: account.remaining > 0 ? _plain(account.remaining) : '');
  final note = TextEditingController();
  final currency = store.data.settings.currency;
  // Per-lesson price of the student's first per-lesson class, for the quick buttons.
  final perLesson = store.data.groupsOf(student).where((g) => g.payType == PayType.perLesson).toList();
  final price = perLesson.isEmpty ? null : (student.priceOverrides[perLesson.first.id] ?? perLesson.first.currentPrice);

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('تسجيل دفع: ${student.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            account.remaining > 0
                ? 'عليه ${fmtMoney(account.remaining, currency)}'
                      '${account.lessonsUnpaid > 0 ? ' (${unitsCount(account.lessonsUnpaid)} لسه مدفوعتش)' : ''}'
                : account.credit > 0
                ? 'دافع مقدم ${fmtMoney(account.credit, currency)}'
                : 'مفيش عليه حاجة',
            style: TextStyle(color: account.remaining > 0 ? AppColors.unpaid : AppColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'المبلغ', suffixText: currency),
          ),
          if (price != null && price > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in [1, 2, 4, 8])
                  ActionChip(
                    label: Text(lessonsCount(n)),
                    onPressed: () => amount.text = _plain(price * n),
                    visualDensity: VisualDensity.compact,
                  ),
                if (account.remaining > 0)
                  ActionChip(
                    label: const Text('كل اللي عليه'),
                    onPressed: () => amount.text = _plain(account.remaining),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final v = parseArNum(amount.text);
              if (v == null || v <= 0) {
                toast(c, 'اكتب المبلغ صح');
                return;
              }
              store.addPayment(student.id, monthKey(now), v, note: note.text.trim());
              Navigator.pop(c, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  if (saved == true && context.mounted) toast(context, 'تم تسجيل الدفع');
}

/// "3 lessons", where a two-hour lesson counts as two.
String unitsCount(double n) =>
    n == n.roundToDouble() ? lessonsCount(n.toInt()) : '${arNum(double.parse(n.toStringAsFixed(1)))} حصة';

/// What one charge is: "السبت ١٠ أكتوبر · رياضيات (ساعتين)" or "رياضيات · شهر أكتوبر".
String chargeText(Charge c) {
  if (c.lesson == null) return '${c.group.name} · شهر ${monthName(c.date)}';
  final h = c.lesson!.hours;
  return '${weekdayName(c.date.weekday)} ${fmtShortDate(c.date)} · ${c.group.name}'
      '${h == 1 ? '' : ' (${hoursCount(h)})'}';
}

String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
