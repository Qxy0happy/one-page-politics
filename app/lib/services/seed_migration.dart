import '../models/knowledge_item.dart';
import 'merge_service.dart';

/// 内置一页纸的内容修订。
///
/// 每次修订递增 [revision]，并把受影响的 id 放进对应集合。旧安装启动时
/// 只更新这些条目：不新增、不删除其他条目，也不覆盖手改内容。这样自定义
/// 导入的列表不会被内置条目污染，id 不变则学习进度继续跟随。
class SeedMigration {
  SeedMigration._();

  static const int revision = 1;

  /// 修订 1：把判断题干末尾的括注移入“解析”，使朗读顺序变为
  /// 判定 → 括注 → 解析。题干参与 id 哈希，所以先冻结这些条目的 id。
  static const Set<String> revision1Ids = {
    'mayuan.trueFalse.d12f9ca1',
    'mayuan.trueFalse.04e9fd74',
    'mayuan.trueFalse.027edd43',
    'mayuan.trueFalse.61174925',
    'mayuan.trueFalse.2060e995',
    'mayuan.trueFalse.e9d08c2b',
    'mayuan.trueFalse.deb47c1e',
    'mayuan.trueFalse.98d95aa4',
    'mayuan.trueFalse.4eeebf75',
    'mayuan.trueFalse.2dba0db7',
    'mayuan.trueFalse.91fb65e6',
    'mayuan.trueFalse.3628c7fd',
    'mayuan.trueFalse.48f2764e',
    'mayuan.trueFalse.8de8d953',
    'mayuan.trueFalse.0baf6429',
    'mayuan.trueFalse.b478566a',
    'mayuan.trueFalse.4425be29',
  };

  /// 只把已存在且受本次修订影响的条目替换为 seed 内容。
  ///
  /// [MergeService] 负责保留三态、标星、复习次数、备注与手改标记；
  /// 手改过的条目按既有导入规则保留本地内容。
  static List<KnowledgeItem> apply(
    List<KnowledgeItem> saved,
    List<KnowledgeItem> seed,
  ) {
    if (saved.isEmpty) return saved;
    final seedById = {for (final item in seed) item.id: item};
    final changed = <KnowledgeItem>[];
    for (final item in saved) {
      if (!revision1Ids.contains(item.id)) continue;
      final next = seedById[item.id];
      if (next != null) changed.add(next);
    }
    if (changed.isEmpty) return saved;
    return MergeService().merge(saved, changed).items;
  }
}
