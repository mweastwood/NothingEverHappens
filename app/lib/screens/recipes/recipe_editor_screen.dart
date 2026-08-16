import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../logic/recipes/recipe.dart';
import '../../logic/recipes/recipe_repository.dart';

class RecipeEditorScreen extends ConsumerStatefulWidget {
  final Recipe? recipeToEdit;

  const RecipeEditorScreen({super.key, this.recipeToEdit});

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _servings = 4;
  bool _isFamily = false;

  final List<RecipeIngredient> _ingredients = [];
  final List<RecipeStep> _prepSteps = [];
  final List<RecipeStep> _cookSteps = [];

  bool _isSaving = false;

  static const List<String> _commonUnits = [
    'cups',
    'cup',
    'tbsp',
    'tsp',
    'g',
    'kg',
    'oz',
    'lb',
    'lbs',
    'ml',
    'l',
    'piece',
    'pieces',
    'clove',
    'cloves',
    'pinch',
    'can',
    'pkg',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.recipeToEdit != null) {
      final r = widget.recipeToEdit!;
      _titleController.text = r.title;
      _descriptionController.text = r.description;
      _servings = r.servings > 0 ? r.servings : 4;
      _isFamily = r.isFamily;
      _ingredients.addAll(r.ingredients);
      _prepSteps.addAll(r.prepSteps);
      _cookSteps.addAll(r.cookSteps);
    } else {
      // Add default empty ingredient & step
      _ingredients.add(
        const RecipeIngredient(id: '1', name: '', quantity: 1.0, unit: 'cups'),
      );
      _prepSteps.add(
        const RecipeStep(stepNumber: 1, instruction: '', estimatedMinutes: 5),
      );
      _cookSteps.add(
        const RecipeStep(stepNumber: 1, instruction: '', estimatedMinutes: 15),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final filteredIngredients = _ingredients
          .where((i) => i.name.trim().isNotEmpty)
          .toList();

      final filteredPrepSteps = _prepSteps
          .where((s) => s.instruction.trim().isNotEmpty)
          .toList()
          .asMap()
          .entries
          .map(
            (e) => e.value.copyWith(
              stepNumber: e.key + 1,
              timerDurationSeconds: e.value.estimatedMinutes * 60,
            ),
          )
          .toList();

      final filteredCookSteps = _cookSteps
          .where((s) => s.instruction.trim().isNotEmpty)
          .toList()
          .asMap()
          .entries
          .map(
            (e) => e.value.copyWith(
              stepNumber: e.key + 1,
              timerDurationSeconds: e.value.estimatedMinutes * 60,
            ),
          )
          .toList();

      final recipe = Recipe(
        id: widget.recipeToEdit?.id ?? Recipe.generateId(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        servings: _servings,
        ingredients: filteredIngredients,
        prepSteps: filteredPrepSteps,
        cookSteps: filteredCookSteps,
        isFamily: _isFamily,
        createdAt: widget.recipeToEdit?.createdAt,
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(recipeRepositoryProvider);
      await repo.saveRecipe(recipe);

      if (mounted) {
        Navigator.pop(context, recipe);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeToEdit == null ? 'Add Recipe' : 'Edit Recipe'),
        actions: [
          IconButton(
            key: const Key('save_recipe_button'),
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('recipe_title_field'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Recipe Title *',
                hintText: 'e.g. Spaghetti Bolognese',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a recipe title';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('recipe_description_field'),
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description / Notes',
                hintText: 'Brief summary, source, or tips...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline),
                    const SizedBox(width: 12),
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
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.group_outlined),
              title: const Text('Share with Family'),
              subtitle: const Text(
                'Family members can view and cook this recipe',
              ),
              value: _isFamily,
              onChanged: (val) => setState(() => _isFamily = val),
            ),
            const Divider(height: 32),
            _buildIngredientsSection(theme),
            const Divider(height: 32),
            _buildStepsSection(
              title: 'Prep Instructions',
              icon: Icons.kitchen,
              steps: _prepSteps,
              onAdd: () {
                setState(() {
                  _prepSteps.add(
                    RecipeStep(
                      stepNumber: _prepSteps.length + 1,
                      instruction: '',
                      estimatedMinutes: 5,
                    ),
                  );
                });
              },
              theme: theme,
            ),
            const Divider(height: 32),
            _buildStepsSection(
              title: 'Cook Instructions',
              icon: Icons.outdoor_grill,
              steps: _cookSteps,
              onAdd: () {
                setState(() {
                  _cookSteps.add(
                    RecipeStep(
                      stepNumber: _cookSteps.length + 1,
                      instruction: '',
                      estimatedMinutes: 15,
                    ),
                  );
                });
              },
              theme: theme,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Recipe'),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shopping_basket_outlined),
            const SizedBox(width: 8),
            Text('Ingredients', style: theme.textTheme.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _ingredients.add(
                    RecipeIngredient(
                      id: const Uuid().v4(),
                      name: '',
                      quantity: 1.0,
                      unit: 'cups',
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_ingredients.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No ingredients added yet.'),
          ),
        ..._ingredients.asMap().entries.map((entry) {
          final index = entry.key;
          final ing = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: TextFormField(
                      initialValue: ing.quantity > 0
                          ? ing.quantity.toString()
                          : '1',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final qty = double.tryParse(val) ?? 1.0;
                        _ingredients[index] = ing.copyWith(quantity: qty);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: ing.unit),
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _commonUnits;
                        }
                        return _commonUnits.where(
                          (u) => u.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                        );
                      },
                      onSelected: (selection) {
                        _ingredients[index] = ing.copyWith(unit: selection);
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                _ingredients[index] = ing.copyWith(unit: val);
                              },
                            );
                          },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: ing.name,
                      decoration: const InputDecoration(
                        labelText: 'Ingredient Name',
                        hintText: 'e.g. olive oil',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        _ingredients[index] = ing.copyWith(name: val);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        _ingredients.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepsSection({
    required String title,
    required IconData icon,
    required List<RecipeStep> steps,
    required VoidCallback onAdd,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(title, style: theme.textTheme.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Step'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (steps.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No steps added yet.'),
          ),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: step.instruction,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Step ${index + 1} Instructions',
                        hintText: 'Describe what to do...',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        steps[index] = step.copyWith(instruction: val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 75,
                    child: TextFormField(
                      initialValue: step.estimatedMinutes > 0
                          ? step.estimatedMinutes.toString()
                          : '',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        hintText: '5',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final mins = int.tryParse(val) ?? 0;
                        steps[index] = step.copyWith(
                          estimatedMinutes: mins,
                          timerDurationSeconds: mins * 60,
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        steps.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
