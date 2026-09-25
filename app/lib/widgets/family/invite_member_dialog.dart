import 'package:flutter/material.dart';
import '../../logic/family.dart';
import '../../logic/l10n_extension.dart';

class InviteMemberResult {
  final String email;
  final FamilyRole role;

  const InviteMemberResult({required this.email, required this.role});

  dynamic operator [](String key) {
    if (key == 'email') return email;
    if (key == 'role') return role;
    return null;
  }

  Map<String, dynamic> toMap() => {'email': email, 'role': role};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InviteMemberResult &&
          runtimeType == other.runtimeType &&
          email == other.email &&
          role == other.role;

  @override
  int get hashCode => email.hashCode ^ role.hashCode;

  @override
  String toString() => 'InviteMemberResult(email: $email, role: $role)';
}

class InviteMemberDialog extends StatefulWidget {
  const InviteMemberDialog({super.key});

  static Future<InviteMemberResult?> show(BuildContext context) {
    return showDialog<InviteMemberResult>(
      context: context,
      builder: (context) => const InviteMemberDialog(),
    );
  }

  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  FamilyRole _selectedRole = FamilyRole.nonParent;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.inviteMemberTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('invite_email_field'),
              controller: _emailController,
              decoration: InputDecoration(
                labelText: context.l10n.inviteMemberEmailLabel,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.emailRequiredError;
                }
                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return context.l10n.emailInvalidError;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FamilyRole>(
              key: const Key('invite_role_dropdown'),
              initialValue: _selectedRole,
              decoration: InputDecoration(
                labelText: context.l10n.inviteMemberRoleLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: FamilyRole.parent,
                  child: Text(context.l10n.parentRole),
                ),
                DropdownMenuItem(
                  value: FamilyRole.nonParent,
                  child: Text(context.l10n.nonParentRole),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedRole = val;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancelButton),
        ),
        ElevatedButton(
          key: const Key('confirm_invite_button'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                InviteMemberResult(
                  email: _emailController.text.trim(),
                  role: _selectedRole,
                ),
              );
            }
          },
          child: Text(context.l10n.saveButton),
        ),
      ],
    );
  }
}
