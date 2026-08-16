import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../logic/task_instance.dart';
import '../../logic/task_repository.dart';
import '../../logic/recipes/unit_converter.dart';

class ShoppingChecklistScreen extends ConsumerStatefulWidget {
  final TaskInstance instance;

  const ShoppingChecklistScreen({super.key, required this.instance});

  @override
  ConsumerState<ShoppingChecklistScreen> createState() =>
      _ShoppingChecklistScreenState();
}

class _ShoppingChecklistScreenState
    extends ConsumerState<ShoppingChecklistScreen> {
  int _currentPhase = 0; // 0 = Pantry Check, 1 = Store Checklist
  late List<ShoppingItemPayload> _items;
  final _customItemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List.from(
      widget.instance.workflowPayload?.shoppingItems ?? const [],
    );

    // If some items were already pantry checked or bought, default to Phase 1 (Store)
    if (_items.any((i) => i.isPantryOwned || i.isBought)) {
      _currentPhase = 1;
    }
  }

  @override
  void dispose() {
    _customItemController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentState({bool completeTask = false}) async {
    final payload =
        widget.instance.workflowPayload?.copyWith(shoppingItems: _items) ??
        WorkflowInstancePayload(
          workflowType: 'mealWorkflow',
          stage: WorkflowStage.shoppingList,
          workflowGroupId: widget.instance.id,
          shoppingItems: _items,
        );

    final updated = widget.instance.copyWith(workflowPayload: payload);
    final repo = ref.read(taskRepositoryProvider);
    if (repo != null) {
      await repo.saveTaskInstance(updated);
      if (completeTask) {
        await repo.completeTaskInstance(updated.id);
      }
    }
  }

  void _addCustomItem() {
    final text = _customItemController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _items.add(
        ShoppingItemPayload(
          id: const Uuid().v4(),
          name: text,
          quantity: 1,
          unit: 'item',
          isPantryOwned: false,
          isBought: false,
          isCustom: true,
        ),
      );
      _customItemController.clear();
    });
    _saveCurrentState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.instance.workflowPayload?.recipeTitle != null
        ? 'Shopping: ${widget.instance.workflowPayload!.recipeTitle}'
        : 'Shopping List';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currentPhase = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _currentPhase == 0
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '1. Pantry Check',
                      style: TextStyle(
                        fontWeight: _currentPhase == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _currentPhase == 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currentPhase = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _currentPhase == 1
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '2. Store Checklist',
                      style: TextStyle(
                        fontWeight: _currentPhase == 1
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _currentPhase == 1
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _currentPhase == 0
          ? _buildPantryCheckView(theme)
          : _buildStoreView(theme),
    );
  }

  Widget _buildPantryCheckView(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.kitchen_outlined, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Check off the ingredients you already have at home so they are excluded from your shopping list.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final qtyAndUnit = UnitConverter.formatQuantityAndUnit(
            item.quantity,
            item.unit,
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              value: item.isPantryOwned,
              title: Text(
                item.name,
                style: TextStyle(
                  decoration: item.isPantryOwned
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              subtitle: Text(qtyAndUnit),
              secondary: Icon(
                item.isPantryOwned
                    ? Icons.inventory
                    : Icons.shopping_basket_outlined,
                color: item.isPantryOwned ? Colors.green : null,
              ),
              onChanged: (val) {
                setState(() {
                  _items[index] = item.copyWith(isPantryOwned: val == true);
                });
                _saveCurrentState();
              },
            ),
          );
        }),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            setState(() => _currentPhase = 1);
            _saveCurrentState();
          },
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Proceed to Store Checklist'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStoreView(ThemeData theme) {
    final toBuyItems = _items.where((i) => !i.isPantryOwned).toList();
    final ownedCount = _items.where((i) => i.isPantryOwned).length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (ownedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Chip(
                    avatar: const Icon(Icons.check, size: 16),
                    label: Text(
                      '$ownedCount items marked as already in pantry',
                    ),
                  ),
                ),
              if (toBuyItems.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'All ingredients are already in your pantry!',
                      ),
                    ),
                  ),
                )
              else
                ...toBuyItems.map((item) {
                  final index = _items.indexWhere((x) => x.id == item.id);
                  final qtyAndUnit = UnitConverter.formatQuantityAndUnit(
                    item.quantity,
                    item.unit,
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: item.isBought
                        ? theme.colorScheme.surfaceContainerHighest.withAlpha(
                            128,
                          )
                        : null,
                    child: CheckboxListTile(
                      value: item.isBought,
                      title: Text(
                        item.name,
                        style: TextStyle(
                          decoration: item.isBought
                              ? TextDecoration.lineThrough
                              : null,
                          fontWeight: item.isBought
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(qtyAndUnit),
                      secondary: Icon(
                        item.isBought
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: item.isBought ? Colors.green : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _items[index] = item.copyWith(isBought: val == true);
                        });
                        _saveCurrentState();
                      },
                    ),
                  );
                }),
              const SizedBox(height: 16),
              // Add Extra Groceries field
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customItemController,
                          decoration: const InputDecoration(
                            hintText: 'Add extra grocery item...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          onSubmitted: (_) => _addCustomItem(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: _addCustomItem,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('done_shopping_button'),
                onPressed: () async {
                  await _saveCurrentState(completeTask: true);
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                },
                icon: const Icon(Icons.done_all),
                label: const Text('Complete Shopping Task'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}
