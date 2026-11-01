import 'package:flutter/material.dart';

class TwoColumnMasonryList<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T item) idOf;
  final double Function(T item) estimatedHeightOf;
  final Map<String, int> columnAffinity;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double columnSpacing;

  const TwoColumnMasonryList({
    super.key,
    required this.items,
    required this.idOf,
    required this.estimatedHeightOf,
    required this.columnAffinity,
    required this.itemBuilder,
    this.columnSpacing = 8.0,
  });

  static ({List<T> leftColumn, List<T> rightColumn}) distribute<T>({
    required List<T> items,
    required String Function(T item) idOf,
    required double Function(T item) estimatedHeightOf,
    required Map<String, int> columnAffinity,
  }) {
    final leftColumn = <T>[];
    final rightColumn = <T>[];

    final currentIds = items.map(idOf).toSet();
    columnAffinity.removeWhere((id, _) => !currentIds.contains(id));

    double leftHeight = 0.0;
    double rightHeight = 0.0;

    for (final item in items) {
      final id = idOf(item);
      final height = estimatedHeightOf(item);
      int? col = columnAffinity[id];
      if (col == null) {
        col = leftHeight <= rightHeight ? 0 : 1;
        columnAffinity[id] = col;
      }
      if (col == 0) {
        leftColumn.add(item);
        leftHeight += height;
      } else {
        rightColumn.add(item);
        rightHeight += height;
      }
    }

    return (leftColumn: leftColumn, rightColumn: rightColumn);
  }

  @override
  Widget build(BuildContext context) {
    final distributed = distribute<T>(
      items: items,
      idOf: idOf,
      estimatedHeightOf: estimatedHeightOf,
      columnAffinity: columnAffinity,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in distributed.leftColumn)
                itemBuilder(context, item),
            ],
          ),
        ),
        SizedBox(width: columnSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in distributed.rightColumn)
                itemBuilder(context, item),
            ],
          ),
        ),
      ],
    );
  }
}
