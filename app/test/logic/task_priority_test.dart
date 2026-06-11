import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/task.dart';

void main() {
  group('TaskPriority enum', () {
    test('defines expected values in priority order', () {
      expect(TaskPriority.values.length, 3);
      expect(TaskPriority.low.name, 'low');
      expect(TaskPriority.medium.name, 'medium');
      expect(TaskPriority.high.name, 'high');
    });
  });
}
