import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/knowledge_item.dart';
import '../models/sheet_path.dart';
import '../services/md_parser_service.dart';
import '../services/merge_service.dart';
import '../services/sheet_tree_service.dart';
import '../services/storage_service.dart';

class StudyProvider extends ChangeNotifier {
  StudyProvider({required this.storage, required this.parser});

  final StorageService storage;
  final MdParserService parser;

  List<KnowledgeItem> _items = const [];
  Map<String, String>? _haystacks;
  bool _loading = true;
  String? _error;

  SheetPath _path = SheetPath.root;
  StatusFilter _statusFilter = StatusFilter.all;
  String _query = '';
  bool _maskMode = false;
  final Set<String> _revealed = <String>{};

  List<KnowledgeItem> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  SheetPath get path => _path;
  String get pathLabel => _path.label;
  StatusFilter get statusFilter => _statusFilter;
  String get query => _query;
  bool get maskMode => _maskMode;

  List<KnowledgeItem> get filteredItems {
    final query = _query.trim().toLowerCase();
    return _items
        .where(
          (item) =>
              _path.matches(item) &&
              _matchesStatus(item) &&
              _matchesQuery(item, query),
        )
        .toList(growable: false);
  }

  /// 状态芯片的分面计数：当前路径 + 搜索词，不含状态本身。
  Map<StatusFilter, int> get statusCounts {
    final query = _query.trim().toLowerCase();
    var all = 0;
    var starred = 0;
    var fuzzy = 0;
    var round2 = 0;
    for (final item in _items) {
      if (!_path.matches(item) || !_matchesQuery(item, query)) continue;
      all++;
      if (item.isStarred) starred++;
      if (item.status == StudyStatus.fuzzy) fuzzy++;
      if (item.isRound2Focus) round2++;
    }
    return {
      StatusFilter.all: all,
      StatusFilter.starred: starred,
      StatusFilter.fuzzy: fuzzy,
      StatusFilter.round2: round2,
    };
  }

  SheetNode get sheetTree => buildSheetTree(_items);

  int get fuzzyCount =>
      _items.where((item) => item.status == StudyStatus.fuzzy).length;

  int get starredCount => _items.where((item) => item.isStarred).length;

  bool _matchesStatus(KnowledgeItem item) => switch (_statusFilter) {
    StatusFilter.all => true,
    StatusFilter.starred => item.isStarred,
    StatusFilter.fuzzy => item.status == StudyStatus.fuzzy,
    StatusFilter.round2 => item.isRound2Focus,
  };

  Map<String, String> get _searchIndex =>
      _haystacks ??= {for (final item in _items) item.id: _haystack(item)};

  bool _matchesQuery(KnowledgeItem item, String query) =>
      query.isEmpty || (_searchIndex[item.id] ?? '').contains(query);

