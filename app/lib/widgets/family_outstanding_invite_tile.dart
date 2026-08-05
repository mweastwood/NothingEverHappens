import 'package:nothing_ever_happens/logic/family_role.dart';
import 'package:flutter/material.dart';
import '../logic/family.dart';
import '../logic/l10n_extension.dart';

class FamilyOutstandingInviteTile extends StatelessWidget {
  final FamilyInvite invite;
  final VoidCallback onRevoke;

  const FamilyOutstandingInviteTile({
    super.key,
    required this.invite,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final inviteIsParent = invite.role == FamilyRole.parent;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.mail_outline,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          invite.toEmail,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          inviteIsParent ? context.l10n.parentRole : context.l10n.nonParentRole,
        ),
        trailing: TextButton(
          key: Key('revoke_invite_${invite.id}'),
          onPressed: onRevoke,
          child: Text(
            context.l10n.revokeInviteButton,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
