import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam_record.dart';
import '../models/knowledge_item.dart';
import '../models/sheet_path.dart';
import 'md_parser_service.dart';

class StorageException implements Exception {
  StorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StorageService {
  StorageService(this.prefs);

  final SharedPreferences prefs;

  static const _itemsFile = 'knowledge_items.json';
  static const _recordsFile = 'exam_records.json';
  static const _sheetPathKey = 'sheetPath';
  static const _seedRevisionKey = 'seedRevision';
  static const _schemaVersion = 1;

  Future<Directory> _directory() async {
    final dir = await getApplicationDocumentsDirectory();
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String name) async {
    final dir = await _directory();
    return File('${dir.path}/$name');
  }

  Future<List<KnowledgeItem>?> loadItems() async {
    final file = await _file(_itemsFile);
    final loaded = await _readItems(file);
    if (loaded != null) return loaded;

    final backup = await _file('$_itemsFile.bak');
    final fromBackup = await _readItems(backup);
    if (fromBackup != null) {
      await _writeJson(file, {
        'schemaVersion': _schemaVersion,
        'items': fromBackup.map((e) => e.toJson()).toList(),
      });
      return fromBackup;
    }
    return null;
  }

  Future<List<KnowledgeItem>?> _readItems(File file) async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schemaVersion'] != _schemaVersion) {
        throw StorageException('数据版本不兼容，请先导出备份');
      }
      final raw = decoded['items'];
      if (raw is! List) return null;
      return raw
          .whereType<Map>()
          .map((e) => KnowledgeItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (error) {
      if (error is StorageException) rethrow;
      await _quarantine(file);
      return null;
    }
  }

  Future<void> saveItems(List<KnowledgeItem> items) async {
    final file = await _file(_itemsFile);
    await _writeJson(file, {
      'schemaVersion': _schemaVersion,
      'items': items.map((e) => e.toJson()).toList(),
    });
  }

  Future<List<ExamRecord>> loadRecords() async {
    final file = await _file(_recordsFile);
    if (!await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return const [];
      if (decoded['schemaVersion'] != _schemaVersion) {
        throw StorageException('数据版本不兼容，请先导出备份');
      }
      final raw = decoded['records'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => ExamRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (error) {
      if (error is StorageException) rethrow;
      await _quarantine(file);
      return const [];
    }
  }

  Future<void> saveRecords(List<ExamRecord> records) async {
    final file = await _file(_recordsFile);
    await _writeJson(file, {
      'schemaVersion': _schemaVersion,
      'records': records.map((e) => e.toJson()).toList(),
    });
  }

  SheetPath? loadSheetPath() {
    final raw = prefs.getString(_sheetPathKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return SheetPath.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // 路径只是导航状态；损坏时回到全部，不影响条目数据。
    }
    return null;
  }

  Future<void> saveSheetPath(SheetPath path) async {
    await prefs.setString(_sheetPathKey, jsonEncode(path.toJson()));
  }

  Future<void> clearSheetPath() async {
    await prefs.remove(_sheetPathKey);
  }

  int loadSeedRevision() => prefs.getInt(_seedRevisionKey) ?? 0;

  Future<void> saveSeedRevision(int revision) async {
    await prefs.setInt(_seedRevisionKey, revision);
  }

  Future<List<KnowledgeItem>> loadSeed(
    String seedText,
    MdParserService parser,
  ) async {
    final parsed = parser.parse(seedText);
    if (!parsed.isValid) {
      throw StorageException('内置一页纸解析失败：${parsed.errors.take(5).join('；')}');
    }
    await saveItems(parsed.items);
    return parsed.items;
  }

  Future<void> _writeJson(File target, Map<String, dynamic> payload) async {
    final temp = File('${target.path}.tmp');
    final backup = File('${target.path}.bak');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    if (await target.exists()) {
      if (await backup.exists()) await backup.delete();
      await target.rename(backup.path);
    }
    await temp.rename(target.path);
  }

  Future<void> _quarantine(File file) async {
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await file.rename('${file.path}.corrupt-$stamp');
    } catch (_) {
      // 保留原文件；不因清理失败覆盖数据。
    }
  }

  Future<void> clearAll() async {
    await prefs.remove(_sheetPathKey);
    await prefs.remove(_seedRevisionKey);
    for (final name in const [_itemsFile, _recordsFile]) {
      final file = await _file(name);
      if (await file.exists()) await file.delete();
      final backup = await _file('$name.bak');
      if (await backup.exists()) await backup.delete();
    }
  }
}
