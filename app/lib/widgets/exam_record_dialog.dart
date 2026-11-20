import 'package:material_ui/material_ui.dart';

import '../models/exam_record.dart';
import '../models/knowledge_item.dart';

Future<ExamRecord?> showExamRecordDialog(
  BuildContext context, {
  required List<KnowledgeItem> items,
  ExamRecord? existing,
}) {
  return showDialog<ExamRecord>(
    context: context,
    builder: (_) => _ExamRecordDialog(items: items, existing: existing),
  );
}

class _ExamRecordDialog extends StatefulWidget {
  const _ExamRecordDialog({required this.items, this.existing});

  final List<KnowledgeItem> items;
  final ExamRecord? existing;

  @override
  State<_ExamRecordDialog> createState() => _ExamRecordDialogState();
}

class _ExamRecordDialogState extends State<_ExamRecordDialog> {
  late final TextEditingController _title;
  late final TextEditingController _single;
  late final TextEditingController _multi;
  late final TextEditingController _note;
  late DateTime _date;
  late Set<String> _linked;
  String? _error;

  @override
  void initState() {
    super.initState();
    final record = widget.existing;
    _title = TextEditingController(text: record?.title ?? '');
    _single = TextEditingController(text: '${record?.singleCorrect ?? 0}');
    _multi = TextEditingController(text: '${record?.multiCorrect ?? 0}');
    _note = TextEditingController(text: record?.note ?? '');
    _date = record?.date ?? DateTime.now();
    _linked = {...?record?.linkedWrongItemIds};
  }

  @override
  void dispose() {
    _title.dispose();
    _single.dispose();
    _multi.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickLinked() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemPicker(items: widget.items, selected: _linked),
    );
    if (result != null) setState(() => _linked = result);
  }

  void _save() {
    final title = _title.text.trim();
    final single = int.tryParse(_single.text.trim());
    final multi = int.tryParse(_multi.text.trim());
    if (title.isEmpty) {
      setState(() => _error = '套卷名称不能为空');
      return;
    }
    if (single == null || single < 0 || single > 16) {
      setState(() => _error = '单选对题数需在 0–16');
      return;
    }
    if (multi == null || multi < 0 || multi > 17) {
      setState(() => _error = '多选对题数需在 0–17');
      return;
    }
    final now = DateTime.now();
    Navigator.of(context).pop(
      ExamRecord(
        id: widget.existing?.id ?? now.microsecondsSinceEpoch.toString(),
        title: title,
        date: DateTime(_date.year, _date.month, _date.day),
        createdAt: widget.existing?.createdAt ?? now,
        singleCorrect: single,
        multiCorrect: multi,
        linkedWrongItemIds: _linked.toList(growable: false),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? '记一套卷' : '编辑记录'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: '套卷名称',
                  hintText: '如 2026 真题 / 模拟卷 1',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
                  '${_date.day.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _single,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '单选对题数',
                        hintText: '0–16',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _multi,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '多选对题数',
                        hintText: '0–17',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickLinked,
                icon: const Icon(Icons.link, size: 18),
                label: Text('关联错题（${_linked.length}）'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '备注',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

class _ItemPicker extends StatefulWidget {
  const _ItemPicker({required this.items, required this.selected});

  final List<KnowledgeItem> items;
  final Set<String> selected;

  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  final _search = TextEditingController();
  late final Set<String> _selected = {...widget.selected};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = widget.items
        .where((item) {
          if (query.isEmpty) return true;
          return '${item.prompt} ${item.answer} ${item.subject.label}'
              .toLowerCase()
              .contains(query);
        })
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '搜索条目',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text('完成 ${_selected.length}'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return CheckboxListTile(
                  dense: true,
                  value: _selected.contains(item.id),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selected.add(item.id);
                      } else {
                        _selected.remove(item.id);
                      }
                    });
                  },
                  title: Text(
                    item.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.subject.label} · ${item.chapter}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
