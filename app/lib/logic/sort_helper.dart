List<({String column, bool ascending})> updateSortHistory(
  List<({String column, bool ascending})> currentHistory,
  String column,
) {
  final newHistory = List<({String column, bool ascending})>.from(
    currentHistory,
  );
  bool ascending = true;
  if (newHistory.isNotEmpty && newHistory.first.column == column) {
    ascending = !newHistory.first.ascending;
    newHistory.removeAt(0);
  } else {
    newHistory.removeWhere((element) => element.column == column);
  }

  newHistory.insert(0, (column: column, ascending: ascending));

  if (newHistory.length > 3) {
    newHistory.removeLast();
  }
  return newHistory;
}

int compareDateTimes(DateTime? a, DateTime? b, bool ascending) {
  int result;
  if (a == null && b == null) {
    result = 0;
  } else if (a == null) {
    result = 1;
  } else if (b == null) {
    result = -1;
  } else {
    result = a.compareTo(b);
  }
  return ascending ? result : -result;
}
