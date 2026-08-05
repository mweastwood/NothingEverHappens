import 'package:nothing_ever_happens/logic/family_role.dart';
import 'package:flutter/material.dart';
import '../logic/family.dart';
import '../logic/l10n_extension.dart';

class FamilyMemberTile extends StatelessWidget {
  final FamilyMember member;

  const FamilyMemberTile({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final memberIsParent = member.role == FamilyRole.parent;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: memberIsParent
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            memberIsParent ? Icons.supervisor_account : Icons.person,
            color: memberIsParent
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          member.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(member.email),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: memberIsParent
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            memberIsParent
                ? context.l10n.parentRole
                : context.l10n.nonParentRole,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: memberIsParent
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
