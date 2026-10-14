import 'package:flutter/material.dart';

import 'theme.dart';

/// What each tab is for, in the order of the tabs.
const tabHelp = [
  (
    'الجدول',
    Icons.calendar_month_outlined,
    'الصفحة الرئيسية. بتوريك الحصة الجاية وفاضل عليها قد إيه، وأيام الأسبوع وفي كل يوم كام حصة.',
    [
      'اضغط على أي يوم تشوف حصصه، وتسجّل الحضور والغياب، أو تلغي حصة أو تأجلها.',
      'الأسهم بتنقلك بين الأسابيع.',
      'زرار الشكل جنب الأسهم بيغيّر العرض بين مربعات وقائمة.',
    ],
  ),
  (
    'الطلاب',
    Icons.people_outline,
    'كل طلابك وحساب كل واحد: عليه كام حصة لسه ما اتدفعتش.',
    [
      'اضغط على الطالب تشوف حسابه وحضوره، وتسجّل دفع، أو تكلّمه على واتساب.',
      'اضغط مطوّل على الطالب عشان تعدّل بياناته أو تمسحه.',
      'الإخوات بيظهروا مع بعض باسم العيلة.',
    ],
  ),
  (
    'الحصص',
    Icons.class_outlined,
    'الحصص الثابتة: مواعيدها في الأسبوع، وسعرها، والطلاب اللي فيها.',
    [
      'فيه حصص فردية، ومجموعات، ومراجعات قبل الامتحان.',
      'زرار الإجازة فوق بيوقف كل الحصص لفترة، وبعدها ترجع لوحدها.',
      'لما حصة تخلص خالص، افتحها واختار "الحصة خلصت". ولو السنة خلصت، تقدر تنهي كل الحصص مرة واحدة من زرار الإجازة.',
    ],
  ),
  (
    'الدفع',
    Icons.payments_outlined,
    'ملخص الفلوس: الباقي على الطلاب كلهم، ومين عليه كام حصة، واللي اتدفع الشهر ده.',
    [
      'اضغط على أي طالب في الجدول عشان تسجّل دفع، أو تبعتله تذكير على واتساب.',
      'زرار المشاركة بيعمل تقرير تبعته لنفسك أو لحد.',
      'تحت هتلاقي دخلك في آخر ٦ شهور، وآخر المدفوعات.',
    ],
  ),
  (
    'التذكيرات',
    Icons.notifications_none,
    'التذكيرات والإعدادات.',
    [
      'تذكير قبل الحصة، وتنبيه لما تخلص، وتذكير بالفلوس كل شهر.',
      'شكل التطبيق: اللون، والوضع الليلي، واسمك.',
      'وضع العرض: لما تفرّج حد على التطبيق من غير ما يشوف طلابك.',
      'النسخة الاحتياطية: اعملها كل فترة عشان بياناتك ما تضيعش لو غيّرت الموبايل.',
    ],
  ),
];

/// A "?" button that explains the tab at [index].
class HelpButton extends StatelessWidget {
  const HelpButton(this.index, {super.key});

  final int index;

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: 'شرح', icon: const Icon(Icons.help_outline), onPressed: () => showHelp(context, index));
  }
}

Future<void> showHelp(BuildContext context, int index) {
  final (title, icon, intro, points) = tabHelp[index];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(icon, color: AppColors.onPrimarySoft),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('تبويب $title', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(intro, style: const TextStyle(fontSize: 15, height: 1.6, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 9, left: 10),
                      child: CircleAvatar(radius: 3, backgroundColor: AppColors.primary),
                    ),
                    Expanded(child: Text(p, style: const TextStyle(height: 1.6))),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            FilledButton(onPressed: () => Navigator.pop(c), child: const Text('تمام')),
          ],
        ),
      ),
    ),
  );
}
