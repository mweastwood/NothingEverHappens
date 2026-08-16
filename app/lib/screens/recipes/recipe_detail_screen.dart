import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/recipes/recipe.dart';
import '../../logic/recipes/unit_converter.dart';
import '../../logic/recipes/recipe_repository.dart';
import 'cooking_mode_screen.dart';
import 'recipe_editor_screen.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  late Recipe _recipe;
  late int _servings;
  UnitSystem _unitSystem = UnitSystem.imperial;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _servings = _recipe.servings > 0 ? _recipe.servings : 4;
  }

  Future<void> _editRecipe() async {
    final updated = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeEditorScreen(recipeToEdit: _recipe),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _recipe = updated;
        _servings = updated.servings;
      });
    }
  }

  Future<void> _deleteRecipe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe?'),
        content: Text('Are you sure you want to delete "${_recipe.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(recipeRepositoryProvider).deleteRecipe(_recipe.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_recipe.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editRecipe,
            tooltip: 'Edit Recipe',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteRecipe,
            tooltip: 'Delete Recipe',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_recipe.description.isNotEmpty) ...[
            Text(
              _recipe.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Quick stats & controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        icon: Icons.timer_outlined,
                        label: 'Prep Time',
                        value: '${_recipe.totalPrepMinutes} min',
                        theme: theme,
                      ),
                      _buildStatColumn(
                        icon: Icons.outdoor_grill_outlined,
                        label: 'Cook Time',
                        value: '${_recipe.totalCookMinutes} min',
                        theme: theme,
                      ),
                      _buildStatColumn(
                        icon: Icons.restaurant,
                        label: 'Total Time',
                        value: '${_recipe.totalMinutes} min',
                        theme: theme,
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.people_outline),
                      const SizedBox(width: 8),
                      Text('Servings:', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _servings > 1
                            ? () => setState(() => _servings--)
                            : null,
                      ),
                      Text(
                        '$_servings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => _servings++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz),
                      const SizedBox(width: 8),
                      Text('Unit System:', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      SegmentedButton<UnitSystem>(
                        segments: const [
                          ButtonSegment(
                            value: UnitSystem.imperial,
                            label: Text('Imperial'),
                          ),
                          ButtonSegment(
                            value: UnitSystem.metric,
                            label: Text('Metric'),
                          ),
                        ],
                        selected: {_unitSystem},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _unitSystem = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Ingredients
          Text('Ingredients', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recipe.ingredients.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final rawIng = _recipe.ingredients[index];
                final scaled = UnitConverter.scale(
                  ingredient: rawIng,
                  originalServings: _recipe.servings,
                  targetServings: _servings,
                );
                final converted = UnitConverter.convert(
                  quantity: scaled.quantity,
                  unit: scaled.unit,
                  targetSystem: _unitSystem,
                );

                final qtyStr = UnitConverter.formatQuantity(converted.quantity);

                return ListTile(
                  leading: const Icon(Icons.check_box_outline_blank, size: 20),
                  title: Text(
                    rawIng.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    '$qtyStr ${converted.unit}'.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Prep Steps
          if (_recipe.prepSteps.isNotEmpty) ...[
            Text('Prep Instructions', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recipe.prepSteps.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final step = _recipe.prepSteps[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 12,
                      child: Text(
                        '${step.stepNumber}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    title: Text(step.instruction),
                    trailing: step.estimatedMinutes > 0
                        ? Chip(
                            label: Text('${step.estimatedMinutes} min'),
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Cook Steps
          if (_recipe.cookSteps.isNotEmpty) ...[
            Text('Cook Instructions', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recipe.cookSteps.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final step = _recipe.cookSteps[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 12,
                      child: Text(
                        '${step.stepNumber}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    title: Text(step.instruction),
                    trailing: step.estimatedMinutes > 0
                        ? Chip(
                            label: Text('${step.estimatedMinutes} min'),
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          FilledButton.icon(
            key: const Key('start_cooking_button'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CookingModeScreen(recipe: _recipe, servings: _servings),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Cooking Mode'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
