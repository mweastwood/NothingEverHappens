import 'package:flutter/material.dart';
import '../logic/family.dart';
import '../logic/l10n_extension.dart';

class FamilyInviteCard extends StatelessWidget {
  final FamilyInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const FamilyInviteCard({
    super.key,
    required this.invite,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    invite.familyName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    invite.role == FamilyRole.parent
                        ? context.l10n.parentRole
                        : context.l10n.nonParentRole,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.invitedBy(invite.fromName, invite.fromEmail),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: Key('decline_invite_${invite.id}'),
                  onPressed: onDecline,
                  child: Text(
                    context.l10n.declineInviteButton,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  key: Key('accept_invite_${invite.id}'),
                  onPressed: onAccept,
                  child: Text(context.l10n.acceptInviteButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
