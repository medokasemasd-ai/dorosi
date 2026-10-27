import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'student_form.dart';
import 'student_page.dart';
import 'help.dart';
import 'theme.dart';

enum _Filter { all, unpaid, archived }

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  _Filter _filter = _Filter.all;
  bool _byFamily = false;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final now = DateTime.now();
    final currency = d.settings.currency;

    final rows = <_Row>[];
    for (final s in d.students) {
      if (_filter == _Filter.archived ? !s.archived : s.archived) continue;
      rows.add(_Row(s, d.accountFor(s, now), d.groupsOf(s)));
    }

    var shown = rows.where((r) {
      if (_q.isNotEmpty && !r.student.name.contains(_q) && !r.student.family.contains(_q)) return false;
      switch (_filter) {
        case _Filter.unpaid:
          return r.bill.status == PayStatus.unpaid || r.bill.status == PayStatus.partial;
        case _Filter.all:
        case _Filter.archived:
          return true;
      }
    }).toList();
    shown.sort((a, b) => a.student.name.compareTo(b.student.name));

    return Scaffold(
      appBar: AppBar(title: const Text('الطلاب'), actions: const [HelpButton(1)]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => openStudentForm(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('طالب جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          const TabHint('كل طلابك. دوس على أي طالب تشوف حسابه وحضوره وتعدّل بياناته.'),
          TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث باسم الطالب أو العائلة'),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(_filterLabel(f)),
                      selected: _filter == f,
                      showCheckmark: false,
                      selectedColor: AppColors.ink,
                      labelStyle: TextStyle(
                        color: _filter == f ? AppColors.onPrimary : AppColors.ink,
                        fontFamily: 'Plex',
                      ),
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
                FilterChip(
                  label: const Text('حسب العائلة'),
                  selected: _byFamily,
                  onSelected: (v) => setState(() => _byFamily = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (d.students.isEmpty)
            EmptyState(
              icon: Icons.people_outline,
              text: 'لسه مفيش طلاب.\nضيف الطالب واختار الحصة أو المجموعة بتاعته.',
              action: FilledButton.icon(
                onPressed: () => openStudentForm(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('إضافة طالب'),
              ),
            )
          else if (shown.isEmpty)
            const EmptyState(icon: Icons.filter_alt_off_outlined, text: 'مفيش طلاب بالشرط ده')
          else if (_byFamily)
            ..._familySections(shown, currency)
          else
            for (final r in shown) _tile(r, currency),
        ],
      ),
    );
  }

  List<Widget> _familySections(List<_Row> rows, String currency) {
    final families = <String, List<_Row>>{};
    for (final r in rows) {
      final f = r.student.family.trim();
      families.putIfAbsent(f.isEmpty ? '' : f, () => []).add(r);
    }
    final keys = families.keys.toList()
      ..sort(
        (a, b) => a.isEmpty
            ? 1
            : b.isEmpty
            ? -1
            : a.compareTo(b),
      );
    return [
      for (final k in keys) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  k.isEmpty ? 'بدون عائلة' : 'عائلة $k',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        for (final r in families[k]!) _tile(r, currency),
      ],
    ];
  }

  Widget _tile(_Row r, String currency) {
    final s = r.student;
    final status = r.bill.status;
    final groups = r.groups.map((g) => g.name).join('، ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentPage(studentId: s.id))),
        child: Row(
          children: [
            Avatar(s.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(
                    groups.isEmpty ? 'مش مسجل في حصة' : groups,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (status == PayStatus.unpaid || status == PayStatus.partial)
              Pill('عليه فلوس', fg: AppColors.unpaid, bg: AppColors.unpaidSoft)
            else if (status == PayStatus.paid)
              Pill('خالص', fg: AppColors.paid, bg: AppColors.paidSoft),
          ],
        ),
      ),
    );
  }

  String _filterLabel(_Filter f) {
    switch (f) {
      case _Filter.all:
        return 'الكل';
      case _Filter.unpaid:
        return 'عليهم فلوس';
      case _Filter.archived:
        return 'السابقين';
    }
  }
}

class _Row {
  _Row(this.student, this.bill, this.groups);

  final Student student;
  final Account bill;
  final List<Group> groups;
}
