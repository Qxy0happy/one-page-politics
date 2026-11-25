import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/providers/study_provider.dart';
import 'package:one_page_politics/services/md_parser_service.dart';
import 'package:one_page_politics/services/seed_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/sheet_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('启动迁移只更新受影响的条目并保留进度与手改', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = MemoryStorage(prefs)
      ..items = [
        const KnowledgeItem(
          id: 'mayuan.trueFalse.04e9fd74',
          subject: Subject.mayuan,
          chapter: '1.4 判断大关与易错原话',
          cardType: CardType.trueFalse,
          prompt: '科技革命是根本动力（人民群众是根本动力）',
          isTrue: false,
          status: StudyStatus.fuzzy,
          isStarred: true,
          reviewCount: 7,
          userNote: '我的备注',
        ),
        const KnowledgeItem(
          id: 'mayuan.trueFalse.027edd43',
          subject: Subject.mayuan,
          chapter: '1.4 判断大关与易错原话',
          cardType: CardType.trueFalse,
          prompt: '人类求知欲是认识最终目的（实践）',
          isTrue: false,
          isCustomEdited: true,
          status: StudyStatus.familiar,
        ),
        const KnowledgeItem(
          id: 'custom.mapping.aaaaaaaa',
          subject: Subject.mayuan,
          chapter: '自定义',
          cardType: CardType.mapping,
          prompt: '自定义条目',
          answer: '自定义结论',
        ),
      ];
    await storage.saveSeedRevision(0);

    final study = StudyProvider(storage: storage, parser: MdParserService());
    await study.load();

    expect(study.items, hasLength(3));
    final migrated = study.items.firstWhere(
      (item) => item.id == 'mayuan.trueFalse.04e9fd74',
    );
    expect(migrated.prompt, '科技革命是根本动力');
    expect(migrated.explanation, '人民群众是根本动力');
    expect(migrated.isTrue, isFalse);
    expect(migrated.status, StudyStatus.fuzzy);
    expect(migrated.isStarred, isTrue);
    expect(migrated.reviewCount, 7);
    expect(migrated.userNote, '我的备注');

    final keptLocal = study.items.firstWhere(
      (item) => item.id == 'mayuan.trueFalse.027edd43',
    );
    expect(keptLocal.prompt, '人类求知欲是认识最终目的（实践）');
    expect(keptLocal.explanation, isEmpty);
    expect(keptLocal.status, StudyStatus.familiar);

    expect(
      study.items.where((item) => item.id == 'custom.mapping.aaaaaaaa'),
      hasLength(1),
    );
    expect(storage.loadSeedRevision(), SeedMigration.revision);
    study.dispose();
  });

  test('修订号已是最新时不重读 seed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = MemoryStorage(prefs)
      ..items = [
        const KnowledgeItem(
          id: 'mayuan.trueFalse.04e9fd74',
          subject: Subject.mayuan,
          chapter: '1.4 判断大关与易错原话',
          cardType: CardType.trueFalse,
          prompt: '本地未迁移的题干',
          isTrue: false,
        ),
      ];
    await storage.saveSeedRevision(SeedMigration.revision);

    final study = StudyProvider(storage: storage, parser: MdParserService());
    await study.load();

    expect(study.items.single.prompt, '本地未迁移的题干');
    study.dispose();
  });
}
