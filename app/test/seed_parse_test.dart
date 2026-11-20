import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/services/md_parser_service.dart';

void main() {
  test('内置一页纸可以按协议解析', () {
    final text = File('assets/default_sheet.md').readAsStringSync();
    final result = MdParserService().parse(text);
    expect(result.errors, isEmpty, reason: result.errors.take(8).join('\n'));
    expect(result.items.length, greaterThan(200));
    final drill = result.items.where((item) => item.isMappingDrill).length;
    expect(drill, greaterThan(0));
    // ignore: avoid_print
    print(
      'seed items=${result.items.length} '
      'drill=$drill '
      'warnings=${result.warnings.length} '
      'ignored=${result.ignoredLines}',
    );
  });
}
