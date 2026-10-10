import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'theme.dart';

/// Asks for an amount and records a payment by [student] for [month].
Future<void> showPaymentSheet(BuildContext context, Student student, String month) async {
  final store = StoreScope.read(context);
  final bill = store.data.billFor(student, month, DateTime.now());
  final amount = TextEditingController(text: bill.remaining > 0 ? _plain(bill.remaining) : '');
  final note = TextEditingController();
  final currency = store.data.settings.currency;

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
            'شهر ${monthName(parseMonthKey(month), withYear: true)} · المستحق ${fmtMoney(bill.due, currency)}'
            '${bill.paid > 0 ? ' · مدفوع ${fmtMoney(bill.paid, currency)}' : ''}',
            style: const TextStyle(color: AppColors.muted),
          ),
          for (final line in bill.lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                line.group.payType == PayType.perLesson
                    ? '• ${line.group.name}: ${lessonsCount(line.count)} × ${fmtMoney(line.price, currency)}'
                    : '• ${line.group.name}: ${fmtMoney(line.price, currency)} شهريًا',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'المبلغ', suffixText: currency),
          ),
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
              store.addPayment(student.id, month, v, note: note.text.trim());
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

String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
