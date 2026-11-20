import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../services/calc_generator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/session_summary.dart';

enum CalcMode { profit, surplus, mixed }

class CalcSessionPage extends StatefulWidget {
  const CalcSessionPage({super.key});

  @override
  State<CalcSessionPage> createState() => _CalcSessionPageState();
}

class _CalcSessionPageState extends State<CalcSessionPage> {
  static const _sessionSize = 15;

  final _random = Random();
  final _generator = CalcGenerator();
  final _controller = TextEditingController();
  var _mode = CalcMode.mixed;
  late CalcQuestion _question;
  var _index = 0;
  var _correct = 0;
  var _wrong = 0;
  var _answered = false;
  bool? _lastCorrect;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _question = _generate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CalcQuestion _generate() {
    final type = switch (_mode) {
      CalcMode.profit => CalcQuestionType.profit,
      CalcMode.surplus => CalcQuestionType.surplusRate,
      CalcMode.mixed =>
        _random.nextBool()
            ? CalcQuestionType.profit
            : CalcQuestionType.surplusRate,
    };
    return _generator.next(type);
  }

  void _submit() {
    if (_answered) return;
    final value = double.tryParse(_controller.text.trim());
    if (value == null) {
      setState(() => _inputError = '请输入数字');
      return;
    }
    final tolerance = _question.type == CalcQuestionType.profit ? 0.01 : 0.1;
    final correct = (value - _question.answer).abs() <= tolerance;
    FocusScope.of(context).unfocus();
    setState(() {
      _answered = true;
      _lastCorrect = correct;
      _inputError = null;
      if (correct) {
        _correct++;
      } else {
        _wrong++;
      }
    });
  }

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= _sessionSize) {
      setState(() => _index = _sessionSize);
      return;
    }
    setState(() {
      _index++;
      _question = _generate();
      _controller.clear();
      _answered = false;
      _lastCorrect = null;
      _inputError = null;
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _correct = 0;
      _wrong = 0;
      _answered = false;
      _lastCorrect = null;
      _inputError = null;
      _controller.clear();
      _question = _generate();
    });
  }

  void _changeMode(CalcMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _index = 0;
      _correct = 0;
      _wrong = 0;
      _answered = false;
      _lastCorrect = null;
      _inputError = null;
      _controller.clear();
      _question = _generate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_index >= _sessionSize) {
      return Scaffold(
        appBar: AppBar(title: const Text('政经计算器')),
        body: SessionSummary(
          title: '计算结束',
          correct: _correct,
          wrong: _wrong,
          onRestart: _restart,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('政经计算器'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_index + 1}/$_sessionSize',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            SegmentedButton<CalcMode>(
              segments: const [
                ButtonSegment(value: CalcMode.profit, label: Text('利润')),
                ButtonSegment(value: CalcMode.surplus, label: Text('剩余价值率')),
                ButtonSegment(value: CalcMode.mixed, label: Text('混合')),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => _changeMode(value.first),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('题目', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text(_question.prompt, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_answered,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '答案',
                hintText: '输入数字',
                errorText: _inputError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (!_answered)
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text('提交'),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _lastCorrect == true
                      ? AppColors.greenSoft
                      : AppColors.redSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lastCorrect == true ? '回答正确' : '回答错误',
                      style: TextStyle(
                        color: _lastCorrect == true
                            ? AppColors.green
                            : AppColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '正确答案：${_format(_question.answer)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _question.explanation,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('下一题'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _format(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
