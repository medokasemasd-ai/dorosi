import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'student_form.dart';
import 'theme.dart';

Future<void> openGroupForm(BuildContext context, {Group? group, int? weekday}) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => GroupForm(group: group, weekday: weekday),
  ),
);

/// "السبت والثلاثاء · ٦:٠٠ م" or "٣ حصص مراجعة من ١٢ أكتوبر".
String scheduleSummary(Group g) {
  final parts = <String>[];
  if (g.slots.isNotEmpty) {
    final slots = [...g.slots]..sort((a, b) => weekOrder.indexOf(a.weekday).compareTo(weekOrder.indexOf(b.weekday)));
    final times = {for (final s in slots) s.startMin};
    if (times.length == 1) {
      parts.add('${slots.map((s) => weekdayName(s.weekday)).join(' و')} · ${fmtTime(times.first)}');
    } else {
      parts.add(slots.map((s) => '${weekdayName(s.weekday)} ${fmtTime(s.startMin)}').join('، '));
    }
  }
  if (g.sessions.isNotEmpty) {
    final dates = [...g.sessions]..sort((a, b) => a.date.compareTo(b.date));
    final label = g.kind == GroupKind.review ? 'مراجعة' : 'إضافية';
    parts.add('${lessonsCount(dates.length)} $label من ${fmtShortDate(dates.first.date)}');
  }
  return parts.isEmpty ? 'بدون مواعيد' : parts.join(' · ');
}

class GroupForm extends StatefulWidget {
  const GroupForm({super.key, this.group, this.weekday});

  final Group? group;
  final int? weekday;

