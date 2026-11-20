import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/knowledge_item.dart';
import '../../providers/study_provider.dart';
import '../../services/reflex_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/session_summary.dart';

class PairSessionPage extends StatefulWidget {
  const PairSessionPage({super.key, required this.initialQueue});

  final List<KnowledgeItem> initialQueue;

  @override
  State<PairSessionPage> createState() => _PairSessionPageState();
}

class _PairSessionPageState extends State<PairSessionPage> {
  final _random = Random();
  late List<KnowledgeItem> _queue;
  var _index = 0;
  var _correct = 0;
  var _wrong = 0;
  var _askA = true;
  bool? _chosenA;
  var _revealed = false;

  @override
  void initState() {
    super.initState();
    _queue = List.of(widget.initialQueue);
    _askA = _random.nextBool();
  }

  bool get _finished => _index >= _queue.length;

  void _answer(bool choseA) {
    if (_revealed) return;
    final item = _queue[_index];
    final correct = choseA == _askA;
    setState(() {
      _chosenA = choseA;
      _revealed = true;
      if (correct) {
        _correct++;
      } else {
        _wrong++;
      }
    });
    unawaited(
      context.read<StudyProvider>().recordJudgement(item.id, correct: correct),
    );
    if (!correct) unawaited(HapticFeedback.mediumImpact());
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      _index++;
      _revealed = false;
      _chosenA = null;
      _askA = _random.nextBool();
    });
  }

  void _restart() {
    final study = context.read<StudyProvider>();
    final queue = ReflexService().buildQueue(study.items, CardType.pair);
    if (queue.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _queue = queue;
      _index = 0;
      _correct = 0;
      _wrong = 0;
      _revealed = false;
      _chosenA = null;
      _askA = _random.nextBool();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('双胞胎辨析')),
        body: SessionSummary(
          title: '辨析结束',
          correct: _correct,
          wrong: _wrong,
          onRestart: _restart,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    }

    final item = _queue[_index];
    final feature = _askA
        ? (item.pairAFeature ?? '（缺少特征）')
        : (item.pairBFeature ?? '（缺少特征）');
    return Scaffold(
      appBar: AppBar(
        title: const Text('双胞胎辨析'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_index + 1}/${_queue.length}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _tag(theme, item.subject.label, AppColors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.chapter,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('下列哪一项的核心特征是', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(
                      '「$feature」',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.amber,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('从 A / B 中选一个。', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _choice(
              theme,
              label: 'A',
              text: item.prompt,
              correct: _revealed && _askA,
              selected: _chosenA == true,
              onTap: () => _answer(true),
            ),
            const SizedBox(height: 10),
            _choice(
              theme,
              label: 'B',
              text: item.answer,
              correct: _revealed && !_askA,
              selected: _chosenA == false,
              onTap: () => _answer(false),
            ),
            if (_revealed) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _chosenA == _askA
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: _chosenA == _askA
                                ? AppColors.green
                                : AppColors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _chosenA == _askA ? '回答正确' : '回答错误',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _compareRow(theme, 'A', item.prompt, item.pairAFeature),
                      const SizedBox(height: 8),
                      _compareRow(theme, 'B', item.answer, item.pairBFeature),
                      if (item.mnemonic.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '口诀：${item.mnemonic}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _next,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('下一题'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _choice(
    ThemeData theme, {
    required String label,
    required String text,
    required bool correct,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final borderColor = correct
        ? AppColors.green
        : selected
        ? AppColors.red
        : theme.colorScheme.outlineVariant;
    final background = correct
        ? AppColors.greenSoft
        : selected
        ? AppColors.redSoft
        : theme.cardColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _revealed ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.blueSoft,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compareRow(
    ThemeData theme,
    String label,
    String name,
    String? feature,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tag(theme, label, AppColors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleMedium),
              if (feature != null && feature.isNotEmpty)
                Text(feature, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tag(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
