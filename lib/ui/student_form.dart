import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../models.dart';
import '../phone.dart';
import '../services/contacts.dart';
import '../store.dart';
import 'common.dart';
import 'group_form.dart';
import 'theme.dart';

/// Adds a new student: name, classes and number. The rest is filled in later
/// from the student's page.
Future<void> openStudentForm(BuildContext context, {String? groupId}) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => StudentForm(groupId: groupId)));

/// Asks before deleting [s] with all their payments. Returns true if deleted.
Future<bool> deleteStudentAsk(BuildContext context, Student s) async {
  final ok = await confirm(context, 'حذف ${s.name}؟', 'هيتمسح الطالب وكل مدفوعاته نهائيًا.', ok: 'حذف', danger: true);
  if (!ok || !context.mounted) return false;
  await StoreScope.read(context).deleteStudent(s);
  if (context.mounted) toast(context, 'اتمسح ${s.name}');
  return true;
}

class StudentForm extends StatefulWidget {
  const StudentForm({super.key, this.groupId});

  /// Pre-selects this class.
  final String? groupId;

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = _Phone();
  late final Set<String> _groups = {?widget.groupId};
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _phone.load('', _defaultCode(StoreScope.read(context).data));
  }

  @override
  Widget build(BuildContext context) {
    final d = StoreScope.of(context).data;
    final groups = d.groups.where((g) => !g.archived).toList()..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('طالب جديد')),
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
              decoration: const InputDecoration(labelText: '١. اسم الطالب'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب اسم الطالب' : null,
            ),
            const SizedBox(height: 20),
            SectionTitle(
              '٢. بياخد أنهي حصة؟',
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
                  padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _groups.contains(g.id),
                    onChanged: (v) => setState(() => v == true ? _groups.add(g.id) : _groups.remove(g.id)),
                    title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(scheduleSummary(g)),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _PhoneField(phone: _phone, label: '٣. رقم الموبايل (اختياري)', onPicked: _fillName),
            const SizedBox(height: 12),
            Text(
              'رقم ولي الأمر والعيلة والسعر الخاص وغيرهم تقدر تضيفهم بعدين من صفحة الطالب.',
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _fillName(String name) {
    if (_name.text.trim().isEmpty) _name.text = name;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final s = Student(
      id: store.newId(),
      name: _name.text.trim(),
      phone: _phone.value,
      joinedAt: DateTime(DateTime.now().year, DateTime.now().month),
    );
    await store.saveStudent(s, _groups);
    if (mounted) Navigator.pop(context);
  }
}

String _defaultCode(AppData d) => d.settings.currency == 'ر.س' ? '966' : '20';

/// A phone number field with the contacts picker and the country code.
class _PhoneField extends StatefulWidget {
  const _PhoneField({required this.phone, required this.label, this.onPicked});

  final _Phone phone;
  final String label;

  /// Called with the contact's name when a number is picked from the contacts.
  final ValueChanged<String>? onPicked;

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  @override
  Widget build(BuildContext context) {
    final p = widget.phone;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: p.text,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            // An empty number is usually in the phone's contacts already.
            onTap: () {
              if (p.text.text.trim().isEmpty) _pick();
            },
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: IconButton(
                tooltip: 'اختار من الأسماء',
                icon: const Icon(Icons.contacts_outlined),
                onPressed: _pick,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _CountryButton(code: p.code, onChanged: (c) => setState(() => p.code = c)),
      ],
    );
  }

  Future<void> _pick() async {
    final p = widget.phone;
    try {
      final c = await pickContactPhone();
      if (c == null || !mounted) return;
      final (code, local) = splitPhone(c.number, fallback: p.code);
      setState(() {
        if (code.isNotEmpty) p.code = code;
        p.text.text = local;
      });
      widget.onPicked?.call(c.name);
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (_) {
      if (mounted) toast(context, 'مقدرتش أفتح الأسماء، اكتب الرقم بإيدك');
    }
  }
}

// ---- editing one thing at a time, from the student's page ----

Set<String> _classIds(AppData d, Student s) => {for (final g in d.groupsOf(s, includeArchived: true)) g.id};

/// A small sheet with a title, the fields, and a save button.
Future<void> _editSheet(
  BuildContext context,
  String title,
  List<Widget> Function(StateSetter setState) fields,
  Future<void> Function() save,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ...fields(setState),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await save();
                  if (c.mounted) Navigator.pop(c);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Edits one text detail of [s]: name, stage or notes.
Future<void> editStudentText(
  BuildContext context,
  Student s, {
  required String title,
  required String initial,
  required void Function(String v) apply,
  bool multiline = false,
  Set<String> suggestions = const {},
}) {
  final store = StoreScope.read(context);
  final ctl = TextEditingController(text: initial);
  return _editSheet(
    context,
    title,
    (setState) => [
      TextField(controller: ctl, autofocus: true, maxLines: multiline ? 4 : 1),
      if (suggestions.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in suggestions.take(8))
              ActionChip(label: Text(o), onPressed: () => ctl.text = o, visualDensity: VisualDensity.compact),
          ],
        ),
      ],
    ],
    () async {
      apply(ctl.text.trim());
      await store.saveStudent(s, _classIds(store.data, s));
    },
  );
}

