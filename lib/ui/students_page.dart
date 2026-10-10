import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'payment_sheet.dart';
import 'student_form.dart';
import 'student_page.dart';
import 'theme.dart';

enum _Filter { all, paid, unpaid, review, archived }

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _Filter _filter = _Filter.all;
  bool _byFamily = false;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.data;
    final now = DateTime.now();
    final month = monthKey(_month);
    final currency = d.settings.currency;

    final rows = <_Row>[];
    for (final s in d.students) {
      if (_filter == _Filter.archived ? !s.archived : s.archived) continue;
      rows.add(_Row(s, d.billFor(s, month, now), d.groupsOf(s)));
    }
    final billed = rows.where((r) => r.bill.status != PayStatus.none && !r.student.archived).toList();
    final paidCount = billed.where((r) => r.bill.status == PayStatus.paid).length;
    final unpaidCount = billed.length - paidCount;
    final totalDue = billed.fold<double>(0, (a, r) => a + (r.bill.totalDue < 0 ? 0 : r.bill.totalDue));
    final totalPaid = rows.fold<double>(0, (a, r) => a + r.bill.paid);

    var shown = rows.where((r) {
      if (_q.isNotEmpty && !r.student.name.contains(_q) && !r.student.family.contains(_q)) return false;
      switch (_filter) {
        case _Filter.paid:
          return r.bill.status == PayStatus.paid;
        case _Filter.unpaid:
          return r.bill.status == PayStatus.unpaid || r.bill.status == PayStatus.partial;
        case _Filter.review:
          return r.groups.any((g) => g.kind == GroupKind.review);
        case _Filter.all:
        case _Filter.archived:
          return true;
      }
    }).toList();
    shown.sort((a, b) => a.student.name.compareTo(b.student.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلاب'),
        actions: [
          IconButton(
            tooltip: 'الشهر السابق',
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(monthName(_month, withYear: true), style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            tooltip: 'الشهر التالي',
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => openStudentForm(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('طالب جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Stat(label: 'دفعوا', value: arNum(paidCount), color: AppColors.paid),
                    ),
                    Expanded(
                      child: _Stat(label: 'لسه', value: arNum(unpaidCount), color: AppColors.unpaid),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: totalDue <= 0 ? 0 : (totalPaid / totalDue).clamp(0, 1).toDouble(),
                    minHeight: 10,
                    backgroundColor: AppColors.unpaidSoft,
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'المحصّل ${fmtMoney(totalPaid, currency)} من ${fmtMoney(totalDue, currency)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                      labelStyle: TextStyle(color: _filter == f ? Colors.white : AppColors.ink, fontFamily: 'Plex'),
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
            ..._familySections(shown, currency, month)
          else
            for (final r in shown) _tile(r, currency, month),
        ],
      ),
    );
  }

  List<Widget> _familySections(List<_Row> rows, String currency, String month) {
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
              if (k.isNotEmpty)
                Text(
                  'الباقي ${fmtMoney(families[k]!.fold<double>(0, (a, r) => a + r.bill.remaining), currency)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
            ],
          ),
        ),
        for (final r in families[k]!) _tile(r, currency, month),
      ],
    ];
  }

  Widget _tile(_Row r, String currency, String month) {
    final s = r.student;
    final status = r.bill.status;
    final groups = r.groups.map((g) => g.name).join('، ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentPage(studentId: s.id))),
        onLongPress: () => showStudentActions(context, s),
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
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  if (status == PayStatus.partial || status == PayStatus.unpaid)
                    Text(
                      'الباقي ${fmtMoney(r.bill.remaining, currency)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.unpaid),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (status == PayStatus.unpaid || status == PayStatus.partial)
              TextButton(
                onPressed: () => showPaymentSheet(context, s, month),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.unpaidSoft,
                  foregroundColor: AppColors.unpaid,
                  minimumSize: const Size(44, 38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('تسجيل الدفع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              )
            else
              StatusPill(status),
          ],
        ),
      ),
    );
  }

  String _filterLabel(_Filter f) {
    switch (f) {
      case _Filter.all:
        return 'الكل';
      case _Filter.paid:
        return 'دفعوا';
      case _Filter.unpaid:
        return 'لسه';
      case _Filter.review:
        return 'مراجعة';
      case _Filter.archived:
        return 'السابقين';
    }
  }
}

class _Row {
  _Row(this.student, this.bill, this.groups);

  final Student student;
  final MonthBill bill;
  final List<Group> groups;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
