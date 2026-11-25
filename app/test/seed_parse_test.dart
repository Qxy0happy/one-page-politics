import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/services/md_parser_service.dart';
import 'package:one_page_politics/services/seed_migration.dart';

void main() {
  test('内置一页纸可以按协议解析', () {
    final text = File('assets/default_sheet.md').readAsStringSync();
    final result = MdParserService().parse(text);
    expect(result.errors, isEmpty, reason: result.errors.take(8).join('\n'));
    expect(result.items.length, greaterThan(200));
    final drill = result.items.where((item) => item.isMappingDrill).length;
    expect(drill, greaterThan(0));

    final trueFalse = result.items.where(
      (item) => item.cardType == CardType.trueFalse,
    );
    expect(
      trueFalse.where((item) => item.prompt.endsWith('）')),
      isEmpty,
      reason: '判断题的括注应放进解析，朗读顺序才是 判定 → 括注 → 解析',
    );
    final ids = result.items.map((item) => item.id).toSet();
    expect(SeedMigration.revision1Ids.difference(ids), isEmpty);

    final moved = result.items.firstWhere(
      (item) => item.id == 'mayuan.trueFalse.04e9fd74',
    );
    expect(moved.prompt, '科技革命是根本动力');
    expect(moved.explanation, '人民群众是根本动力');
    expect(moved.isTrue, isFalse);
    expect(moved.isRound2Focus, isTrue);
    expect(moved.tombstoneWords, contains('根本'));

    // ignore: avoid_print
    print(
      'seed items=${result.items.length} '
      'drill=$drill '
      'warnings=${result.warnings.length} '
      'ignored=${result.ignoredLines}',
    );
  });
}
