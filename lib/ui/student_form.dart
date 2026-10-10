import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'group_form.dart';
import 'theme.dart';

Future<void> openStudentForm(BuildContext context, {Student? student, String? groupId}) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => StudentForm(student: student, groupId: groupId)));

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
  late final _phone = TextEditingController(text: widget.student?.phone);
  late final _stage = TextEditingController(text: widget.student?.stage);
  late final _family = TextEditingController(text: widget.student?.family);
  late final _notes = TextEditingController(text: widget.student?.notes);
  late DateTime _joined = widget.student?.joinedAt ?? DateTime(DateTime.now().year, DateTime.now().month);
  final Set<String> _groups = {};
  final Map<String, TextEditingController> _prices = {};
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final d = StoreScope.read(context).data;
    final s = widget.student;
    if (s != null) {
      _groups.addAll(d.groupsOf(s, includeArchived: true).map((g) => g.id));
      s.priceOverrides.forEach((gid, p) => _prices[gid] = TextEditingController(text: _plain(p)));
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
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الموبايل (اختياري)', prefixIcon: Icon(Icons.phone_outlined)),
            ),
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
              const Text('لسه مفيش حصص. ضيف حصة الأول وبعدين اختارها هنا.', style: TextStyle(color: AppColors.muted)),
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                  child: Column(children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _groups.contains(g.id),
                      onChanged: (v) => setState(() => v == true ? _groups.add(g.id) : _groups.remove(g.id)),
                      title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${scheduleSummary(g)}\n${fmtMoney(g.currentPrice, currency)} ${g.payType == PayType.perLesson ? 'للحصة' : 'في الشهر'}',
                      ),
                      isThreeLine: true,
                    ),
                    if (_groups.contains(g.id))
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
                  ]),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final s = widget.student ?? Student(id: store.newId(), name: '');
    s
      ..name = _name.text.trim()
      ..phone = westernDigits(_phone.text.trim())
      ..stage = _stage.text.trim()
      ..family = _family.text.trim()
      ..notes = _notes.text.trim()
      ..joinedAt = dateOnly(_joined);
    s.priceOverrides.clear();
    for (final gid in _groups) {
      final v = parseArNum(_prices[gid]?.text ?? '');
      if (v != null && v >= 0) s.priceOverrides[gid] = v;
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: controller, decoration: InputDecoration(labelText: label, hintText: hint)),
      if (options.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final o in options.take(8))
              ActionChip(label: Text(o), onPressed: () => controller.text = o, visualDensity: VisualDensity.compact),
          ]),
        ),
    ]);
  }
}

String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
