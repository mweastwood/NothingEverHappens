import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/family.dart';
import '../logic/family_repository.dart';
import '../logic/error_handler.dart';
import '../logic/l10n_extension.dart';
import '../widgets/subscription_paywall_widget.dart';
import '../widgets/app_snackbar.dart';
import '../logic/subscription_service.dart';
import '../widgets/family/create_family_dialog.dart';
import '../widgets/family/invite_member_dialog.dart';
import '../widgets/family/change_family_role_dialog.dart';
import '../widgets/family/family_screen_sections.dart';
import 'subscription_screen.dart';

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  bool _isProcessing = false;

  void _navigateToSubscriptions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
    );
  }

  Future<void> _runProcessingAction(
    Future<void> Function() action, {
    String? Function()? successMessage,
  }) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      await action();
      if (mounted && successMessage != null) {
        final msg = successMessage();
        if (msg != null) {
          AppSnackBar.show(context, content: Text(msg));
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        final errorHandler = ref.read(errorHandlerProvider);
        final report = errorHandler.report(e, stackTrace: stackTrace);
        errorHandler.showErrorDialog(context, report);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool?> _showDestructiveConfirmDialog({
    required String title,
    required String content,
    required Key confirmButtonKey,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancelButton),
          ),
          ElevatedButton(
            key: confirmButtonKey,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _createFamily(FamilyRepository repository) async {
    final name = await CreateFamilyDialog.show(context);
    if (name != null && mounted) {
      await _runProcessingAction(() => repository.createFamily(name));
    }
  }

  Future<void> _inviteMember(FamilyRepository repository, Family family) async {
    final result = await InviteMemberDialog.show(context);
    if (result != null && mounted) {
      await _runProcessingAction(
        () => repository.inviteMember(
          familyId: family.id,
          familyName: family.name,
          toEmail: result.email,
          role: result.role,
        ),
        successMessage: () => context.l10n.inviteSentSuccess,
      );
    }
  }

  Future<void> _leaveFamily(
    FamilyRepository repository,
    String familyId,
  ) async {
    final confirm = await _showDestructiveConfirmDialog(
      title: context.l10n.leaveFamilyConfirmTitle,
      content: context.l10n.leaveFamilyConfirmBody,
      confirmButtonKey: const Key('confirm_leave_family_button'),
      confirmLabel: context.l10n.leaveFamilyButton,
    );

    if (confirm == true && mounted) {
      await _runProcessingAction(() => repository.leaveFamily(familyId));
    }
  }

  Future<void> _handleInvite(
    FamilyRepository repository,
    FamilyInvite invite,
    bool accept,
  ) {
    return _runProcessingAction(
      () => accept
          ? repository.acceptInvite(invite)
          : repository.declineInvite(invite),
    );
  }

  Future<void> _revokeInvite(
    FamilyRepository repository,
    FamilyInvite invite,
  ) async {
    final confirm = await _showDestructiveConfirmDialog(
      title: context.l10n.revokeInviteConfirmTitle,
      content: context.l10n.revokeInviteConfirmBody(invite.toEmail),
      confirmButtonKey: const Key('confirm_revoke_invite_button'),
      confirmLabel: context.l10n.revokeInviteButton,
    );

    if (confirm == true && mounted) {
      await _runProcessingAction(
        () => repository.revokeInvite(invite.id),
        successMessage: () => context.l10n.inviteRevokedSuccess,
      );
    }
  }

  Future<void> _changeMemberRole(
    FamilyRepository repository,
    Family family,
    FamilyMember member,
  ) async {
    final parentCount = family.members.values
        .where((m) => m.role == FamilyRole.parent)
        .length;
    final isOnlyParent = member.role == FamilyRole.parent && parentCount <= 1;

    final newRole = await ChangeRoleDialog.show(
      context,
      member: member,
      isOnlyParent: isOnlyParent,
    );

    if (newRole != null && newRole != member.role && mounted) {
      await _runProcessingAction(
        () => repository.updateMemberRole(
          familyId: family.id,
          memberUserId: member.userId,
          newRole: newRole,
        ),
        successMessage: () =>
            context.l10n.roleUpdatedSuccess(member.displayName),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionServiceProvider);
    final priceAsync = ref.watch(familyPlanPriceProvider);
    final priceString = priceAsync.value;
    final familyRepo = ref.watch(familyRepositoryProvider);

    if (familyRepo == null) {
      if (!subscription.isFamilyPlan) {
        return SubscriptionPaywallWidget(
          isProcessing: _isProcessing,
          onUpgrade: () => _navigateToSubscriptions(context),
          priceString: priceString,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (_isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }

    final profileAsync = ref.watch(familyProfileStreamProvider);

    return profileAsync.when(
      error: (error, stackTrace) =>
          Center(child: Text('${context.l10n.errorOccurred}: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
      data: (profile) {
        final familyId = profile?.familyId ?? '';
        final familyRole = profile?.familyRole ?? '';

        if (familyId.isNotEmpty) {
          return FamilyMembersView(
            familyId: familyId,
            familyRole: familyRole,
            onInviteMember: (family) => _inviteMember(familyRepo, family),
            onChangeMemberRole: (family, member) =>
                _changeMemberRole(familyRepo, family, member),
            onRevokeInvite: (invite) => _revokeInvite(familyRepo, invite),
            onLeaveFamily: (id) => _leaveFamily(familyRepo, id),
          );
        }

        if (subscription.isFamilyPlan) {
          return NoFamilyView(
            onCreateFamily: () => _createFamily(familyRepo),
            onHandleInvite: (invite, accept) =>
                _handleInvite(familyRepo, invite, accept),
          );
        }

        final invitesAsync = ref.watch(pendingInvitesStreamProvider);

        return invitesAsync.when(
          error: (error, stackTrace) =>
              Center(child: Text('${context.l10n.errorOccurred}: $error')),
          loading: () => const Center(child: CircularProgressIndicator()),
          data: (invites) {
            if (invites.isNotEmpty) {
              return PendingInvitesView(
                invites: invites,
                isFamilyPlan: false,
                onHandleInvite: (invite, accept) =>
                    _handleInvite(familyRepo, invite, accept),
                onCreateFamily: () => _createFamily(familyRepo),
                onViewSubscriptions: () => _navigateToSubscriptions(context),
              );
            }

            return SubscriptionPaywallWidget(
              isProcessing: _isProcessing,
              onUpgrade: () => _navigateToSubscriptions(context),
              priceString: priceString,
            );
          },
        );
      },
    );
  }
}
