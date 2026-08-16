import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/recipes/recipe_repository.dart';
import 'recipe_detail_screen.dart';
import 'recipe_editor_screen.dart';

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  String _searchQuery = '';
  bool? _familyFilter; // null = all, false = personal, true = family

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(recipesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Library'),
        actions: [
          IconButton(
            key: const Key('add_recipe_appbar_button'),
            icon: const Icon(Icons.add),
            tooltip: 'Add Recipe',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecipeEditorScreen(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_recipe_fab'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RecipeEditorScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Recipe'),
      ),
      body: Column(
        children: [
          // Search & Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search recipes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _familyFilter == null,
                  onSelected: (_) => setState(() => _familyFilter = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Personal'),
                  selected: _familyFilter == false,
                  onSelected: (_) => setState(() => _familyFilter = false),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Family Shared'),
                  selected: _familyFilter == true,
                  onSelected: (_) => setState(() => _familyFilter = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Recipe List
          Expanded(
            child: recipesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('Error loading recipes: $err')),
              data: (allRecipes) {
                var filtered = allRecipes;
                if (_familyFilter != null) {
                  filtered = filtered
                      .where((r) => r.isFamily == _familyFilter)
                      .toList();
                }
                if (_searchQuery.trim().isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered.where((r) {
                    return r.title.toLowerCase().contains(q) ||
                        r.description.toLowerCase().contains(q) ||
                        r.ingredients.any(
                          (i) => i.name.toLowerCase().contains(q),
                        );
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(
                            128,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No recipes match your search'
                              : 'Your recipe library is empty',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your favorite meals and ingredients.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final recipe = filtered[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RecipeDetailScreen(recipe: recipe),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      recipe.title,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  if (recipe.isFamily)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.group,
                                            size: 14,
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Family',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              if (recipe.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  recipe.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${recipe.servings} servings',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${recipe.totalMinutes} min',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.shopping_basket_outlined,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${recipe.ingredients.length} items',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
