import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/exam_record.dart';
import '../providers/study_provider.dart';
import '../providers/war_room_provider.dart';
import '../services/md_exporter.dart';
import '../services/md_parser_service.dart';
import '../services/merge_service.dart';
import '../services/study_timer.dart';
import '../theme/app_theme.dart';
import '../widgets/exam_record_dialog.dart';
import '../widgets/score_line_chart.dart';

class Tab4WarRoomPage extends StatefulWidget {
  const Tab4WarRoomPage({super.key});

  @override
  State<Tab4WarRoomPage> createState() => _Tab4WarRoomPageState();
}

class _Tab4WarRoomPageState extends State<Tab4WarRoomPage> {
  static const _syntax = '''
# 科目
## 章节
- [配对] 帽子或题干 == 核心结论 | 口诀: 可选 | 解析: 可选 | 墓碑词: 词1,词2 | 备注: 原文如此 #二轮 #配对
- [对] 正确原话 | 解析: 为什么对
- [错] 常见错项 | 解析: 正确说法 | 墓碑词: 绝对化词
- [对比] 概念A（核心特征） <> 概念B（核心特征） | 口诀: 可选 #二轮

规则：
- # 标题只能取 马原 / 史纲 / 思修 / 新思想 / 时政。
- 每条以 “- ” 开头；非 “- ” 开头行忽略。
- 行尾 #二轮 表示二轮重点；#配对 表示可进入 4×4 配对训练。
- 导入按 id 增量合并，不删除现有条目；手改内容默认保留。
- 导出文件带 id，可再次导入并命中同一条目。''';

