import 'package:material_ui/material_ui.dart';

import '../models/knowledge_item.dart';

Future<KnowledgeItem?> showItemEditSheet(
  BuildContext context,
  KnowledgeItem item,
) {
  return showModalBottomSheet<KnowledgeItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ItemEditSheet(item: item),
  );
}

class _ItemEditSheet extends StatefulWidget {
  const _ItemEditSheet({required this.item});

  final KnowledgeItem item;

  @override
  State<_ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<_ItemEditSheet> {
  late final TextEditingController _prompt;
  late final TextEditingController _answer;
  late final TextEditingController _explanation;
  late final TextEditingController _mnemonic;
  late final TextEditingController _pairA;
  late final TextEditingController _pairB;
  late final TextEditingController _sourceNote;
  late final TextEditingController _userNote;
  late bool _round2;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _prompt = TextEditingController(text: item.prompt);
    _answer = TextEditingController(text: item.answer);
    _explanation = TextEditingController(text: item.explanation);
    _mnemonic = TextEditingController(text: item.mnemonic);
    _pairA = TextEditingController(text: item.pairAFeature ?? '');
    _pairB = TextEditingController(text: item.pairBFeature ?? '');
    _sourceNote = TextEditingController(text: item.sourceNote);
    _userNote = TextEditingController(text: item.userNote);
    _round2 = item.isRound2Focus;
  }

  @override
  void dispose() {
    _prompt.dispose();
    _answer.dispose();
    _explanation.dispose();
    _mnemonic.dispose();
    _pairA.dispose();
    _pairB.dispose();
    _sourceNote.dispose();
    _userNote.dispose();
    super.dispose();
  }

  bool get _isPair => widget.item.cardType == CardType.pair;
  bool get _isTrueFalse => widget.item.cardType == CardType.trueFalse;

  void _save() {
    final prompt = _prompt.text.trim();
    final answer = _answer.text.trim();
    if (prompt.isEmpty) {
      setState(() => _validationError = '题干不能为空');
      return;
    }
    if (!_isTrueFalse && answer.isEmpty) {
      setState(() => _validationError = '结论不能为空');
      return;
    }
    if (_isPair && (_pairA.text.trim().isEmpty || _pairB.text.trim().isEmpty)) {
      setState(() => _validationError = '对比两侧的特征不能为空');
      return;
    }

    final item = widget.item;
    final contentChanged =
        prompt != item.prompt ||
        answer != item.answer ||
        _explanation.text.trim() != item.explanation ||
        _mnemonic.text.trim() != item.mnemonic ||
        _sourceNote.text.trim() != item.sourceNote ||
        _round2 != item.isRound2Focus ||
        (_isPair &&
            (_pairA.text.trim() != (item.pairAFeature ?? '') ||
                _pairB.text.trim() != (item.pairBFeature ?? '')));

    Navigator.of(context).pop(
      item.copyWith(
        prompt: prompt,
        answer: _isTrueFalse ? item.answer : answer,
        explanation: _explanation.text.trim(),
        mnemonic: _mnemonic.text.trim(),
        pairAFeature: _isPair ? _pairA.text.trim() : item.pairAFeature,
        pairBFeature: _isPair ? _pairB.text.trim() : item.pairBFeature,
        sourceNote: _sourceNote.text.trim(),
        isRound2Focus: _round2,
        userNote: _userNote.text.trim(),
        isCustomEdited: item.isCustomEdited || contentChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('编辑条目', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.item.subject.label} · ${widget.item.chapter} · ${widget.item.cardType.label}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _field('题干', _prompt, maxLines: 3),
            if (!_isTrueFalse) _field('结论', _answer, maxLines: 4),
            if (_isPair) ...[
              _field('A 的特征', _pairA, maxLines: 2),
              _field('B 的特征', _pairB, maxLines: 2),
            ],
            _field('解析', _explanation, maxLines: 3),
            _field('口诀', _mnemonic, maxLines: 2),
            _field('来源注记', _sourceNote, maxLines: 2),
            _field('个人备注', _userNote, maxLines: 3),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _round2,
              onChanged: (value) => setState(() => _round2 = value),
              title: const Text('二轮冲刺重点'),
            ),
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  _validationError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
