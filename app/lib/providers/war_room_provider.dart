import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam_record.dart';
import '../services/storage_service.dart';
import '../services/study_timer.dart';
import 'study_provider.dart';

class WarRoomProvider extends ChangeNotifier {
  WarRoomProvider({
    required this.storage,
    required this.prefs,
    required this.study,
  });

  final StorageService storage;
  final SharedPreferences prefs;
  final StudyProvider study;

  late final StudyTimer methodTimer = StudyTimer(
    key: 'method',
    label: '解题方法 30min',
    duration: const Duration(minutes: 30),
    prefs: prefs,
  );

  late final StudyTimer sheetTimer = StudyTimer(
    key: 'sheet',
    label: '一页纸 30min',
    duration: const Duration(minutes: 30),
    prefs: prefs,
  );

  List<ExamRecord> _records = const [];
  var _passCount = 0;
  DateTime? _lastPass;
  Timer? _ticker;
  var _loading = true;

  bool get loading => _loading;
  int get passCount => _passCount;
  DateTime? get lastPass => _lastPass;

  List<ExamRecord> get records {
    final list = List<ExamRecord>.of(_records);
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  List<ExamRecord> get chartRecords {
    final list = List<ExamRecord>.of(_records);
    list.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  Future<void> load() async {
    _loading = true;
    try {
      _records = await storage.loadRecords();
      _passCount = prefs.getInt('passCount') ?? 0;
      final last = prefs.getString('passLastDate');
      _lastPass = last == null ? null : DateTime.tryParse(last);
    } finally {
      _loading = false;
    }
    _ticker ??= Timer.periodic(const Duration(milliseconds: 500), _tick);
    notifyListeners();
  }

  void _tick(Timer _) {
    var justCompleted = false;
    if (methodTimer.tick()) justCompleted = true;
    if (sheetTimer.tick()) justCompleted = true;
    if (justCompleted) unawaited(HapticFeedback.vibrate());
    notifyListeners();
  }

  void startTimer(StudyTimer timer) {
    timer.start();
    notifyListeners();
  }

  void pauseTimer(StudyTimer timer) {
    timer.pause();
    notifyListeners();
  }

  void resetTimer(StudyTimer timer) {
    timer.reset();
    notifyListeners();
  }

  Future<void> addPass() async {
    _passCount++;
    _lastPass = DateTime.now();
    await prefs.setInt('passCount', _passCount);
    await prefs.setString('passLastDate', _lastPass!.toIso8601String());
    notifyListeners();
  }

  Future<void> addRecord(ExamRecord record) async {
    _records = [..._records.where((item) => item.id != record.id), record];
    await storage.saveRecords(_records);
    await study.starItems(record.linkedWrongItemIds);
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    _records = _records.where((item) => item.id != id).toList(growable: false);
    await storage.saveRecords(_records);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _records = const [];
    _passCount = 0;
    _lastPass = null;
    methodTimer.reset();
    sheetTimer.reset();
    await storage.saveRecords(const []);
    await prefs.remove('passCount');
    await prefs.remove('passLastDate');
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
