import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/family.dart';
import '../../logic/family_repository.dart';
import '../../logic/l10n_extension.dart';
import '../family_invite_card.dart';
import '../family_member_tile.dart';
import '../family_outstanding_invite_tile.dart';

class NoFamilyView extends ConsumerWidget {
  final VoidCallback onCreateFamily;
  final void Function(FamilyInvite invite, bool accept) onHandleInvite;

  const NoFamilyView({
    super.key,
    required this.onCreateFamily,
    required this.onHandleInvite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingInvitesAsync = ref.watch(pendingInvitesStreamProvider);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  Theme.of(
                    context,
                  ).colorScheme.secondaryContainer.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.familyScreenTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.notInFamilyBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    key: const Key('create_family_button'),
                    onPressed: onCreateFamily,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.createFamilyButton),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.pendingInvitesHeader,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        pendingInvitesAsync.when(
          error: (error, stackTrace) =>
              Text('${context.l10n.errorOccurred}: $error'),
          loading: () => const Center(child: CircularProgressIndicator()),
          data: (invites) {
            if (invites.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    context.l10n.noPendingInvites,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final invite in invites)
                  FamilyInviteCard(
                    invite: invite,
                    onAccept: () => onHandleInvite(invite, true),
                    onDecline: () => onHandleInvite(invite, false),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class FamilyMembersView extends ConsumerWidget {
  final String familyId;
  final String familyRole;
  final void Function(Family family) onInviteMember;
  final void Function(Family family, FamilyMember member) onChangeMemberRole;
  final void Function(FamilyInvite invite) onRevokeInvite;
  final void Function(String familyId) onLeaveFamily;

  const FamilyMembersView({
    super.key,
    required this.familyId,
    required this.familyRole,
    required this.onInviteMember,
    required this.onChangeMemberRole,
    required this.onRevokeInvite,
    required this.onLeaveFamily,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(familyStreamProvider(familyId));

    return familyAsync.when(
      error: (error, stackTrace) =>
          Center(child: Text('${context.l10n.errorOccurred}: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
      data: (family) {
        if (family == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.errorOccurred,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    key: const Key('leave_missing_family_button'),
                    onPressed: () => onLeaveFamily(familyId),
                    icon: const Icon(Icons.exit_to_app),
                    label: Text(context.l10n.leaveFamilyButton),
                  ),
                ],
              ),
            ),
          );
        }

        final isParent = familyRole == FamilyRole.parent.value;

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.name,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.familyMembersCount(family.members.length),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    context.l10n.membersHeader,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isParent)
                  TextButton.icon(
                    key: const Key('invite_member_button'),
                    onPressed: () => onInviteMember(family),
                    icon: const Icon(Icons.person_add),
                    label: Text(context.l10n.inviteMemberButton),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...family.members.values.map((member) {
              return FamilyMemberTile(
                member: member,
                isCurrentParent: isParent,
                onEditRole: isParent
                    ? () => onChangeMemberRole(family, member)
                    : null,
              );
            }),
            if (isParent) ...[
              const SizedBox(height: 24),
              Text(
                context.l10n.outstandingInvitesHeader,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildOutstandingInvitesList(context, ref),
            ],
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                key: const Key('leave_family_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => onLeaveFamily(family.id),
                icon: const Icon(Icons.exit_to_app),
                label: Text(context.l10n.leaveFamilyButton),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOutstandingInvitesList(BuildContext context, WidgetRef ref) {
    final outstandingAsync = ref.watch(
      outstandingInvitesStreamProvider(familyId),
    );

    return outstandingAsync.when(
      error: (error, stackTrace) =>
          Text('${context.l10n.errorOccurred}: $error'),
      loading: () => const Center(child: CircularProgressIndicator()),
      data: (invites) {
        if (invites.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Text(
                context.l10n.noOutstandingInvites,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final invite in invites)
              FamilyOutstandingInviteTile(
                invite: invite,
                onRevoke: () => onRevokeInvite(invite),
              ),
          ],
        );
      },
    );
  }
}

class PendingInvitesView extends StatelessWidget {
  final List<FamilyInvite> invites;
  final bool isFamilyPlan;
  final void Function(FamilyInvite invite, bool accept) onHandleInvite;
  final VoidCallback onCreateFamily;
  final VoidCallback onViewSubscriptions;

  const PendingInvitesView({
    super.key,
    required this.invites,
    required this.isFamilyPlan,
    required this.onHandleInvite,
    required this.onCreateFamily,
    required this.onViewSubscriptions,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          context.l10n.pendingInvitesHeader,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final invite in invites)
              FamilyInviteCard(
                invite: invite,
                onAccept: () => onHandleInvite(invite, true),
                onDecline: () => onHandleInvite(invite, false),
              ),
          ],
        ),
        if (isFamilyPlan) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            key: const Key('create_family_button'),
            onPressed: onCreateFamily,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.createFamilyButton),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('view_subscriptions_button'),
            onPressed: onViewSubscriptions,
            icon: const Icon(Icons.star_outline),
            label: const Text('View Subscriptions'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
