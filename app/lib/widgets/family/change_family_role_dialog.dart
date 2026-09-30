import 'package:flutter/material.dart';
import '../../logic/family.dart';
import '../../logic/l10n_extension.dart';

class ChangeRoleDialog extends StatefulWidget {
  final FamilyMember member;
  final bool isOnlyParent;

  const ChangeRoleDialog({
    super.key,
    required this.member,
    required this.isOnlyParent,
  });

  static Future<FamilyRole?> show(
    BuildContext context, {
    required FamilyMember member,
    required bool isOnlyParent,
  }) {
    return showDialog<FamilyRole>(
      context: context,
      builder: (context) =>
          ChangeRoleDialog(member: member, isOnlyParent: isOnlyParent),
    );
  }

  @override
  State<ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<ChangeRoleDialog> {
  late FamilyRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.member.role;
  }

  @override
  Widget build(BuildContext context) {
    final isOnlyParent = widget.isOnlyParent;

    return AlertDialog(
      title: Text(context.l10n.changeRoleDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.changeRoleDescription(widget.member.displayName)),
          const SizedBox(height: 16),
          DropdownButtonFormField<FamilyRole>(
            key: const Key('change_role_dropdown'),
            isExpanded: true,
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
                enabled: !isOnlyParent,
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
          if (isOnlyParent) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.cannotDemoteOnlyParent,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancelButton),
        ),
        ElevatedButton(
          key: const Key('confirm_change_role_button'),
          onPressed: () {
            Navigator.pop(context, _selectedRole);
          },
          child: Text(context.l10n.saveButton),
        ),
      ],
    );
  }
}
