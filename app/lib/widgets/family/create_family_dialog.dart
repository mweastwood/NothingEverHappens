import 'package:flutter/material.dart';
import '../../logic/l10n_extension.dart';

class CreateFamilyDialog extends StatefulWidget {
  const CreateFamilyDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => const CreateFamilyDialog(),
    );
  }

  @override
  State<CreateFamilyDialog> createState() => _CreateFamilyDialogState();
}

class _CreateFamilyDialogState extends State<CreateFamilyDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.createFamilyTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('family_name_field'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: context.l10n.familyUnitNameLabel,
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.l10n.familyNameRequiredError;
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancelButton),
        ),
        ElevatedButton(
          key: const Key('confirm_create_family_button'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: Text(context.l10n.saveButton),
        ),
      ],
    );
  }
}
