import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../phone.dart';
import '../services/contacts.dart';
import '../store.dart';
import 'common.dart';
import 'group_form.dart';
import 'theme.dart';

Future<void> openStudentForm(BuildContext context, {Student? student, String? groupId}) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => StudentForm(student: student, groupId: groupId),
  ),
);

/// Asks before deleting [s] with all their payments. Returns true if deleted.
Future<bool> deleteStudentAsk(BuildContext context, Student s) async {
  final ok = await confirm(context, 'حذف ${s.name}؟', 'هيتمسح الطالب وكل مدفوعاته نهائيًا.', ok: 'حذف', danger: true);
  if (!ok || !context.mounted) return false;
  await StoreScope.read(context).deleteStudent(s);
  if (context.mounted) toast(context, 'اتمسح ${s.name}');
  return true;
}

/// Edit / move to former students / delete, from a long press on a student anywhere.
Future<void> showStudentActions(BuildContext context, Student s) async {
  final v = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('تعديل الاسم والبيانات'),
            onTap: () => Navigator.pop(c, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(s.archived ? 'رجّعه للطلاب الحاليين' : 'نقله للطلاب السابقين'),
            onTap: () => Navigator.pop(c, 'archive'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: AppColors.unpaid),
            title: Text('حذف الطالب', style: TextStyle(color: AppColors.unpaid)),
            onTap: () => Navigator.pop(c, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (v) {
    case 'edit':
      await openStudentForm(context, student: s);
    case 'archive':
      await StoreScope.read(context).setStudentArchived(s, !s.archived);
    case 'delete':
      await deleteStudentAsk(context, s);
  }
}

class StudentForm extends StatefulWidget {
  const StudentForm({super.key, this.student, this.groupId});

  final Student? student;

  /// Pre-selects this class for a new student.
  final String? groupId;

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.student?.name);
  final _phone = _Phone();
  final _parentPhone = _Phone();
  bool _more = false;
  late final _stage = TextEditingController(text: widget.student?.stage);
  late final _family = TextEditingController(text: widget.student?.family);
  late final _notes = TextEditingController(text: widget.student?.notes);
  late DateTime _joined = widget.student?.joinedAt ?? DateTime(DateTime.now().year, DateTime.now().month);
  final Set<String> _groups = {};
  final Map<String, TextEditingController> _prices = {};
  final Map<String, TextEditingController> _hours = {};
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final d = StoreScope.read(context).data;
    final s = widget.student;
    final fallback = d.settings.currency == 'ر.س' ? '966' : '20';
    _phone.load(s?.phone ?? '', fallback);
    _parentPhone.load(s?.parentPhone ?? '', fallback);
    // Open the extra options when this student already uses some of them.
    _more =
        s != null &&
        (s.parentPhone.isNotEmpty ||
            s.stage.isNotEmpty ||
            s.family.isNotEmpty ||
            s.notes.isNotEmpty ||
            s.priceOverrides.isNotEmpty ||
            s.hoursOverrides.isNotEmpty ||
            _phone.code != fallback);
    if (s != null) {
      _groups.addAll(d.groupsOf(s, includeArchived: true).map((g) => g.id));
      s.priceOverrides.forEach((gid, p) => _prices[gid] = TextEditingController(text: _plain(p)));
      s.hoursOverrides.forEach((gid, h) => _hours[gid] = TextEditingController(text: _plain(h)));
    } else if (widget.groupId != null) {
      _groups.add(widget.groupId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final currency = d.settings.currency;
    final groups = d.groups.where((g) => !g.archived || _groups.contains(g.id)).toList();
    final families = {for (final s in d.students) s.family.trim()}..remove('');
    final stages = {for (final s in d.students) s.stage.trim(), for (final g in d.groups) g.stage.trim()}..remove('');

    return Scaffold(
      appBar: AppBar(title: Text(widget.student == null ? 'طالب جديد' : 'تعديل الطالب')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: _save, child: const Text('حفظ')),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'اسم الطالب'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب اسم الطالب' : null,
            ),
            const SizedBox(height: 12),
            _phoneField(_phone, 'رقم الطالب (اختياري)', fillName: true),
            const SizedBox(height: 20),
            SectionTitle(
              'الحصص',
              trailing: TextButton.icon(
                onPressed: () => openGroupForm(context),
                icon: const Icon(Icons.add),
                label: const Text('حصة جديدة'),
              ),
            ),
            if (groups.isEmpty)
              Text('لسه مفيش حصص. ضيف حصة الأول وبعدين اختارها هنا.', style: TextStyle(color: AppColors.muted)),
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _groups.contains(g.id),
                        onChanged: (v) => setState(() => v == true ? _groups.add(g.id) : _groups.remove(g.id)),
                        title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${scheduleSummary(g)}\n${fmtMoney(g.currentPrice, currency)} ${g.payType == PayType.perLesson ? 'للساعة' : 'في الشهر'}',
                        ),
                        isThreeLine: true,
                      ),
                      if (_more && _groups.contains(g.id) && g.payType == PayType.perLesson && _longest(g) > 60)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 12, bottom: 8),
                          child: TextField(
                            controller: _hours.putIfAbsent(g.id, () => TextEditingController()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'ساعات الطالب ده في الحصة (اختياري)',
                              hintText: 'مثلًا ١ لو الحصة لكذا أخ وكل واحد ساعة',
                              helperText: 'لو فاضية بيتحسب مدة الحصة كلها (${fmtDuration(_longest(g))})',
                              suffixText: 'ساعة',
                            ),
                          ),
                        ),
                      if (_more && _groups.contains(g.id))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 12, bottom: 8),
                          child: TextField(
                            controller: _prices.putIfAbsent(g.id, () => TextEditingController()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'سعر خاص للطالب ده (اختياري)',
                              hintText: 'مثلًا خصم الإخوات',
                              suffixText: currency,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => setState(() => _more = !_more),
              icon: Icon(_more ? Icons.expand_less : Icons.expand_more),
              label: Text(_more ? 'إخفاء الخيارات الإضافية' : 'خيارات إضافية'),
            ),
            if (!_more)
              Text(
                'رقم ولي الأمر، كود الدولة، المرحلة، العيلة، سعر خاص، وغيرهم',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            if (_more) ...[
              const SizedBox(height: 8),
              _phoneField(_parentPhone, 'رقم ولي الأمر (اختياري)'),
              const SizedBox(height: 12),
              _Suggest(controller: _stage, label: 'المرحلة / الصف', options: stages, hint: 'مثال: الثالث الثانوي'),
              const SizedBox(height: 12),
              _Suggest(
                controller: _family,
                label: 'العائلة (للإخوات)',
                options: families,
                hint: 'اكتب نفس الاسم لكل الإخوات، مثال: محمود',
              ),
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _joined,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) setState(() => _joined = p);
                },
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('الحساب يبدأ من'),
                  subtitle: Text(fmtDate(_joined)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _phoneField(_Phone p, String label, {bool fillName = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextFormField(
          controller: p.text,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          // An empty number is usually in the phone's contacts already.
          onTap: () {
            if (p.text.text.trim().isEmpty) _pickContact(p, fillName: fillName);
          },
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: IconButton(
              tooltip: 'اختار من الأسماء',
              icon: const Icon(Icons.contacts_outlined),
              onPressed: () => _pickContact(p, fillName: fillName),
            ),
          ),
        ),
      ),
      if (_more) ...[
        const SizedBox(width: 8),
        _CountryButton(code: p.code, onChanged: (c) => setState(() => p.code = c)),
      ],
    ],
  );

  Future<void> _pickContact(_Phone p, {bool fillName = false}) async {
    try {
      final c = await pickContactPhone();
      if (c == null || !mounted) return;
      final (code, local) = splitPhone(c.number, fallback: p.code);
      setState(() {
        if (code.isNotEmpty) p.code = code;
        p.text.text = local;
        if (fillName && _name.text.trim().isEmpty) _name.text = c.name;
      });
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (_) {
      if (mounted) toast(context, 'مقدرتش أفتح الأسماء، اكتب الرقم بإيدك');
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final s = widget.student ?? Student(id: store.newId(), name: '');
    s
      ..name = _name.text.trim()
      ..phone = _phone.value
      ..parentPhone = _parentPhone.value
      ..stage = _stage.text.trim()
      ..family = _family.text.trim()
      ..notes = _notes.text.trim()
      ..joinedAt = dateOnly(_joined);
    s.priceOverrides.clear();
    s.hoursOverrides.clear();
    for (final gid in _groups) {
      final v = parseArNum(_prices[gid]?.text ?? '');
      if (v != null && v >= 0) s.priceOverrides[gid] = v;
      final h = parseArNum(_hours[gid]?.text ?? '');
      if (h != null && h > 0) s.hoursOverrides[gid] = h;
    }
    await store.saveStudent(s, _groups);
    if (mounted) Navigator.pop(context);
  }
}

/// A text field with tap-to-fill suggestions from values used before.
class _Suggest extends StatelessWidget {
  const _Suggest({required this.controller, required this.label, required this.options, this.hint});

  final TextEditingController controller;
  final String label;
  final Set<String> options;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
        if (options.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in options.take(8))
                  ActionChip(
                    label: Text(o),
                    onPressed: () => controller.text = o,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The longest lesson of [g], in minutes.
int _longest(Group g) => [
  for (final s in g.slots) s.durationMin,
  for (final s in g.sessions) s.durationMin,
].fold(0, (a, b) => a > b ? a : b);

String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// The country code in front of a phone number; tap to pick another country.
class _CountryButton extends StatelessWidget {
  const _CountryButton({required this.code, required this.onChanged});

  final String code;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final flag = countries.where((c) => c.$3 == code).map((c) => c.$2).firstOrNull ?? '🌍';
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        key: const ValueKey('country'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () async {
          final picked = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            backgroundColor: AppColors.card,
            builder: (c) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('كود الدولة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  for (final (name, f, cc) in countries)
                    ListTile(
                      leading: Text(f, style: const TextStyle(fontSize: 24)),
                      title: Text(name),
                      trailing: Text('+$cc', textDirection: TextDirection.ltr),
                      selected: cc == code,
                      onTap: () => Navigator.pop(c, cc),
                    ),
                ],
              ),
            ),
          );
          if (picked != null) onChanged(picked);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 4),
            Text('+$code', textDirection: TextDirection.ltr),
          ],
        ),
      ),
    );
  }
}

/// A phone number being edited: its country code and the local part.
class _Phone {
  final text = TextEditingController();
  String code = '20';

  void load(String phone, String fallback) {
    final (c, local) = splitPhone(phone, fallback: fallback);
    code = c;
    text.text = local;
  }

  String get value => joinPhone(code, text.text);
}
