import 'dart:async';
import 'package:flutter/material.dart';
import '../../logic/recipes/recipe.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  final int servings;
  final VoidCallback? onCompleteCooking;

  const CookingModeScreen({
    super.key,
    required this.recipe,
    this.servings = 4,
    this.onCompleteCooking,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingStepItem {
  final String stage; // 'Prep' or 'Cook'
  final int stepNumber;
  final String instruction;
  final int durationSeconds;

  const _CookingStepItem({
    required this.stage,
    required this.stepNumber,
    required this.instruction,
    required this.durationSeconds,
  });
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  final List<_CookingStepItem> _allSteps = [];
  int _currentStepIndex = 0;

  Timer? _timer;
  int _secondsRemaining = 0;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    for (final s in widget.recipe.prepSteps) {
      _allSteps.add(
        _CookingStepItem(
          stage: 'Prep',
          stepNumber: s.stepNumber,
          instruction: s.instruction,
          durationSeconds: s.timerDurationSeconds > 0
              ? s.timerDurationSeconds
              : s.estimatedMinutes * 60,
        ),
      );
    }
    for (final s in widget.recipe.cookSteps) {
      _allSteps.add(
        _CookingStepItem(
          stage: 'Cook',
          stepNumber: s.stepNumber,
          instruction: s.instruction,
          durationSeconds: s.timerDurationSeconds > 0
              ? s.timerDurationSeconds
              : s.estimatedMinutes * 60,
        ),
      );
    }

    _loadStepTimer();
  }

  void _loadStepTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
    if (_allSteps.isNotEmpty && _currentStepIndex < _allSteps.length) {
      _secondsRemaining = _allSteps[_currentStepIndex].durationSeconds;
    } else {
      _secondsRemaining = 0;
    }
  }

  void _toggleTimer() {
    if (_isTimerRunning) {
      _timer?.cancel();
      setState(() => _isTimerRunning = false);
    } else {
      if (_secondsRemaining <= 0) {
        _secondsRemaining = _allSteps[_currentStepIndex].durationSeconds > 0
            ? _allSteps[_currentStepIndex].durationSeconds
            : 300; // Default 5 mins if 0
      }
      setState(() => _isTimerRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
        } else {
          _timer?.cancel();
          setState(() => _isTimerRunning = false);
          _showTimerFinishedDialog();
        }
      });
    }
  }

  void _addMinutes(int mins) {
    setState(() {
      _secondsRemaining += mins * 60;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _secondsRemaining = _allSteps[_currentStepIndex].durationSeconds;
    });
  }

  void _showTimerFinishedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.alarm_on, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Timer Finished!'),
          ],
        ),
        content: Text(
          'Step ${_currentStepIndex + 1} timer is done: "${_allSteps[_currentStepIndex].instruction}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          if (_currentStepIndex < _allSteps.length - 1)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _nextStep();
              },
              child: const Text('Next Step'),
            ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStepIndex < _allSteps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _loadStepTimer();
      });
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
        _loadStepTimer();
      });
    }
  }

  String _formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_allSteps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.recipe.title)),
        body: const Center(
          child: Text('This recipe has no instructions added yet.'),
        ),
      );
    }

    final step = _allSteps[_currentStepIndex];
    final progress = (_currentStepIndex + 1) / _allSteps.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.recipe.title, style: const TextStyle(fontSize: 18)),
            Text(
              'Cooking Mode (${widget.servings} Servings)',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              widget.onCompleteCooking?.call();
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.done_all, color: Colors.greenAccent),
            label: const Text(
              'Finish',
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: progress),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(
                    avatar: Icon(
                      step.stage == 'Prep'
                          ? Icons.kitchen
                          : Icons.outdoor_grill,
                      size: 16,
                    ),
                    label: Text('${step.stage} Phase'),
                  ),
                  Text(
                    'Step ${_currentStepIndex + 1} of ${_allSteps.length}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              'Step ${step.stepNumber}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              step.instruction,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Step Timer Card
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            Text(
                              _formatSeconds(_secondsRemaining),
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _resetTimer,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reset'),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: _toggleTimer,
                                  icon: Icon(
                                    _isTimerRunning
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                  label: Text(
                                    _isTimerRunning ? 'Pause' : 'Start',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () => _addMinutes(1),
                                  child: const Text('+1 min'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom navigation controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _currentStepIndex > 0 ? _prevStep : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                  ),
                  const Spacer(),
                  if (_currentStepIndex < _allSteps.length - 1)
                    FilledButton.icon(
                      onPressed: _nextStep,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next Step'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () {
                        widget.onCompleteCooking?.call();
                        Navigator.pop(context, true);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Finish Cooking'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