  @override
  State<GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<GroupForm> {
  final _form = GlobalKey<FormState>();
  late final Group? _orig = widget.group;
  late final _name = TextEditingController(text: _orig?.name);
  late final _stage = TextEditingController(text: _orig?.stage);
  late final _notes = TextEditingController(text: _orig?.notes);
  late final _price = TextEditingController(text: _orig == null ? '' : _plain(_orig.currentPrice));
  late GroupKind _kind = _orig?.kind ?? GroupKind.group;
  late PayType _pay = _orig?.payType ?? PayType.perLesson;
  late bool _remindStart = _orig?.remindStart ?? true;
  late bool _remindEnd = _orig?.remindEnd ?? true;
  late DateTime _start = _orig?.createdAt ?? DateTime(DateTime.now().year, DateTime.now().month);
  late final List<WeeklySlot> _slots =
      _orig?.slots.map((e) => e.copy()).toList() ??
      [WeeklySlot(weekday: widget.weekday ?? DateTime.saturday, startMin: 16 * 60, durationMin: 60)];
  late final List<DatedSession> _sessions = _orig?.sessions.map((e) => e.copy()).toList() ?? [];
  late final Set<String> _students = {...?_orig?.studentIds};

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final currency = d.settings.currency;
    final stages = {for (final s in d.students) s.stage.trim(), for (final g in d.groups) g.stage.trim()}..remove('');
    final students = d.students.where((s) => !s.archived || _students.contains(s.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: Text(_orig == null ? 'حصة جديدة' : 'تعديل الحصة'),
        actions: [
          if (_orig != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                final g = _orig;
                if (v == 'archive') {
                  await store.setGroupArchived(g, !g.archived);
                  if (context.mounted) Navigator.pop(context);
                } else if (v == 'delete') {
                  final ok = await confirm(
                    context,
                    'حذف ${g.name}؟',
                    'الحصة هتتمسح من الجدول، وحساب الطلاب عنها هيتشال. لو الحصة خلصت بس، الأفضل تنقلها للسابقة.',
                    ok: 'حذف',
                    danger: true,
                  );
                  if (ok) {
                    await store.deleteGroup(g);
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Text(_orig.archived ? 'رجّعها للجدول' : 'الحصة خلصت (نقلها للسابقة)'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('حذف الحصة')),
              ],
            ),
        ],
      ),
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
            SegmentedButton<GroupKind>(
              segments: const [
                ButtonSegment(value: GroupKind.individual, label: Text('فردي'), icon: Icon(Icons.person_outline)),
                ButtonSegment(value: GroupKind.group, label: Text('مجموعة'), icon: Icon(Icons.groups_outlined)),
                ButtonSegment(value: GroupKind.review, label: Text('مراجعة'), icon: Icon(Icons.menu_book_outlined)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() {
                _kind = v.first;
                if (_kind == GroupKind.review) {
                  _pay = PayType.perLesson;
                  if (_orig == null && _sessions.isEmpty) {
                    _slots.clear();
                    _addSession();
                  }
                }
              }),
            ),
            if (_kind == GroupKind.review)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'حصص مراجعة قبل الامتحان بتواريخ محددة، وبعدها تختفي من الجدول لوحدها.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: 'اسم الحصة',
                hintText: _kind == GroupKind.individual
                    ? 'مثال: أحمد محمود (فيزياء)'
                    : 'مثال: الثالث الثانوي · مجموعة أ',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب اسم الحصة' : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stage,
              decoration: const InputDecoration(labelText: 'المرحلة / الصف'),
            ),
            if (stages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final o in stages.take(8))
                      ActionChip(
                        label: Text(o),
                        onPressed: () => _stage.text = o,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const SectionTitle('الحساب'),
            SegmentedButton<PayType>(
              segments: const [
                ButtonSegment(value: PayType.monthly, label: Text('شهري')),
                ButtonSegment(value: PayType.perLesson, label: Text('بالحصة')),
              ],
              selected: {_pay},
              onSelectionChanged: (v) => setState(() => _pay = v.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _pay == PayType.monthly ? 'السعر في الشهر' : 'سعر الحصة (الساعة)',
                suffixText: currency,
                helperText: [
                  if (_pay == PayType.perLesson) 'الحصة اللي مدتها ساعتين بتتحسب بضعف السعر',
                  if (_orig != null) 'لو غيرت السعر، الشهور اللي فاتت هتفضل بالسعر القديم',
                ].join('\n'),
                helperMaxLines: 2,
              ),
              validator: (v) => parseArNum(v ?? '') == null ? 'اكتب السعر' : null,
            ),
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _start,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => _start = p);
              },
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('الحصة بدأت من'),
                subtitle: Text(fmtDate(_start)),
              ),
            ),
            const SizedBox(height: 20),
            if (_kind != GroupKind.review) ...[
              SectionTitle(
                'المواعيد كل أسبوع',
                trailing: TextButton.icon(
                  onPressed: () => setState(
                    () => _slots.add(
                      WeeklySlot(
                        weekday: _slots.isEmpty ? (widget.weekday ?? DateTime.saturday) : _slots.last.weekday,
                        startMin: _slots.isEmpty ? 16 * 60 : _slots.last.startMin,
                        durationMin: _slots.isEmpty ? 90 : _slots.last.durationMin,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('ميعاد'),
                ),
              ),
              for (var i = 0; i < _slots.length; i++) _slotRow(i),
              const SizedBox(height: 12),
            ],
            SectionTitle(
              _kind == GroupKind.review ? 'مواعيد المراجعة' : 'حصص إضافية بتاريخ (اختياري)',
              trailing: TextButton.icon(
                onPressed: () => setState(_addSession),
                icon: const Icon(Icons.add),
                label: const Text('حصة'),
              ),
            ),
            for (var i = 0; i < _sessions.length; i++) _sessionRow(i),
            const SizedBox(height: 20),
            SectionTitle(
              'الطلاب (${arNum(_students.length)})',
              trailing: TextButton.icon(
                onPressed: _quickAddStudent,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('طالب جديد'),
              ),
            ),
            if (students.isEmpty)
              Text('لسه مفيش طلاب. دوس "طالب جديد" وضيفه بسرعة.', style: TextStyle(color: AppColors.muted)),
            if (students.isNotEmpty)
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final s in students)
                      CheckboxListTile(
                        value: _students.contains(s.id),
                        onChanged: (v) => setState(() => v == true ? _students.add(s.id) : _students.remove(s.id)),
                        title: Text(s.name),
                        subtitle: s.stage.isEmpty && s.family.isEmpty
                            ? null
                            : Text(
                                [
                                  if (s.stage.isNotEmpty) s.stage,
                                  if (s.family.isNotEmpty) 'عائلة ${s.family}',
                                ].join(' · '),
                              ),
                        secondary: PopupMenuButton<String>(
                          tooltip: 'تعديل أو حذف',
                          onSelected: (v) => _studentAction(v, s),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('تعديل الطالب')),
                            PopupMenuItem(value: 'delete', child: Text('حذف الطالب')),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const SectionTitle('التذكير'),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _remindStart,
                    onChanged: (v) => setState(() => _remindStart = v),
                    title: const Text('تذكير قبل بداية الحصة'),
                  ),
                  SwitchListTile(
                    value: _remindEnd,
                    onChanged: (v) => setState(() => _remindEnd = v),
                    title: const Text('تنبيه عند نهاية الحصة'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
          ],
        ),
      ),
    );
  }

  void _addSession() {
    final last = _sessions.isEmpty ? null : _sessions.last;
    final base = last?.date ?? DateTime.now();
    _sessions.add(
      DatedSession(
        date: DateTime(base.year, base.month, base.day + (last == null ? 1 : 1)),
        startMin: last?.startMin ?? 16 * 60,
        durationMin: last?.durationMin ?? 60,
      ),
    );
  }

  Widget _slotRow(int i) {
    final s = _slots[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            DropdownButton<int>(
              value: s.weekday,
              underline: const SizedBox(),
              items: [for (final w in weekOrder) DropdownMenuItem(value: w, child: Text(weekdayName(w)))],
              onChanged: (v) => setState(() => s.weekday = v!),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TimeButton(minutes: s.startMin, onPicked: (m) => setState(() => s.startMin = m)),
            ),
            _DurationButton(minutes: s.durationMin, onPicked: (m) => setState(() => s.durationMin = m)),
            IconButton(
              tooltip: 'حذف الميعاد',
              onPressed: () => setState(() => _slots.removeAt(i)),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionRow(int i) {
    final s = _sessions[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            TextButton(
              onPressed: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: s.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => s.date = p);
              },
              child: Text(fmtShortDate(s.date)),
            ),
            Expanded(
              child: _TimeButton(minutes: s.startMin, onPicked: (m) => setState(() => s.startMin = m)),
            ),
            _DurationButton(minutes: s.durationMin, onPicked: (m) => setState(() => s.durationMin = m)),
            IconButton(
              tooltip: 'حذف الحصة',
              onPressed: () => setState(() => _sessions.removeAt(i)),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _studentAction(String v, Student s) async {
    if (v == 'edit') {
      final inClass = _students.contains(s.id);
      await openStudentForm(context, student: s);
      // Keep the tick for this class as it is in this form; it is saved with the class.
      if (mounted) setState(() => inClass ? _students.add(s.id) : _students.remove(s.id));
    } else if (v == 'delete') {
      if (await deleteStudentAsk(context, s) && mounted) setState(() => _students.remove(s.id));
    }
  }

  Future<void> _quickAddStudent() async {
    final store = StoreScope.read(context);
    final name = TextEditingController();
    final phone = TextEditingController();
    final family = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('طالب جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'الموبايل'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: family,
              decoration: const InputDecoration(labelText: 'العائلة (للإخوات)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('إضافة')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final s = Student(
      id: store.newId(),
      name: name.text.trim(),
      phone: westernDigits(phone.text.trim()),
      family: family.text.trim(),
      stage: _stage.text.trim(),
      joinedAt: dateOnly(_start),
    );
    // Saved now with no classes; the class membership is set when this form is saved.
    await store.saveStudent(s, {});
    setState(() => _students.add(s.id));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_slots.isEmpty && _sessions.isEmpty) {
      toast(context, 'ضيف ميعاد واحد على الأقل');
      return;
    }
    final store = StoreScope.read(context);
    final g = _orig ?? Group(id: store.newId(), name: '');
    g
      ..name = _name.text.trim()
      ..stage = _stage.text.trim()
      ..kind = _kind
      ..payType = _pay
      ..slots = _kind == GroupKind.review ? [] : _slots
      ..sessions = _sessions
      ..studentIds = _students.toList()
      ..remindStart = _remindStart
      ..remindEnd = _remindEnd
      ..notes = _notes.text.trim()
      ..createdAt = dateOnly(_start);
    g.setPrice(parseArNum(_price.text)!);
    await store.saveGroup(g);
    if (mounted) Navigator.pop(context);
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.minutes, required this.onPicked});

  final int minutes;
  final ValueChanged<int> onPicked;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        );
        if (t != null) onPicked(t.hour * 60 + t.minute);
      },
      icon: const Icon(Icons.schedule, size: 18),
      label: Text(fmtTime(minutes)),
    );
  }
}

class _DurationButton extends StatelessWidget {
  const _DurationButton({required this.minutes, required this.onPicked});

  final int minutes;
  final ValueChanged<int> onPicked;

  static const _options = [30, 45, 60, 75, 90, 105, 120, 150, 180];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'مدة الحصة',
      onSelected: onPicked,
      itemBuilder: (_) => [for (final o in _options) PopupMenuItem(value: o, child: Text(fmtDuration(o)))],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text(fmtDuration(minutes), style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ),
    );
  }
}

String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
