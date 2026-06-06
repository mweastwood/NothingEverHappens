import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('No dev_dependencies are imported in lib/', () {
    final libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'lib/ directory not found in the current working directory',
    );

    final forbiddenPatterns = [
      'package:fake_cloud_firestore/',
      'package:flutter_test/',
      'package:golden_toolkit/',
      'package:mockito/',
    ];

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final violatingFiles = <String, List<String>>{};

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
          for (final pattern in forbiddenPatterns) {
            if (trimmed.contains(pattern)) {
              violatingFiles.putIfAbsent(file.path, () => []).add(trimmed);
            }
          }
        }
      }
    }

    expect(
      violatingFiles,
      isEmpty,
      reason:
          'The following files in lib/ import/export forbidden dev_dependencies:\n'
          '${violatingFiles.entries.map((e) => '${e.key}:\n  - ${e.value.join('\n  - ')}').join('\n')}',
    );
  });
}
