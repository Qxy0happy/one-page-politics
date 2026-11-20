import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/models/sheet_path.dart';
import 'package:one_page_politics/providers/study_provider.dart';
import 'package:one_page_politics/services/md_parser_service.dart';
import 'package:one_page_politics/services/sheet_tree_service.dart';
import 'package:one_page_politics/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/sheet_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('树：命名章节直接挂科目，未分章按卡片类型展开', () {
    final tree = buildSheetTree(sampleItems());

    expect(tree.progress.total, 5);
    expect(tree.children.map((node) => node.label).toList(), ['马原', '新思想']);

    final mayuan = tree.children.first;
    expect(mayuan.progress.summary, '3 条 · 眼熟 1 · 模糊 1');
    expect(mayuan.children.map((node) => node.label).toList(), [
      '1.1 基础概念与“帽子”',
      '1.2 资本主义与垄断',
    ]);
    expect(mayuan.children.every((node) => node.children.isEmpty), isTrue);
    expect(mayuan.children.first.progress.summary, '2 条 · 眼熟 1 · 模糊 1');

    final xinsixiang = tree.children.last;
    expect(xinsixiang.children.map((node) => node.label).toList(), [
      '配对',
      '对比',
    ]);
    expect(
      xinsixiang.children.first.path,
      const SheetPath(
        subject: Subject.xinsixiang,
        chapter: kUnchaptered,
        cardType: CardType.mapping,
      ),
    );
    expect(xinsixiang.children.first.progress.total, 1);
  });

  test('路径标签、匹配与 JSON 往返', () {
    const chapterPath = SheetPath(
      subject: Subject.mayuan,
      chapter: '1.1 基础概念与“帽子”',
    );
    expect(chapterPath.label, '马原 › 1.1');
    expect(
      const SheetPath(subject: Subject.xinsixiang, chapter: kUnchaptered).label,
      '新思想',
    );
    expect(
      const SheetPath(
        subject: Subject.xinsixiang,
        chapter: kUnchaptered,
        cardType: CardType.pair,
      ).label,
      '新思想 › 对比',
    );
    expect(SheetPath.root.label, '全部');
    expect(SheetPath.fromJson(chapterPath.toJson()), chapterPath);
    expect(
      SheetPath.fromJson({
        'subject': 'mayuan',
        'chapter': '1.1 基础概念与“帽子”',
        'cardType': 'pair',
      }).cardType,
      isNull,
    );
    expect(SheetPath.fromJson({'chapter': '1.1'}), SheetPath.root);
    expect(SheetPath.fromJson({'subject': 'unknown'}), SheetPath.root);

    final item = sampleItems().first;
    expect(chapterPath.matches(item), isTrue);
    expect(
      const SheetPath(
        subject: Subject.mayuan,
        chapter: '1.2 资本主义与垄断',
      ).matches(item),
      isFalse,
    );
    expect(
      const SheetPath(subject: Subject.mayuan).isUnder(SheetPath.root),
      isTrue,
    );
    expect(
      chapterPath.isUnder(const SheetPath(subject: Subject.mayuan)),
      isTrue,
    );
    expect(
      const SheetPath(subject: Subject.shigang).isUnder(chapterPath),
      isFalse,
    );
  });

  test('路径与搜索按 AND 过滤，芯片计数按路径与搜索词分面', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = MemoryStorage(prefs)..items = sampleItems();
    final study = StudyProvider(storage: storage, parser: MdParserService());
    await study.load();

    expect(study.path, SheetPath.root);
    expect(study.filteredItems.length, 5);
    expect(study.statusCounts[StatusFilter.all], 5);

    const path = SheetPath(subject: Subject.mayuan, chapter: '1.1 基础概念与“帽子”');
    await study.setPath(path);
    expect(study.filteredItems.length, 2);
    expect(study.statusCounts[StatusFilter.all], 2);
    expect(study.statusCounts[StatusFilter.fuzzy], 1);
    expect(study.statusCounts[StatusFilter.starred], 1);
    expect(storage.sheetPath, path);

    final restored = StudyProvider(storage: storage, parser: MdParserService());
    await restored.load();
    expect(restored.path, path);

    study.setQuery('帽子');
    expect(study.filteredItems.length, 2);
    expect(study.statusCounts[StatusFilter.all], 2);

    study.setQuery('资本');
    expect(study.filteredItems, isEmpty);
    expect(study.statusCounts[StatusFilter.all], 0);

    await study.setPath(SheetPath.root);
    expect(study.filteredItems.length, 1);
    expect(study.filteredItems.single.id, 'c');
    expect(study.statusCounts[StatusFilter.all], 1);
  });

  test('失效的持久化路径回退到科目或全部', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = MemoryStorage(prefs)..items = sampleItems();

    storage.sheetPath = const SheetPath(
      subject: Subject.mayuan,
      chapter: '不存在的章节',
    );
    final study = StudyProvider(storage: storage, parser: MdParserService());
    await study.load();
    expect(study.path, const SheetPath(subject: Subject.mayuan));

    storage.sheetPath = const SheetPath(subject: Subject.shigang);
    await study.load();
    expect(study.path, SheetPath.root);
  });

  test('真实 prefs 中的路径可往返，损坏时回到全部', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    expect(storage.loadSheetPath(), isNull);
    const path = SheetPath(
      subject: Subject.xinsixiang,
      chapter: kUnchaptered,
      cardType: CardType.pair,
    );
    await storage.saveSheetPath(path);
    expect(storage.loadSheetPath(), path);

    await prefs.setString('sheetPath', '{not json');
    expect(storage.loadSheetPath(), isNull);

    await storage.clearSheetPath();
    expect(storage.loadSheetPath(), isNull);
  });
}
