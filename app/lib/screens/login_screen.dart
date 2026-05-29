import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/auth_repository.dart';
import '../logic/error_handler.dart';
import '../logic/l10n_extension.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static bool debugDisableAnimations = false;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.appName,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.pleaseSignInToContinue,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() {
                          _isLoading = true;
                        });
                        try {
                          final authRepo = Provider.of<AuthRepository>(
                            context,
                            listen: false,
                          );
                          await authRepo.signInWithGoogle();
                        } catch (e, stackTrace) {
                          if (context.mounted) {
                            final errorHandler = Provider.of<ErrorHandler>(
                              context,
                              listen: false,
                            );
                            final report = errorHandler.report(
                              e,
                              stackTrace: stackTrace,
                            );
                            errorHandler.showErrorDialog(context, report);
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      },
                icon: _isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          value: LoginScreen.debugDisableAnimations
                              ? 0.8
                              : null,
                          strokeWidth: 2.0,
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  _isLoading
                      ? context.l10n.signingIn
                      : context.l10n.signInWithGoogle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
