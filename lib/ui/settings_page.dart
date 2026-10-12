import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models.dart';
import '../services/reminders.dart';
import '../store.dart';
import 'common.dart';
import 'theme.dart';

/// The release number, set by the build (empty in local builds).
const appBuild = String.fromEnvironment('BUILD');

/// The currencies the user can pick: symbol and name.
const currencies = [('ج.م', 'جنيه مصري'), ('ر.س', 'ريال'), (r'$', 'دولار')];

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.data.settings;
    final next = store.data.nextLesson(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('التذكيرات والإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _WidgetPreview(
            title: next?.group.name,
            time: next == null ? null : '${dayLabel(next.date, DateTime.now())} · ${fmtTime(next.startMin)}',
          ),
          const SizedBox(height: 16),
          const SectionTitle('شكل التطبيق'),
          const _Look(),
          const SizedBox(height: 20),
          const SectionTitle('التذكيرات'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  value: s.remindStart,
                  onChanged: (v) => store.updateSettings((x) => x.remindStart = v),
                  title: const Text('تذكير بداية الحصة'),
                  subtitle: Text(
                    s.startLeadMin == 0 ? 'وقت بداية الحصة' : 'قبل الحصة بـ ${minutesCount(s.startLeadMin)}',
                  ),
                ),
                if (s.remindStart)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final m in [0, 5, 10, 15, 30, 60])
                          ChoiceChip(
                            label: Text(m == 0 ? 'وقتها' : arNum(m)),
                            selected: s.startLeadMin == m,
                            onSelected: (_) => store.updateSettings((x) => x.startLeadMin = m),
                          ),
                      ],
                    ),
                  ),
                const Divider(),
                SwitchListTile(
                  value: s.remindEnd,
                  onChanged: (v) => store.updateSettings((x) => x.remindEnd = v),
                  title: const Text('تنبيه نهاية الحصة'),
                  subtitle: const Text('عند انتهاء وقت الحصة'),
                ),
                const Divider(),
                SwitchListTile(
                  value: s.remindPayment,
                  onChanged: (v) => store.updateSettings((x) => x.remindPayment = v),
                  title: const Text('تذكير المدفوعات'),
                  subtitle: Text(
                    '${s.paymentDay == 0 ? 'آخر يوم في الشهر' : 'يوم ${arNum(s.paymentDay)} من الشهر'} الساعة ${fmtTime(s.paymentHour * 60)}',
                  ),
                ),
                if (s.remindPayment)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 16,
                      children: [
                        DropdownButton<int>(
                          value: s.paymentDay,
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem(value: 0, child: Text('آخر الشهر')),
                            for (var i = 1; i <= 28; i++) DropdownMenuItem(value: i, child: Text('يوم ${arNum(i)}')),
                          ],
                          onChanged: (v) => store.updateSettings((x) => x.paymentDay = v!),
                        ),
                        DropdownButton<int>(
                          value: s.paymentHour,
                          underline: const SizedBox(),
                          items: [
                            for (var h = 8; h <= 23; h++) DropdownMenuItem(value: h, child: Text(fmtTime(h * 60))),
                          ],
                          onChanged: (v) => store.updateSettings((x) => x.paymentHour = v!),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'كل حصة ليها كمان زرار تشغيل وإيقاف للتذكير من صفحة اليوم.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Reminders.instance.showTest();
              if (context.mounted) toast(context, 'لو وصلك إشعار، التذكيرات شغالة');
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('جرّب إشعار دلوقتي'),
          ),
          const SizedBox(height: 20),
          const SectionTitle('ويدجت الشاشة الرئيسية'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'الويدجت بيعرض الحصة الجاية على الشاشة الرئيسية للموبايل ويتحدث لوحده.\n'
                  'لإضافته: اضغط مطولًا على مكان فاضي في الشاشة الرئيسية، اختار "الأدوات" أو Widgets، ودوّر على "دروسي".',
                  style: TextStyle(height: 1.6),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _pinWidget(context),
                  icon: const Icon(Icons.widgets_outlined),
                  label: const Text('أضف الويدجت للشاشة'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('نسخة احتياطية'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'البيانات محفوظة على الموبايل بس. اعمل نسخة احتياطية كل فترة وابعتها لنفسك على واتساب أو Drive، '
                  'عشان لو غيرت الموبايل ترجّع كل حاجة.',
                  style: TextStyle(height: 1.6),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => _export(context, store),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('حفظ نسخة احتياطية'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _import(context, store),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('استرجاع من نسخة'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('التحديثات'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  appBuild.isEmpty ? 'نسخة تجريبية' : 'النسخة اللي عندك: رقم ${arNum(int.parse(appBuild))}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'لو فيه نسخة أحدث، نزّلها وسطّبها فوق دي وبياناتك هتفضل زي ما هي.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://github.com/medokasemasd-ai/dorosi/releases/latest'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.system_update_outlined),
                  label: const Text('شوف آخر نسخة'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('العملة'),
          Wrap(
            spacing: 6,
            children: [
              for (final (c, name) in currencies)
                ChoiceChip(
                  label: Text('$name ($c)'),
                  selected: s.currency == c,
                  onSelected: (_) => store.updateSettings((x) => x.currency = c),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pinWidget(BuildContext context) async {
    if (kIsWeb) return;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() == true) {
        await HomeWidget.requestPinWidget(qualifiedAndroidName: 'com.aboelkasem.dorosi.NextLessonWidget');
        return;
      }
    } catch (_) {}
    if (context.mounted) toast(context, 'ضيفه يدوي من قائمة الأدوات في الشاشة الرئيسية');
  }

  Future<void> _export(BuildContext context, AppStore store) async {
    final name = 'dorosi-backup-${dateKey(DateTime.now())}.json';
    final bytes = utf8.encode(store.exportJson());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(Uint8List.fromList(bytes), name: name, mimeType: 'application/json')],
        fileNameOverrides: [name],
        subject: 'نسخة احتياطية من دروسي',
      ),
    );
  }

  Future<void> _import(BuildContext context, AppStore store) async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty || !context.mounted) return;
    final ok = await confirm(
      context,
      'استرجاع النسخة؟',
      'كل البيانات الحالية هتتبدل بالبيانات اللي في النسخة.',
      ok: 'استرجاع',
      danger: true,
    );
    if (!ok) return;
    try {
      await store.importJson(await files.first.xFile.readAsString());
      if (context.mounted) toast(context, 'تم الاسترجاع');
    } catch (_) {
      if (context.mounted) toast(context, 'الملف ده مش نسخة احتياطية من دروسي');
    }
  }
}

class _Look extends StatefulWidget {
  const _Look();

  @override
  State<_Look> createState() => _LookState();
}

class _LookState extends State<_Look> {
  late final _name = TextEditingController(text: StoreScope.read(context).data.settings.teacherName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.data.settings;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('لون التطبيق', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (var i = 0; i < accents.length; i++)
                Tooltip(
                  message: accents[i].$1,
                  child: InkResponse(
                    key: ValueKey('accent-$i'),
                    onTap: () => store.updateSettings((x) => x.themeColor = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accents[i].$2,
                        shape: BoxShape.circle,
                        border: Border.all(color: s.themeColor == i ? AppColors.ink : Colors.transparent, width: 3),
                      ),
                      child: s.themeColor == i ? const Icon(Icons.check, color: Colors.white) : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('الوضع', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, icon: Icon(Icons.light_mode_outlined), label: Text('فاتح')),
              ButtonSegment(value: 2, icon: Icon(Icons.dark_mode_outlined), label: Text('ليلي')),
              ButtonSegment(value: 0, icon: Icon(Icons.phone_android), label: Text('تلقائي')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => store.updateSettings((x) => x.themeMode = v.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'اسمك (للترحيب في الجدول)', hintText: 'مثلًا: أستاذ محمد'),
            onChanged: (v) => store.updateSettings((x) => x.teacherName = v),
          ),
        ],
      ),
    );
  }
}

class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({this.title, this.time});

  final String? title;
  final String? time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF26344F), borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(
            width: 170,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الحصة الجاية',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(time ?? 'مفيش حصص', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if (title != null)
                  Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'شكل الويدجت على الشاشة الرئيسية',
              style: TextStyle(color: AppColors.navyText, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
