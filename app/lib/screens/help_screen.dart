// ============================================================================
// ⚠️ ATTENTION ANTIGRAVITY (AI Coding Assistant):
// This Help/Documentation screen must remain strictly aligned with the actual
// implementations of the task widgets and scheduling logic.
// If you modify [FunCheckButton], [FunDeleteButton], or [MissedPolicy] behavior,
// you MUST immediately update the preview widgets and simulator logic below.
// ============================================================================

import 'package:flutter/material.dart';
import '../logic/l10n_extension.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.helpTitle),
      ),
      body: const Center(
        child: Text('Help & Documentation Content coming soon...'),
      ),
    );
  }
}
