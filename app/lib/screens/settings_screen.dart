import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/app_state_exporter.dart';
import '../logic/error_handler.dart';
import '../logic/l10n_extension.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hoursController = TextEditingController();
  bool _isSaving = false;
  bool _isInitialized = false;
  bool _showLastSpawnedDate = false;

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings(
    UserSettingsRepository repository,
    UserSettings currentSettings,
  ) async {
    if (_formKey.currentState!.validate()) {
      final l10n = context.l10n;
      setState(() {
        _isSaving = true;
      });

      try {
        final hours = double.parse(_hoursController.text.trim());
        final updatedSettings = currentSettings.copyWith(
          hoursAvailable: hours,
          showLastSpawnedDate: _showLastSpawnedDate,
        );

        await repository
            .updateSettings(updatedSettings)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception(l10n.saveTimeoutError),
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.settingsSavedSuccessfully)),
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
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsRepository = ref.watch(userSettingsRepositoryProvider);

    if (settingsRepository == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.settingsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: StreamBuilder<UserSettings>(
        stream: settingsRepository.getSettings(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('${context.l10n.errorOccurred}: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final settings = snapshot.data!;
          if (!_isInitialized) {
            _hoursController.text = settings.hoursAvailable.toString();
            _showLastSpawnedDate = settings.showLastSpawnedDate;
            _isInitialized = true;
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule_outlined, size: 28),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.l10n.hoursAvailableLabel,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('hours_available_field'),
                          controller: _hoursController,
                          decoration: InputDecoration(
                            labelText: context.l10n.hoursAvailableLabel,
                            helperText: context.l10n.hoursAvailableHelper,
                            border: const OutlineInputBorder(),
                            suffixText: context.l10n.hoursSuffix,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.l10n.hoursAvailableValidationError;
                            }
                            final val = double.tryParse(value.trim());
                            if (val == null || val < 0 || val > 24) {
                              return context.l10n.hoursAvailableValidationError;
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: SwitchListTile(
                    key: const Key('show_last_spawned_date_switch'),
                    title: Text(context.l10n.showLastSpawnedDateLabel),
                    subtitle: Text(context.l10n.showLastSpawnedDateHelper),
                    value: _showLastSpawnedDate,
                    onChanged: (val) {
                      setState(() {
                        _showLastSpawnedDate = val;
                      });
                    },
                    secondary: const Icon(Icons.bug_report_outlined, size: 28),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bug_report_outlined, size: 28),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Debug & Diagnostics',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Export the complete local and remote app state as '
                          'structured JSON for debugging with LLMs or support.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('export_debug_state_button'),
                          onPressed: () {
                            ref
                                .read(appStateExporterProvider)
                                .shareDebugState(context);
                          },
                          icon: const Icon(Icons.ios_share),
                          label: const Text('Export Debug State (LLM JSON)'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  key: const Key('save_settings_button'),
                  onPressed: _isSaving
                      ? null
                      : () => _saveSettings(settingsRepository, settings),
                  icon: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(context.l10n.saveButton),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
