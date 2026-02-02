import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/fun_check_button.dart';
import 'package:nothing_ever_happens/widgets/task_widget.dart';

/// A Robot for interacting with [TaskWidget] in tests.
class TaskWidgetRobot {
  final WidgetTester tester;
  final Finder parent;

  TaskWidgetRobot(this.tester, {Finder? parent})
    : parent = parent ?? find.byType(TaskWidget);

  /// Create a robot scoped to a specific task by title
  factory TaskWidgetRobot.fromTitle(WidgetTester tester, String title) {
    return TaskWidgetRobot(
      tester,
      parent: find.ancestor(
        of: find.text(title),
        matching: find.byType(TaskWidget),
      ),
    );
  }

  Finder _find(Finder finder) {
    return find.descendant(of: parent, matching: finder);
  }

  Future<void> tapCheckbox() async {
    await tester.tap(_find(find.byType(FunCheckButton)));
    await tester.pump(); // Start animation
  }

  /// Waits for the completion animation to finish (confetti + collapse).
  Future<void> waitForCompletion() async {
    // Wait for confetti delay (600ms in code, using 700ms for safety)
    await tester.pump(const Duration(milliseconds: 700));
    // Wait for collapse animation (600ms in code, using 700ms for safety)
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> expectTitle(String title) async {
    expect(_find(find.text(title)), findsOneWidget);
  }

  Future<void> expectDescription(String description) async {
    expect(_find(find.text(description)), findsOneWidget);
  }

  Future<void> expectChecked(bool checked) async {
    final checkbox = tester.widget<FunCheckButton>(
      _find(find.byType(FunCheckButton)),
    );
    expect(checkbox.value, checked);
  }

  /// Expects the task widget to be present in the tree
  void expectVisible() {
    expect(parent, findsOneWidget);
  }

  /// Expects the task widget to NOT be present in the tree
  void expectGone() {
    expect(parent, findsNothing);
  }
}
