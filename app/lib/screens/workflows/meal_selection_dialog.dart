import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/recipes/recipe.dart';
import '../../logic/recipes/recipe_repository.dart';
import '../../logic/task_instance.dart';
import '../../logic/task_schedule.dart';
import '../../logic/task_repository.dart';
import '../../logic/workflows/meal_workflow_engine.dart';
import '../recipes/recipe_editor_screen.dart';

class MealSelectionDialog extends ConsumerStatefulWidget {
  final TaskInstance instance;
  final TaskSchedule? schedule;

  const MealSelectionDialog({super.key, required this.instance, this.schedule});

  @override
  ConsumerState<MealSelectionDialog> createState() =>
      _MealSelectionDialogState();
}

class _MealSelectionDialogState extends ConsumerState<MealSelectionDialog> {
  MealSelectionOption _selectedOption = MealSelectionOption.recipe;
  Recipe? _chosenRecipe;
  int _targetServings = 4;
  final _noteController = TextEditingController();
  String _recipeSearch = '';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _confirmSelection() async {
    final schedule =
        widget.schedule ??
        TaskSchedule(
          id: widget.instance.scheduleId,
          title: widget.instance.title,
          description: widget.instance.description,
          workflowType: 'mealWorkflow',
        );

    final results = MealWorkflowEngine.processMealSelection(
      schedule: schedule,
      selectInstance: widget.instance,
      selectedOption: _selectedOption,
      recipe: _chosenRecipe,
      targetServings: _targetServings,
      customNote: _noteController.text.trim(),
    );

    final repo = ref.read(taskRepositoryProvider);
    if (repo != null) {
      for (final inst in results) {
        await repo.saveTaskInstance(inst);
      }
      // Mark current Stage 1 task as completed
      await repo.completeTaskInstance(widget.instance.id);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(recipesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan Today\'s Dinner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'What would you like to have for dinner?',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Option cards
          RadioGroup<MealSelectionOption>(
            groupValue: _selectedOption,
            onChanged: (opt) {
              if (opt != null) {
                setState(() => _selectedOption = opt);
              }
            },
            child: Column(
              children: [
                _buildOptionTile(
                  option: MealSelectionOption.recipe,
                  icon: Icons.restaurant_menu,
                  title: 'Cook a Recipe',
                  subtitle: 'Pick a meal from your recipe library',
                ),
                _buildOptionTile(
                  option: MealSelectionOption.leftovers,
                  icon: Icons.inventory_2_outlined,
                  title: 'Leftovers',
                  subtitle: 'Reheat meals already in the fridge',
                ),
                _buildOptionTile(
                  option: MealSelectionOption.delivery,
                  icon: Icons.delivery_dining,
                  title: 'Order Delivery',
                  subtitle: 'Order dinner from a restaurant or app',
                ),
                _buildOptionTile(
                  option: MealSelectionOption.eatingOut,
                  icon: Icons.storefront,
                  title: 'Eating Out',
                  subtitle: 'Dining out at a restaurant tonight',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Conditional selection content
          if (_selectedOption == MealSelectionOption.recipe) ...[
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Select Recipe', style: theme.textTheme.titleLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final newRecipe = await Navigator.push<Recipe>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecipeEditorScreen(),
                      ),
                    );
                    if (newRecipe != null && mounted) {
                      setState(() {
                        _chosenRecipe = newRecipe;
                        _targetServings = newRecipe.servings;
                      });
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Recipe'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search recipes...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) => setState(() => _recipeSearch = val),
            ),
            const SizedBox(height: 12),
            recipesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
              data: (recipes) {
                var filtered = recipes;
                if (_recipeSearch.trim().isNotEmpty) {
                  final q = _recipeSearch.toLowerCase();
                  filtered = filtered
                      .where((r) => r.title.toLowerCase().contains(q))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No recipes found in your library.'),
                    ),
                  );
                }

                return RadioGroup<String>(
                  groupValue: _chosenRecipe?.id,
                  onChanged: (id) {
                    if (id != null) {
                      final found = recipes
                          .where((r) => r.id == id)
                          .firstOrNull;
                      if (found != null) {
                        setState(() {
                          _chosenRecipe = found;
                          _targetServings = found.servings > 0
                              ? found.servings
                              : 4;
                        });
                      }
                    }
                  },
                  child: Column(
                    children: filtered.map((r) {
                      final isSelected = _chosenRecipe?.id == r.id;
                      return Card(
                        color: isSelected
                            ? theme.colorScheme.primaryContainer
                            : null,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Radio<String>(value: r.id),
                          title: Text(
                            r.title,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${r.servings} servings • ${r.ingredients.length} ingredients • ${r.totalMinutes} min',
                          ),
                          onTap: () {
                            setState(() {
                              _chosenRecipe = r;
                              _targetServings = r.servings > 0 ? r.servings : 4;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            if (_chosenRecipe != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline),
                      const SizedBox(width: 12),
                      Text(
                        'Target Servings:',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _targetServings > 1
                            ? () => setState(() => _targetServings--)
                            : null,
                      ),
                      Text(
                        '$_targetServings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => _targetServings++),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else if (_selectedOption == MealSelectionOption.leftovers ||
              _selectedOption == MealSelectionOption.delivery) ...[
            const Divider(),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: _selectedOption == MealSelectionOption.leftovers
                    ? 'What leftovers are we having?'
                    : 'Where are we ordering from?',
                hintText: _selectedOption == MealSelectionOption.leftovers
                    ? 'e.g. Pasta from Tuesday'
                    : 'e.g. Thai Palace or Uber Eats',
                border: const OutlineInputBorder(),
              ),
            ),
          ],

          const SizedBox(height: 32),
          FilledButton(
            key: const Key('confirm_meal_selection_button'),
            onPressed:
                (_selectedOption == MealSelectionOption.recipe &&
                    _chosenRecipe == null)
                ? null
                : _confirmSelection,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Confirm Dinner Choice'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required MealSelectionOption option,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedOption == option;
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 3 : 1,
      color: isSelected ? theme.colorScheme.secondaryContainer : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedOption = option),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.onSecondaryContainer
                            : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onSecondaryContainer
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<MealSelectionOption>(value: option),
            ],
          ),
        ),
      ),
    );
  }
}
