import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/knowledge_item.dart';
import '../../providers/study_provider.dart';
import '../../services/reflex_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/session_summary.dart';

class MappingSessionPage extends StatefulWidget {
  const MappingSessionPage({super.key, required this.initialQueue});

  final List<KnowledgeItem> initialQueue;

  @override
  State<MappingSessionPage> createState() => _MappingSessionPageState();
}

class _MappingSessionPageState extends State<MappingSessionPage> {
  static const _batchSize = 4;

  late List<KnowledgeItem> _queue;
  late int _batchCount;
  var _batchIndex = 0;
  var _batch = <KnowledgeItem>[];
  var _right = <KnowledgeItem>[];
  final Set<String> _matched = {};
  final Set<String> _wrongInBatch = {};
  String? _selectedLeft;
  String? _flashRight;
  var _error = false;
  var _finished = false;
  var _matchedTotal = 0;
  var _wrongTotal = 0;

  @override
  void initState() {
    super.initState();
    _queue = List.of(widget.initialQueue);
    _batchCount = math.max(1, (_queue.length / _batchSize).ceil());
    _loadBatch();
  }

  void _loadBatch() {
    final start = _batchIndex * _batchSize;
    _batch = _queue.sublist(start, math.min(start + _batchSize, _queue.length));
    _right = List.of(_batch)..shuffle();
    _matched.clear();
    _wrongInBatch.clear();
    _selectedLeft = null;
    _flashRight = null;
    _error = false;
  }

  void _selectLeft(KnowledgeItem item) {
    if (_matched.contains(item.id)) return;
    setState(() {
      _selectedLeft = item.id;
      _error = false;
      _flashRight = null;
    });
  }

  void _tapRight(KnowledgeItem right) {
    final leftId = _selectedLeft;
    if (leftId == null || _matched.contains(right.id)) return;
    if (leftId == right.id) {
      setState(() {
        _matched.add(leftId);
        _selectedLeft = null;
        _matchedTotal++;
      });
      unawaited(
        context.read<StudyProvider>().recordJudgement(right.id, correct: true),
      );
      unawaited(HapticFeedback.lightImpact());
      if (_matched.length >= _batch.length) {
        setState(() {});
        Future<void>.delayed(const Duration(milliseconds: 450), () {
          if (mounted) _nextBatch();
        });
      }
      return;
    }

    setState(() {
      _error = true;
      _flashRight = right.id;
    });
    unawaited(HapticFeedback.mediumImpact());
    if (_wrongInBatch.add(leftId)) {
      _wrongTotal++;
      unawaited(
        context.read<StudyProvider>().recordJudgement(leftId, correct: false),
      );
    }
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() {
        _error = false;
        _flashRight = null;
        _selectedLeft = null;
      });
    });
  }

  void _nextBatch() {
    if (!mounted) return;
    if (_batchIndex + 1 >= _batchCount) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _batchIndex++;
      _loadBatch();
    });
  }

  void _restart() {
    final study = context.read<StudyProvider>();
    final queue = ReflexService().buildQueue(study.items, CardType.mapping);
    if (queue.length < _batchSize) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _queue = queue;
      _batchCount = math.max(1, (queue.length / _batchSize).ceil());
      _batchIndex = 0;
      _finished = false;
      _matchedTotal = 0;
      _wrongTotal = 0;
      _loadBatch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('帽子配对')),
        body: SessionSummary(
          title: '配对结束',
          correct: _matchedTotal,
          wrong: _wrongTotal,
          onRestart: _restart,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('帽子配对'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '第 ${_batchIndex + 1}/$_batchCount 批',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            children: [
              Text('先点左栏题干，再点右栏结论；每批 4 组。', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          for (final item in _batch)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _tile(
                                  theme,
                                  text: item.prompt,
                                  selected: _selectedLeft == item.id,
                                  matched: _matched.contains(item.id),
                                  error: _error && _selectedLeft == item.id,
                                  onTap: () => _selectLeft(item),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          for (final item in _right)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _tile(
                                  theme,
                                  text: item.answer,
                                  selected: false,
                                  matched: _matched.contains(item.id),
                                  error: _error && _flashRight == item.id,
                                  onTap: () => _tapRight(item),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    ThemeData theme, {
    required String text,
    required bool selected,
    required bool matched,
    required bool error,
    required VoidCallback onTap,
  }) {
    final borderColor = error
        ? AppColors.red
        : matched
        ? AppColors.green
        : selected
        ? AppColors.blue
        : theme.colorScheme.outlineVariant;
    final background = error
        ? AppColors.redSoft
        : matched
        ? AppColors.greenSoft
        : selected
        ? AppColors.blueSoft
        : theme.cardColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: selected || error ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: matched ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Center(
            child: Text(
              text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: matched ? AppColors.green : null,
                decoration: matched ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
