import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'group_form.dart';
import 'theme.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final d = StoreScope.of(context).data;
    final active = d.groups.where((g) => !g.archived).toList()..sort((a, b) => a.name.compareTo(b.name));
    final archived = d.groups.where((g) => g.archived).toList();
    final sections = [
      ('المجموعات', active.where((g) => g.kind == GroupKind.group).toList()),
      ('الحصص الفردية', active.where((g) => g.kind == GroupKind.individual).toList()),
      ('المراجعة', active.where((g) => g.kind == GroupKind.review).toList()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('الحصص والمجموعات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openGroupForm(context),
        icon: const Icon(Icons.add),
        label: const Text('حصة جديدة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (d.groups.isEmpty)
            EmptyState(
              icon: Icons.class_outlined,
              text: 'لسه مفيش حصص.\nالحصة ممكن تكون فردية لطالب واحد، أو مجموعة، أو مراجعة قبل الامتحان.',
              action: FilledButton.icon(
                onPressed: () => openGroupForm(context),
                icon: const Icon(Icons.add),
                label: const Text('إضافة حصة'),
              ),
            ),
          for (final (title, list) in sections)
            if (list.isNotEmpty) ...[
              SectionTitle('$title (${arNum(list.length)})'),
              for (final g in list) _GroupTile(group: g),
              const SizedBox(height: 8),
            ],
          if (archived.isNotEmpty) ...[
            TextButton.icon(
              onPressed: () => setState(() => _showArchived = !_showArchived),
              icon: Icon(_showArchived ? Icons.expand_less : Icons.expand_more),
              label: Text('الحصص السابقة (${arNum(archived.length)})'),
            ),
            if (_showArchived) for (final g in archived) _GroupTile(group: g),
          ],
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final d = StoreScope.of(context).data;
    final g = group;
    final members = d.studentsOf(g);
    final currency = d.settings.currency;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        onTap: () => openGroupForm(context, group: g),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(g.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            KindPill(g),
          ]),
          const SizedBox(height: 4),
          Text(scheduleSummary(g), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.people_outline, size: 16, color: AppColors.muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                members.isEmpty ? 'بدون طلاب' : members.map((s) => s.name).join('، '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${fmtMoney(g.currentPrice, currency)} ${g.payType == PayType.perLesson ? '/ حصة' : '/ شهر'}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ]),
        ]),
      ),
    );
  }
}
