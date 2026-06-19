import 'package:flutter/material.dart';
import '../logic/l10n_extension.dart';
import '../widgets/basic_task_completion_tab.dart';
import '../widgets/scheduling_playground_tab.dart';
import '../widgets/missed_policies_playground_tab.dart';

class HelpScreen extends StatefulWidget {
  final int initialIndex;
  const HelpScreen({super.key, this.initialIndex = 0});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _resetCounter = 0;

  TabController get tabController => _tabController;
  int get resetCounter => _resetCounter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _resetCounter++;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.helpTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.helpTabInteractions),
            Tab(text: context.l10n.helpTabScheduling),
            Tab(text: context.l10n.helpTabMissedPolicies),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          BasicTaskCompletionTab(
            key: ValueKey('basic_task_tab_$_resetCounter'),
          ),
          const SchedulingPlaygroundTab(
            key: ValueKey('scheduling_playground_tab'),
          ),
          MissedPoliciesPlaygroundTab(
            key: ValueKey('missed_policies_tab_$_resetCounter'),
          ),
        ],
      ),
    );
  }
}
