import 'package:flutter/material.dart';

import '../store.dart';
import 'groups_page.dart';
import 'payments_page.dart';
import 'schedule_page.dart';
import 'theme.dart';
import 'students_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [const SchedulePage(), const StudentsPage(), const GroupsPage(), const PaymentsPage()],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (store.showcase)
            Material(
              color: AppColors.partialSoft,
              child: InkWell(
                onTap: () => store.setShowcase(false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 18, color: AppColors.partial),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'وضع العرض: دي بيانات تجريبية',
                          style: TextStyle(color: AppColors.partial, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        'خروج',
                        style: TextStyle(color: AppColors.partial, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'الجدول',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'الطلاب',
              ),
              NavigationDestination(icon: Icon(Icons.class_outlined), selectedIcon: Icon(Icons.class_), label: 'الحصص'),
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments),
                label: 'الدفع',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