/// Edits the student's or the parent's number.
Future<void> editStudentPhone(BuildContext context, Student s, {bool parent = false}) {
  final store = StoreScope.read(context);
  final p = _Phone()..load(parent ? s.parentPhone : s.phone, _defaultCode(store.data));
  return _editSheet(
    context,
    parent ? 'رقم ولي الأمر' : 'رقم الطالب',
    (setState) => [_PhoneField(phone: p, label: 'الرقم')],
    () async {
      if (parent) {
        s.parentPhone = p.value;
      } else {
        s.phone = p.value;
      }
      await store.saveStudent(s, _classIds(store.data, s));
    },
  );
}

/// Picks the classes [s] takes.
Future<void> editStudentClasses(BuildContext context, Student s) {
  final store = StoreScope.read(context);
  final d = store.data;
  final chosen = _classIds(d, s);
  final groups = d.groups.where((g) => !g.archived || chosen.contains(g.id)).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return _editSheet(
    context,
    'الحصص اللي بياخدها',
    (setState) => [
      if (groups.isEmpty) Text('لسه مفيش حصص.', style: TextStyle(color: AppColors.muted)),
      for (final g in groups)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: chosen.contains(g.id),
          onChanged: (v) => setState(() => v == true ? chosen.add(g.id) : chosen.remove(g.id)),
          title: Text(g.name),
          subtitle: Text(scheduleSummary(g)),
        ),
    ],
    () => store.saveStudent(s, chosen),
  );
}

/// A special price for [s] in each class, and their own hours in a long shared lesson.
Future<void> editStudentPrices(BuildContext context, Student s) {
  final store = StoreScope.read(context);
  final d = store.data;
  final currency = d.settings.currency;
  final groups = d.groupsOf(s);
  final prices = {for (final g in groups) g.id: TextEditingController(text: s.priceOverrides[g.id]?.let(_plain) ?? '')};
  final hours = {for (final g in groups) g.id: TextEditingController(text: s.hoursOverrides[g.id]?.let(_plain) ?? '')};
  return _editSheet(
    context,
    'سعر خاص',
    (setState) => [
      Text('سيبها فاضية لو الطالب بيدفع سعر الحصة العادي.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
      const SizedBox(height: 10),
      if (groups.isEmpty) Text('الطالب مش في أي حصة.', style: TextStyle(color: AppColors.muted)),
      for (final g in groups) ...[
        Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: prices[g.id],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            isDense: true,
            labelText: 'السعر للطالب ده',
            hintText: 'العادي ${fmtMoney(g.currentPrice, currency)}',
            suffixText: currency,
          ),
        ),
        if (g.payType == PayType.perLesson && _longest(g) > 60) ...[
          const SizedBox(height: 8),
          TextField(
            controller: hours[g.id],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'ساعات الطالب ده في الحصة',
              hintText: 'مثلًا ١ لو الحصة لكذا أخ',
              helperText: 'لو فاضية بيتحسب مدة الحصة كلها (${fmtDuration(_longest(g))})',
              suffixText: 'ساعة',
            ),
          ),
        ],
        const SizedBox(height: 14),
      ],
    ],
    () async {
      s.priceOverrides.clear();
      s.hoursOverrides.clear();
      for (final g in groups) {
        final v = parseArNum(prices[g.id]!.text);
        if (v != null && v >= 0) s.priceOverrides[g.id] = v;
        final h = parseArNum(hours[g.id]!.text);
        if (h != null && h > 0) s.hoursOverrides[g.id] = h;
      }
      await store.saveStudent(s, _classIds(d, s));
    },
  );
}

/// The family name shared by siblings, and the price of a lesson they take together.
Future<void> editStudentFamily(BuildContext context, Student s) {
  final store = StoreScope.read(context);
  final d = store.data;
  final families = {for (final o in d.students) o.family.trim()}..remove('');
  final name = TextEditingController(text: s.family);
  final price = TextEditingController(text: d.familyPrices[s.family.trim()]?.let(_plain) ?? '');
  return _editSheet(
    context,
    'العيلة (للإخوات)',
    (setState) => [
      _Suggest(
        controller: name,
        label: 'اسم العيلة',
        options: families,
        hint: 'اكتب نفس الاسم لكل الإخوات، مثال: محمود',
      ),
      const SizedBox(height: 12),
      TextField(
        controller: price,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'سعر الحصة للإخوات مع بعض (اختياري)',
          hintText: 'مثلًا ٢٠٠ للتلاتة',
          helperText: 'لو كتبته، الإخوات يبقى ليهم حساب واحد ودفع واحد',
          helperMaxLines: 2,
          suffixText: d.settings.currency,
        ),
      ),
    ],
    () async {
      s.family = name.text.trim();
      if (s.family.isNotEmpty) {
        final v = parseArNum(price.text);
        if (v != null && v > 0) {
          d.familyPrices[s.family] = v;
        } else {
          d.familyPrices.remove(s.family);
        }
      }
      await store.saveStudent(s, _classIds(d, s));
    },
  );
}

/// The day the student's account starts.
Future<void> editStudentStart(BuildContext context, Student s) async {
  final store = StoreScope.read(context);
  final p = await showDatePicker(
    context: context,
    helpText: 'الحساب يبدأ من',
    initialDate: s.joinedAt,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (p == null) return;
  s.joinedAt = dateOnly(p);
  await store.saveStudent(s, _classIds(store.data, s));
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

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