  @override
  Widget build(BuildContext context) {
    final war = context.watch<WarRoomProvider>();
    final study = context.watch<StudyProvider>();
    final theme = Theme.of(context);

    if (war.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Text('作战室', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '节奏、真题与数据管理。计时按墙钟走，切到后台也会继续。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _timerCard(theme, war, war.methodTimer)),
                const SizedBox(width: 10),
                Expanded(child: _timerCard(theme, war, war.sheetTimer)),
              ],
            ),
            const SizedBox(height: 10),
            _passCard(theme, war),
            const SizedBox(height: 18),
            _examHeader(theme, study, war),
            const SizedBox(height: 8),
            if (war.records.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    '还没有真题记录。先记一套卷，折线图会按日期画出 35/40 参考线。',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                  child: ScoreLineChart(records: war.chartRecords),
                ),
              ),
              const SizedBox(height: 8),
              for (final record in war.records) _recordCard(theme, war, record),
            ],
            const SizedBox(height: 18),
            _dataSection(theme, study, war),
          ],
        ),
      ),
    );
  }

  Widget _timerCard(ThemeData theme, WarRoomProvider war, StudyTimer timer) {
    final progress = timer.duration.inMilliseconds == 0
        ? 0.0
        : (1 - timer.remaining.inMilliseconds / timer.duration.inMilliseconds)
              .clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timer.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                timer.formatted,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    if (timer.isRunning) {
                      war.pauseTimer(timer);
                    } else {
                      war.startTimer(timer);
                    }
                  },
                  icon: Icon(
                    timer.isRunning ? Icons.pause : Icons.play_arrow,
                    size: 20,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => war.resetTimer(timer),
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            if (timer.isCompleted)
              Text(
                '今日政治时间已够，请把精力留给数学/英语/专业课。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _passCard(ThemeData theme, WarRoomProvider war) {
    final last = war.lastPass;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('一页纸已过遍数', style: theme.textTheme.bodySmall),
                Text(
                  '${war.passCount}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                last == null ? '还没有打卡记录' : '上次：${_date(last)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: war.addPass,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('+1 记一遍'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _examHeader(
    ThemeData theme,
    StudyProvider study,
    WarRoomProvider war,
  ) {
    return Row(
      children: [
        Expanded(child: Text('真题 / 模拟卷', style: theme.textTheme.titleLarge)),
        FilledButton.tonalIcon(
          onPressed: () => _addRecord(study, war),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('记一套卷'),
        ),
      ],
    );
  }

  Widget _recordCard(ThemeData theme, WarRoomProvider war, ExamRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(record.title),
        subtitle: Text(
          '${_date(record.date)} · 单选 ${record.singleCorrect}/16 · '
          '多选 ${record.multiCorrect}/17'
          '${record.linkedWrongItemIds.isEmpty ? '' : ' · 关联 ${record.linkedWrongItemIds.length} 条'}',
        ),
        leading: CircleAvatar(
          backgroundColor: record.totalScore >= 40
              ? AppColors.greenSoft
              : record.totalScore >= 35
              ? AppColors.amberSoft
              : AppColors.redSoft,
          child: Text(
            '${record.totalScore}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: record.totalScore >= 40
                  ? AppColors.green
                  : record.totalScore >= 35
                  ? AppColors.amber
                  : AppColors.red,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editRecord(context.read<StudyProvider>(), war, record);
            } else if (value == 'delete') {
              _deleteRecord(war, record);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ),
    );
  }

  Widget _dataSection(
    ThemeData theme,
    StudyProvider study,
    WarRoomProvider war,
  ) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: const Text('导入新版一页纸 (.md)'),
            subtitle: const Text('按 id 增量合并；不删除现有条目'),
            onTap: () => _import(study),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('导出当前一页纸'),
            subtitle: const Text('带 id，可再次导入；不导出学习进度'),
            onTap: () => _export(study),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('恢复内置一页纸'),
            subtitle: const Text('保留能按 id 匹配的进度；删除其它条目'),
            onTap: () => _restore(study),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('清空全部数据'),
            subtitle: const Text('进度、笔记、真题记录、计时器全部归零'),
            onTap: () => _clearAll(study, war),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('查看 MD 语法规范'),
            onTap: _showSyntax,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '当前 ${study.items.length} 条 · 模糊 ${study.fuzzyCount} 条 · '
                '标星 ${study.starredCount} 条 · 真题 ${war.records.length} 套',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addRecord(StudyProvider study, WarRoomProvider war) async {
    final record = await showExamRecordDialog(context, items: study.items);
    if (record == null) return;
    await war.addRecord(record);
    if (mounted) _snack('已保存；关联错题已标星');
  }

  Future<void> _editRecord(
    StudyProvider study,
    WarRoomProvider war,
    ExamRecord record,
  ) async {
    final updated = await showExamRecordDialog(
      context,
      items: study.items,
      existing: record,
    );
    if (updated == null) return;
    await war.addRecord(updated);
    if (mounted) _snack('已更新');
  }

  Future<void> _deleteRecord(WarRoomProvider war, ExamRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text('${record.title} · ${record.totalScore} 分'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await war.deleteRecord(record.id);
    if (mounted) _snack('已删除');
  }

  Future<void> _import(StudyProvider study) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['md'],
        dialogTitle: '选择一页纸 .md',
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      final parsed = MdParserService().parse(text);
      if (!parsed.isValid) {
        _showErrors(parsed.errors);
        return;
      }
      final preview = MergeService().merge(study.items, parsed.items);
      final override = await _confirmImport(preview);
      if (override == null || !mounted) return;
      final applied = await study.importItems(
        parsed.items,
        overrideLocalEdits: override,
      );
      if (mounted) {
        _snack(
          '导入完成：新增 ${applied.added}，更新 ${applied.updated}，'
          '保留本地 ${applied.keptLocal}，缺失 ${applied.missing}',
        );
      }
    } catch (error) {
      if (mounted) _snack('导入失败：$error');
    }
  }

  Future<bool?> _confirmImport(MergeResult preview) {
    var override = false;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('导入预览'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('新增 ${preview.added} 条'),
              Text('更新 ${preview.updated} 条'),
              Text('保留本地修改 ${preview.keptLocal} 条'),
              Text('现有但文件缺失 ${preview.missing} 条（会保留）'),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: override,
                onChanged: (value) => setState(() => override = value ?? false),
                title: const Text('覆盖手动编辑内容'),
                subtitle: const Text('默认保留长按改过的题干、答案与口诀'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(override),
              child: const Text('开始导入'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(StudyProvider study) async {
    try {
      final markdown = MdExporter().export(study.items);
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final uri = await FilePicker.saveFile(
        dialogTitle: '导出当前一页纸',
        fileName: 'one_page_politics_$date.md',
        mimeType: 'text/markdown',
        bytes: Uint8List.fromList(utf8.encode(markdown)),
      );
      if (uri != null && mounted) _snack('已导出：$uri');
    } catch (error) {
      if (mounted) _snack('导出失败：$error');
    }
  }

  Future<void> _restore(StudyProvider study) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复内置一页纸？'),
        content: const Text('会删除本地新增条目；能按 id 匹配的进度、标星与备注会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await study.restoreSeed();
      if (mounted) _snack('已恢复内置一页纸');
    } catch (error) {
      if (mounted) _snack('恢复失败：$error');
    }
  }

  Future<void> _clearAll(StudyProvider study, WarRoomProvider war) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部数据？'),
        content: const Text('进度、笔记、标星、真题记录、计时器与遍数都会归零。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('再次确认'),
        content: const Text('此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (second != true) return;
    try {
      await study.clearAll();
      await war.clearAll();
      if (mounted) _snack('已清空，内置一页纸已重新载入');
    } catch (error) {
      if (mounted) _snack('清空失败：$error');
    }
  }

  void _showErrors(List<String> errors) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入失败'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final error in errors.take(10))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showSyntax() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MD 语法规范'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Text(_syntax)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
