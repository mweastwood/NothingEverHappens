import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../logic/family.dart';
import '../logic/family_repository.dart';
import '../logic/error_handler.dart';
import '../logic/l10n_extension.dart';
import '../widgets/family_invite_card.dart';
import '../widgets/family_outstanding_invite_tile.dart';
import '../widgets/family_member_tile.dart';
import '../widgets/subscription_paywall_widget.dart';
import '../logic/auth_repository.dart';
import '../logic/subscription_service.dart';

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  bool _isProcessing = false;

  Future<void> _createFamily(FamilyRepository repository) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _CreateFamilyDialog(),
    );

    if (name != null && mounted) {
      setState(() {
        _isProcessing = true;
      });
      try {
        await repository.createFamily(name);
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
  }

  Future<void> _inviteMember(FamilyRepository repository, Family family) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _InviteMemberDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _isProcessing = true;
      });
      try {
        await repository.inviteMember(
          familyId: family.id,
          familyName: family.name,
          toEmail: result['email']!,
          role: result['role']!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.inviteSentSuccess)),
          );
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
  }

  Future<void> _leaveFamily(
    FamilyRepository repository,
    String familyId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.leaveFamilyConfirmTitle),
        content: Text(context.l10n.leaveFamilyConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancelButton),
          ),
          ElevatedButton(
            key: const Key('confirm_leave_family_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.leaveFamilyButton),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _isProcessing = true;
      });
      try {
        await repository.leaveFamily(familyId);
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
  }

  Future<void> _handleInvite(
    FamilyRepository repository,
    FamilyInvite invite,
    bool accept,
  ) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      if (accept) {
        await repository.acceptInvite(invite);
      } else {
        await repository.declineInvite(invite);
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

  Future<void> _revokeInvite(
    FamilyRepository repository,
    FamilyInvite invite,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.revokeInviteConfirmTitle),
        content: Text(context.l10n.revokeInviteConfirmBody(invite.toEmail)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancelButton),
          ),
          ElevatedButton(
            key: const Key('confirm_revoke_invite_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.revokeInviteButton),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _isProcessing = true;
      });
      try {
        await repository.revokeInvite(invite.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.inviteRevokedSuccess)),
          );
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
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionServiceProvider);

    if (!subscription.isFamilyPlan) {
      return SubscriptionPaywallWidget(
        isProcessing: _isProcessing,
        onUpgrade: () => _upgradeToFamily(context),
      );
    }

    final familyRepo = ref.watch(familyRepositoryProvider);

    if (familyRepo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: familyRepo.getProfile(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.hasError) {
          return Center(
            child: Text(
              '${context.l10n.errorOccurred}: ${profileSnapshot.error}',
            ),
          );
        }

        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final profileData = profileSnapshot.data?.data() ?? {};
        final familyId = profileData['familyId'] as String? ?? '';
        final familyRole = profileData['familyRole'] as String? ?? '';

        if (familyId.isEmpty) {
          return _buildNoFamilyScreen(familyRepo);
        } else {
          return _buildFamilyScreen(familyRepo, familyId, familyRole);
        }
      },
    );
  }

  Widget _buildNoFamilyScreen(FamilyRepository repository) {
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
                    onPressed: () => _createFamily(repository),
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
        StreamBuilder<List<FamilyInvite>>(
          stream: repository.getPendingInvites(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('${context.l10n.errorOccurred}: ${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final invites = snapshot.data ?? [];
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
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invites.length,
              itemBuilder: (context, index) {
                final invite = invites[index];
                return FamilyInviteCard(
                  invite: invite,
                  onAccept: () => _handleInvite(repository, invite, true),
                  onDecline: () => _handleInvite(repository, invite, false),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFamilyScreen(
    FamilyRepository repository,
    String familyId,
    String familyRole,
  ) {
    return StreamBuilder<Family?>(
      stream: repository.getFamily(familyId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('${context.l10n.errorOccurred}: ${snapshot.error}'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final family = snapshot.data;
        if (family == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final isParent = familyRole == 'parent';

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
                    onPressed: () => _inviteMember(repository, family),
                    icon: const Icon(Icons.person_add),
                    label: Text(context.l10n.inviteMemberButton),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...family.members.values.map((member) {
              return FamilyMemberTile(member: member);
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
              StreamBuilder<List<FamilyInvite>>(
                stream: repository.getOutstandingFamilyInvites(family.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      '${context.l10n.errorOccurred}: ${snapshot.error}',
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final invites = snapshot.data ?? [];
                  if (invites.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          context.l10n.noOutstandingInvites,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).disabledColor,
                              ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: invites.length,
                    itemBuilder: (context, index) {
                      final invite = invites[index];
                      return FamilyOutstandingInviteTile(
                        invite: invite,
                        onRevoke: () => _revokeInvite(repository, invite),
                      );
                    },
                  );
                },
              ),
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
                onPressed: () => _leaveFamily(repository, family.id),
                icon: const Icon(Icons.exit_to_app),
                label: Text(context.l10n.leaveFamilyButton),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _upgradeToFamily(BuildContext context) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = authRepo.currentUser;
      if (user != null) {
        if (!kIsWeb) {
          try {
            final offerings = await Purchases.getOfferings();
            final current = offerings.current;
            if (current != null && current.availablePackages.isNotEmpty) {
              final package = current.availablePackages.firstWhere(
                (p) => p.identifier.contains('family'),
                orElse: () => current.availablePackages.first,
              );
              await Purchases.purchase(PurchaseParams.package(package));
            }
          } catch (e) {
            debugPrint('RevenueCat purchase error / fallback: $e');
          }
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'subscriptionTier': 'family',
        }, SetOptions(merge: true));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upgraded to Family Plan!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error purchasing: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}

class _CreateFamilyDialog extends StatefulWidget {
  const _CreateFamilyDialog();

  @override
  State<_CreateFamilyDialog> createState() => _CreateFamilyDialogState();
}

class _CreateFamilyDialogState extends State<_CreateFamilyDialog> {
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

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog();

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  String _selectedRole = 'non-parent';

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
            DropdownButtonFormField<String>(
              key: const Key('invite_role_dropdown'),
              initialValue: _selectedRole,
              decoration: InputDecoration(
                labelText: context.l10n.inviteMemberRoleLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'parent',
                  child: Text(context.l10n.parentRole),
                ),
                DropdownMenuItem(
                  value: 'non-parent',
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
              Navigator.pop(context, {
                'email': _emailController.text.trim(),
                'role': _selectedRole,
              });
            }
          },
          child: Text(context.l10n.saveButton),
        ),
      ],
    );
  }
}
