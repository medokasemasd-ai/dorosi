import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'theme.dart';

String breakText(Break b) => b.to == null
    ? 'من ${fmtShortDate(b.from)} لحد ما ترجّعها'
    : 'من ${fmtShortDate(b.from)} لحد ${fmtShortDate(b.to!)}';

/// Holidays: stop all lessons for a while, or end the classes for the year.
Future<void> showBreakSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    builder: (c) {
      final store = StoreScope.of(c);
      final today = dateOnly(DateTime.now());
      final breaks = store.data.breaks;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إجازة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'في الإجازة الحصص مش بتظهر في الجدول، ومفيش تذكيرات، ومش بتتحسب على الطلاب.',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  final r = await showDateRangePicker(
                    context: c,
                    firstDate: DateTime(today.year - 1),
                    lastDate: DateTime(today.year + 2),
                    initialDateRange: DateTimeRange(
                      start: today,
                      end: DateTime(today.year, today.month, today.day + 7),
                    ),
                    helpText: 'اختار أول وآخر يوم في الإجازة',
                    saveText: 'تمام',
                  );
                  if (r == null) return;
                  await store.addBreak(r.start, r.end);
                  if (c.mounted) Navigator.pop(c);
                },
                icon: const Icon(Icons.date_range_outlined),
                label: const Text('إجازة لفترة محددة'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await store.addBreak(today, null);
                  if (c.mounted) Navigator.pop(c);
                },
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('وقّف الحصص من النهارده لحد ما أرجّعها'),
              ),
              if (breaks.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('الإجازات', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final b in breaks.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      b.covers(today) ? Icons.beach_access : Icons.event_busy_outlined,
                      color: b.covers(today) ? AppColors.partial : AppColors.muted,
                    ),
                    title: Text(breakText(b)),
                    subtitle: b.covers(today) ? const Text('شغّالة دلوقتي') : null,
                    trailing: IconButton(
                      tooltip: 'امسح الإجازة',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => store.removeBreak(b),
                    ),
                  ),
              ],
              const Divider(height: 28),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.unpaid),
                onPressed: () => _endYear(c, store),
                icon: const Icon(Icons.school_outlined),
                label: const Text('السنة خلصت: إنهاء كل الحصص'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _endYear(BuildContext context, AppStore store) async {
  final n = store.data.groups.where((g) => !g.archived).length;
  if (n == 0) {
    toast(context, 'مفيش حصص حالية');
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('إنهاء كل الحصص؟'),
      content: Text(
        'الـ${arNum(n)} حصص هيتنقلوا للحصص السابقة ويختفوا من الجدول. '
        'حسابات الطلاب والمدفوعات هتفضل زي ما هي، وتقدر ترجّع أي حصة بعدين.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('أيوه، أنهيها')),
      ],
    ),
  );
  if (ok != true) return;
  await store.archiveAllGroups();
  if (context.mounted) {
    Navigator.pop(context);
    toast(context, 'تم إنهاء كل الحصص');
  }
}

/// Shown on the schedule and classes tabs during a holiday, or when one is near.
class BreakBanner extends StatelessWidget {
  const BreakBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = dateOnly(DateTime.now());
    final now = store.data.onBreak(today);
    Break? soon;
    if (now == null) {
      for (final b in store.data.breaks) {
        final days = dateOnly(b.from).difference(today).inDays;
        if (days > 0 && days <= 14) soon = b;
      }
    }
    final b = now ?? soon;
    if (b == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.partialSoft,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Icon(Icons.beach_access, color: AppColors.partial),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      now != null ? 'إجازة: الحصص واقفة' : 'فيه إجازة جاية',
                      style: TextStyle(color: AppColors.partial, fontWeight: FontWeight.w700),
                    ),
                    Text(breakText(b), style: TextStyle(color: AppColors.partial, fontSize: 13)),
                  ],
                ),
              ),
              if (now != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.partial),
                  onPressed: () => store.endBreak(now, today),
                  child: const Text('رجّع الحصص'),
                )
              else
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.partial),
                  onPressed: () => showBreakSheet(context),
                  child: const Text('تعديل'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
