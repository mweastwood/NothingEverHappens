import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

class ToleranceComparator extends LocalFileComparator {
  ToleranceComparator(super.testFile, this.maxDiffPercent);
  final double maxDiffPercent;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent <= maxDiffPercent) {
      debugPrint(
        'WARNING: Golden diff of ${(result.diffPercent * 100).toStringAsFixed(2)}% '
        'was within tolerance of ${(maxDiffPercent * 100).toStringAsFixed(2)}%.',
      );
      return true;
    }
    return result.passed;
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  if (goldenFileComparator is LocalFileComparator) {
    final LocalFileComparator orig =
        goldenFileComparator as LocalFileComparator;
    goldenFileComparator = ToleranceComparator(
      orig.getTestUri(Uri.parse('fake.dart'), null),
      0.03,
    );
  }
  return GoldenToolkit.runWithConfiguration(() async {
    await testMain();
  }, config: GoldenToolkitConfiguration());
}
