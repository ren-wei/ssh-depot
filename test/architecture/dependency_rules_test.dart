import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature dependency boundaries are explicit', () {
    final libDir = Directory('lib');
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final violations = <String>[];
    final importPattern = RegExp(r'''import\s+['"]package:ssh_depot/(.*?)['"]''');

    for (final file in dartFiles) {
      final sourcePath = file.path.replaceAll('\\', '/');
      final sourcePart = _partName(sourcePath);
      final sourceIsPage = sourcePath.startsWith('lib/feature/pages/');

      for (final match in importPattern.allMatches(file.readAsStringSync())) {
        final importedPath = 'lib/${match.group(1)!}';
        final importedPart = _partName(importedPath);
        if (importedPart == null) {
          continue;
        }

        if (sourcePart == null) {
          if (!sourceIsPage) {
            violations.add('$sourcePath imports part module $importedPath');
          }
          continue;
        }

        if (sourcePart != importedPart && !_allowedCrossPartImport(sourcePart, importedPart)) {
          violations.add('$sourcePath imports another part module $importedPath');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

String? _partName(String path) {
  const marker = 'lib/feature/parts/';
  if (!path.startsWith(marker)) {
    return null;
  }
  final rest = path.substring(marker.length);
  final slash = rest.indexOf('/');
  if (slash <= 0) {
    return null;
  }
  return rest.substring(0, slash);
}

bool _allowedCrossPartImport(String sourcePart, String importedPart) {
  return sourcePart == 'overview' && importedPart == 'services';
}