  static String _haystack(KnowledgeItem item) => [
    item.prompt,
    item.answer,
    item.explanation,
    item.mnemonic,
    item.sourceNote,
    item.userNote,
    item.tombstoneWords.join(' '),
  ].join(' ').toLowerCase();

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final saved = await storage.loadItems();
      if (saved != null && saved.isNotEmpty) {
        _setItems(saved);
      } else {
        final seed = await rootBundle.loadString('assets/default_sheet.md');
        _setItems(await storage.loadSeed(seed, parser));
      }
      _path = _validPath(storage.loadSheetPath());
    } catch (error) {
      _error = error.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> setPath(SheetPath value) async {
    final next = _validPath(value);
    if (next == _path) return;
    _path = next;
    _revealed.clear();
    notifyListeners();
    await _persistPath();
  }

  void setStatusFilter(StatusFilter value) {
    _statusFilter = value;
    _revealed.clear();
    notifyListeners();
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void toggleMaskMode() {
    _maskMode = !_maskMode;
    _revealed.clear();
    notifyListeners();
  }

  bool isRevealed(String itemId, String field) =>
      _revealed.contains('$itemId:$field');

  void toggleReveal(String itemId, String field) {
    final key = '$itemId:$field';
    if (!_revealed.add(key)) _revealed.remove(key);
    notifyListeners();
  }

  Future<void> toggleStatus(String id, StudyStatus target) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final current = _items[index];
    final nextStatus = current.status == target ? StudyStatus.unseen : target;
    final next = current.copyWith(
      status: nextStatus,
      reviewCount: current.reviewCount + 1,
    );
    _replace(index, next);
    await _persist();
  }

  Future<void> toggleStar(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final current = _items[index];
    _replace(index, current.copyWith(isStarred: !current.isStarred));
    await _persist();
  }

  Future<void> updateItem(KnowledgeItem item) async {
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) return;
    _replace(index, item);
    await _persist();
  }

  /// 微训练判题回写：错误置为模糊；正确只增加复习次数，不改三态。
  Future<void> recordJudgement(String id, {required bool correct}) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final current = _items[index];
    _replace(
      index,
      current.copyWith(
        status: correct ? current.status : StudyStatus.fuzzy,
        reviewCount: current.reviewCount + 1,
      ),
    );
    await _persist();
  }

  Future<void> starItems(Iterable<String> ids) async {
    final targets = ids.toSet();
    if (targets.isEmpty) return;
    var changed = false;
    final next = _items
        .map((item) {
          if (targets.contains(item.id) && !item.isStarred) {
            changed = true;
            return item.copyWith(isStarred: true);
          }
          return item;
        })
        .toList(growable: false);
    if (!changed) return;
    _setItems(next);
    notifyListeners();
    await _persist();
  }

  Future<MergeResult> importItems(
    List<KnowledgeItem> incoming, {
    bool overrideLocalEdits = false,
  }) async {
    final result = MergeService().merge(
      _items,
      incoming,
      overrideLocalEdits: overrideLocalEdits,
    );
    _setItems(result.items);
    _revalidatePath();
    notifyListeners();
    await _persist();
    return result;
  }

  Future<void> restoreSeed() async {
    final seedText = await rootBundle.loadString('assets/default_sheet.md');
    final parsed = parser.parse(seedText);
    if (!parsed.isValid) {
      throw StorageException('内置一页纸解析失败：${parsed.errors.take(3).join('；')}');
    }
    final oldById = {for (final item in _items) item.id: item};
    _setItems(
      parsed.items
          .map((seed) {
            final old = oldById[seed.id];
            if (old == null) return seed;
            return seed.copyWith(
              status: old.status,
              isStarred: old.isStarred,
              reviewCount: old.reviewCount,
              userNote: old.userNote,
            );
          })
          .toList(growable: false),
    );
    _revalidatePath();
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    await storage.clearAll();
    final seedText = await rootBundle.loadString('assets/default_sheet.md');
    final parsed = parser.parse(seedText);
    if (!parsed.isValid) {
      throw StorageException('内置一页纸解析失败：${parsed.errors.take(3).join('；')}');
    }
    _setItems(parsed.items);
    _path = SheetPath.root;
    _statusFilter = StatusFilter.all;
    _query = '';
    _maskMode = false;
    _revealed.clear();
    notifyListeners();
    await _persist();
  }

  SheetPath _validPath(SheetPath? path) {
    if (path == null || path.subject == null) return SheetPath.root;
    final subject = path.subject!;
    if (!_items.any((item) => item.subject == subject)) {
      return SheetPath.root;
    }
    if (path.chapter == null) return SheetPath(subject: subject);
    final chapter = path.chapter!;
    final chapterExists = _items.any(
      (item) => item.subject == subject && item.chapter == chapter,
    );
    if (!chapterExists) return SheetPath(subject: subject);
    if (path.cardType == null) {
      return SheetPath(subject: subject, chapter: chapter);
    }
    final typeExists = _items.any(
      (item) =>
          item.subject == subject &&
          item.chapter == chapter &&
          item.cardType == path.cardType,
    );
    if (!typeExists) return SheetPath(subject: subject, chapter: chapter);
    return path;
  }

  void _revalidatePath() {
    final next = _validPath(_path);
    if (next == _path) return;
    _path = next;
    unawaited(_persistPath());
  }

  void _setItems(List<KnowledgeItem> items) {
    _items = items;
    _haystacks = null;
  }

  void _replace(int index, KnowledgeItem item) {
    final next = List<KnowledgeItem>.of(_items);
    next[index] = item;
    _setItems(next);
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await storage.saveItems(_items);
      _error = null;
    } catch (error) {
      _error = '保存失败：$error';
      notifyListeners();
    }
  }

  Future<void> _persistPath() async {
    try {
      await storage.saveSheetPath(_path);
    } catch (_) {
      // 路径只是导航状态；保存失败不阻断条目与进度。
    }
  }
}
