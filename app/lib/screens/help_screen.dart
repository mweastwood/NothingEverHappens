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
        child: Text('Help Content coming soon...'),
      ),
    );
  }
}
