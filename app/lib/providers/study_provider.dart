import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/knowledge_item.dart';
import '../services/md_parser_service.dart';
import '../services/merge_service.dart';
import '../services/storage_service.dart';

class StudyProvider extends ChangeNotifier {
  StudyProvider({required this.storage, required this.parser});

  final StorageService storage;
  final MdParserService parser;

  List<KnowledgeItem> _items = const [];
  bool _loading = true;
  String? _error;

  Subject? _subject;
  StatusFilter _statusFilter = StatusFilter.all;
  String _query = '';
  bool _maskMode = false;
  final Set<String> _revealed = <String>{};

  List<KnowledgeItem> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  Subject? get subject => _subject;
  StatusFilter get statusFilter => _statusFilter;
  String get query => _query;
  bool get maskMode => _maskMode;

  List<KnowledgeItem> get filteredItems {
    final query = _query.trim().toLowerCase();
    return _items
        .where((item) {
          if (_subject != null && item.subject != _subject) return false;
          switch (_statusFilter) {
            case StatusFilter.all:
              break;
            case StatusFilter.starred:
              if (!item.isStarred) return false;
              break;
            case StatusFilter.fuzzy:
              if (item.status != StudyStatus.fuzzy) return false;
              break;
            case StatusFilter.round2:
              if (!item.isRound2Focus) return false;
              break;
          }
          if (query.isEmpty) return true;
          final haystack = [
            item.prompt,
            item.answer,
            item.explanation,
            item.mnemonic,
            item.sourceNote,
            item.userNote,
            item.tombstoneWords.join(' '),
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  Map<Subject, int> get subjectCounts {
    final counts = {for (final subject in Subject.values) subject: 0};
    for (final item in _items) {
      counts[item.subject] = (counts[item.subject] ?? 0) + 1;
    }
    return counts;
  }

  Map<CardType, int> get typeCounts {
    final counts = {for (final type in CardType.values) type: 0};
    for (final item in _items) {
      counts[item.cardType] = (counts[item.cardType] ?? 0) + 1;
    }
    return counts;
  }

  int get fuzzyCount =>
      _items.where((item) => item.status == StudyStatus.fuzzy).length;

  int get starredCount => _items.where((item) => item.isStarred).length;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final saved = await storage.loadItems();
      if (saved != null && saved.isNotEmpty) {
        _items = saved;
      } else {
        final seed = await rootBundle.loadString('assets/default_sheet.md');
        _items = await storage.loadSeed(seed, parser);
      }
    } catch (error) {
      _error = error.toString();
    }
    _loading = false;
    notifyListeners();
  }

  void setSubject(Subject? value) {
    _subject = value;
    _revealed.clear();
    notifyListeners();
  }

  void setStatusFilter(StatusFilter value) {
    _statusFilter = value;
    _revealed.clear();
    notifyListeners();
  }

  void setQuery(String value) {
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
    _items = next;
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
    _items = result.items;
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
    _items = parsed.items
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
        .toList(growable: false);
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
    _items = parsed.items;
    _subject = null;
    _statusFilter = StatusFilter.all;
    _query = '';
    _maskMode = false;
    _revealed.clear();
    notifyListeners();
    await _persist();
  }

  void _replace(int index, KnowledgeItem item) {
    final next = List<KnowledgeItem>.of(_items);
    next[index] = item;
    _items = next;
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
}
