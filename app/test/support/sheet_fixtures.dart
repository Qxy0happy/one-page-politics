import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/models/sheet_path.dart';
import 'package:one_page_politics/services/md_parser_service.dart';
import 'package:one_page_politics/services/storage_service.dart';

KnowledgeItem makeItem({
  required String id,
  required Subject subject,
  required String chapter,
  required CardType cardType,
  required String prompt,
  StudyStatus status = StudyStatus.unseen,
  bool starred = false,
  bool round2 = false,
}) {
  return KnowledgeItem(
    id: id,
    subject: subject,
    chapter: chapter,
    cardType: cardType,
    prompt: prompt,
    answer: cardType == CardType.trueFalse ? '' : '答案 $id',
    isTrue: cardType == CardType.trueFalse ? false : null,
    pairAFeature: cardType == CardType.pair ? 'A 特征' : null,
    pairBFeature: cardType == CardType.pair ? 'B 特征' : null,
    status: status,
    isStarred: starred,
    isRound2Focus: round2,
  );
}

List<KnowledgeItem> sampleItems() => [
  makeItem(
    id: 'a',
    subject: Subject.mayuan,
    chapter: '1.1 基础概念与“帽子”',
    cardType: CardType.mapping,
    prompt: '帽子一',
    status: StudyStatus.familiar,
  ),
  makeItem(
    id: 'b',
    subject: Subject.mayuan,
    chapter: '1.1 基础概念与“帽子”',
    cardType: CardType.trueFalse,
    prompt: '帽子二',
    status: StudyStatus.fuzzy,
    starred: true,
  ),
  makeItem(
    id: 'c',
    subject: Subject.mayuan,
    chapter: '1.2 资本主义与垄断',
    cardType: CardType.mapping,
    prompt: '资本一',
  ),
  makeItem(
    id: 'd',
    subject: Subject.xinsixiang,
    chapter: kUnchaptered,
    cardType: CardType.mapping,
    prompt: '新思想一',
  ),
  makeItem(
    id: 'e',
    subject: Subject.xinsixiang,
    chapter: kUnchaptered,
    cardType: CardType.pair,
    prompt: '新思想二',
  ),
];

class MemoryStorage extends StorageService {
  MemoryStorage(super.prefs);

  List<KnowledgeItem> items = const [];
  SheetPath? sheetPath;

  @override
  Future<List<KnowledgeItem>?> loadItems() async =>
      items.isEmpty ? null : items;

  @override
  Future<void> saveItems(List<KnowledgeItem> items) async {
    this.items = items;
  }

  @override
  Future<List<KnowledgeItem>> loadSeed(
    String seedText,
    MdParserService parser,
  ) async {
    final parsed = parser.parse(seedText);
    if (!parsed.isValid) {
      throw StorageException('seed 解析失败');
    }
    items = parsed.items;
    return items;
  }

  @override
  SheetPath? loadSheetPath() => sheetPath;

  @override
  Future<void> saveSheetPath(SheetPath path) async {
    sheetPath = path;
  }

  @override
  Future<void> clearSheetPath() async {
    sheetPath = null;
  }

  @override
  Future<void> clearAll() async {
    items = const [];
    sheetPath = null;
  }
}
