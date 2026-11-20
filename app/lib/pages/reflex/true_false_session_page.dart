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

class TrueFalseSessionPage extends StatefulWidget {
  const TrueFalseSessionPage({super.key, required this.initialQueue});

  final List<KnowledgeItem> initialQueue;

  @override
  State<TrueFalseSessionPage> createState() => _TrueFalseSessionPageState();
}

class _TrueFalseSessionPageState extends State<TrueFalseSessionPage> {
  late List<KnowledgeItem> _queue;
  final Set<String> _requeued = {};
  var _index = 0;
  var _correct = 0;
  var _wrong = 0;
  var _showAnswer = false;
  bool? _lastCorrect;
  double _dragX = 0;

  @override
  void initState() {
    super.initState();
    _queue = List.of(widget.initialQueue);
  }

  bool get _finished => _index >= _queue.length;

  void _answer(bool saysTrue) {
    if (_finished || _showAnswer) return;
    final item = _queue[_index];
    final correct = (item.isTrue == true) == saysTrue;
    setState(() {
      _showAnswer = true;
      _lastCorrect = correct;
      if (correct) {
        _correct++;
      } else {
        _wrong++;
        if (_requeued.add(item.id)) _queue.add(item);
      }
      _dragX = 0;
    });
    unawaited(
      context.read<StudyProvider>().recordJudgement(item.id, correct: correct),
    );
    if (correct) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _next();
      });
    } else {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      _index++;
      _showAnswer = false;
      _lastCorrect = null;
      _dragX = 0;
    });
  }

  void _restart() {
    final study = context.read<StudyProvider>();
    final queue = ReflexService().buildQueue(study.items, CardType.trueFalse);
    if (queue.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _queue = queue;
      _index = 0;
      _correct = 0;
      _wrong = 0;
      _showAnswer = false;
      _lastCorrect = null;
      _dragX = 0;
      _requeued.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('是非滑卡')),
        body: SessionSummary(
          title: '本局结束',
          correct: _correct,
          wrong: _wrong,
          onRestart: _restart,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    }

    final item = _queue[_index];
    return Scaffold(
      appBar: AppBar(
        title: const Text('是非滑卡'),
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
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.min(constraints.maxWidth - 32, 520.0);
                  return Center(
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        if (_showAnswer) return;
                        setState(() {
                          _dragX = (_dragX + details.delta.dx).clamp(
                            -width * 0.6,
                            width * 0.6,
                          );
                        });
                      },
                      onPanEnd: (details) {
                        if (_showAnswer) return;
                        final velocity = details.velocity.pixelsPerSecond.dx;
                        if (_dragX > width * 0.25 || velocity > 800) {
                          _answer(true);
                        } else if (_dragX < -width * 0.25 || velocity < -800) {
                          _answer(false);
                        } else {
                          setState(() => _dragX = 0);
                        }
                      },
                      child: Transform.translate(
                        offset: Offset(_dragX, 0),
                        child: Transform.rotate(
                          angle: _dragX / width * 0.12,
                          child: SizedBox(
                            width: width,
                            child: _card(theme, item),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: _showAnswer
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _next,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('下一张'),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _judgeButton(
                            theme,
                            label: '错',
                            icon: Icons.close,
                            color: AppColors.red,
                            onTap: () => _answer(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _judgeButton(
                            theme,
                            label: '对',
                            icon: Icons.check,
                            color: AppColors.green,
                            onTap: () => _answer(true),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, KnowledgeItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                if (item.isRound2Focus) _tag(theme, '二轮', AppColors.amber),
              ],
            ),
            const SizedBox(height: 22),
            Text(item.prompt, style: theme.textTheme.titleLarge),
            const SizedBox(height: 22),
            if (_showAnswer) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastCorrect == true
                      ? AppColors.greenSoft
                      : AppColors.redSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _lastCorrect == true
                      ? '判断正确'
                      : '判断错误；正确答案是「${item.isTrue == true ? '对' : '错'}」',
                  style: TextStyle(
                    color: _lastCorrect == true
                        ? AppColors.green
                        : AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.explanation.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '解析：${item.explanation}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ] else
              Text('左滑判错 · 右滑判对', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _judgeButton(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 18)),
      ),
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
