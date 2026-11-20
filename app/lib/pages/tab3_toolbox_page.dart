import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/toolbox_seed_data.dart';
import '../models/toolbox_models.dart';
import '../theme/app_theme.dart';

class Tab3ToolboxPage extends StatefulWidget {
  const Tab3ToolboxPage({super.key});

  @override
  State<Tab3ToolboxPage> createState() => _Tab3ToolboxPageState();
}

class _Tab3ToolboxPageState extends State<Tab3ToolboxPage> {
  var _segment = 0;
  final _tombstoneSearch = TextEditingController();
  final _threeInOne = TextEditingController();

  @override
  void dispose() {
    _tombstoneSearch.dispose();
    _threeInOne.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text('工具箱', style: theme.textTheme.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('选择题兵法'),
                    icon: Icon(Icons.checklist),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('大题与抄材料'),
                    icon: Icon(Icons.edit_note),
                  ),
                ],
                selected: {_segment},
                onSelectionChanged: (value) =>
                    setState(() => _segment = value.first),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _segment == 0
                  ? _choiceView(theme)
                  : _bigQuestionView(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceView(ThemeData theme) {
    final query = _tombstoneSearch.text.trim().toLowerCase();
    final categories = tombstoneCategories
        .where((category) {
          if (query.isEmpty) return true;
          final haystack = [
            category.name,
            category.words.join(' '),
            category.strategy,
            category.boundary,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        _whiteListCard(theme),
        const SizedBox(height: 10),
        for (final strategy in choiceStrategies) ...[
          Card(
            child: ExpansionTile(
              title: Text(strategy.title),
              subtitle: Text('${strategy.points.length} 条'),
              children: [
                for (final point in strategy.points)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.chevron_right, size: 18),
                    title: Text(point),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Text('墓碑词红黑榜', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        TextField(
          controller: _tombstoneSearch,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '搜索词、类型或处理策略',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        for (final category in categories) ...[
          _tombstoneTile(theme, category),
          const SizedBox(height: 8),
        ],
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '没有匹配的墓碑词。',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _whiteListCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: AppColors.green),
              const SizedBox(width: 8),
              Text(
                '白名单与反例警示区',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final note in whiteListNotes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $note',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF14532D),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tombstoneTile(ThemeData theme, TombstoneCategory category) {
    return Card(
      child: ExpansionTile(
        title: Text(category.name),
        subtitle: Text(
          category.words.join('、'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('处理：${category.strategy}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text('边界：${category.boundary}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _bigQuestionView(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        Text('十二＋一角度', style: theme.textTheme.titleLarge),
        Text('口诀：党理制度史文实诚人需环卫，再加“问题”', style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final angle in bigQuestionAngles)
              ActionChip(
                label: Text(angle.label),
                onPressed: () => _showAngle(angle),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text('三位一体句式转换器', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _threeInOne,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '输入一个短词，如“高质量发展”',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final word in const ['高质量发展', '制度型开放', '共同富裕'])
              ActionChip(
                label: Text(word),
                onPressed: () {
                  _threeInOne.text = word;
                  setState(() {});
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        _threeInOneCard(theme),
        const SizedBox(height: 18),
        Text('通用框架', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final card in frameworkCards) ...[
          Card(
            child: ExpansionTile(
              title: Text(card.title),
              children: [
                for (final line in card.lines)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.chevron_right, size: 18),
                    title: Text(line),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Text('分科目大题口袋卡', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final pocket in subjectPocketCards) ...[
          Card(
            child: ExpansionTile(
              title: Text(pocket.subject),
              children: [
                for (final line in pocket.sections)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.chevron_right, size: 18),
                    title: Text(line),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('总原则与评分预期', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                for (final line in bigQuestionReminders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('· $line', style: theme.textTheme.bodyMedium),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _threeInOneCard(ThemeData theme) {
    final word = _threeInOne.text.trim();
    final enabled = word.isNotEmpty;
    final lines = <(String, String)>[
      ('原因', enabled ? '$word是……的必然要求／必然选择' : '先输入一个短词'),
      ('意义', enabled ? '有助于$word的推进。' : '先输入一个短词'),
      ('措施', enabled ? '我们要坚持$word，……' : '先输入一个短词'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines) ...[
              Row(
                children: [
                  _tag(theme, line.$1, AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(line.$2, style: theme.textTheme.bodyMedium),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '复制',
                    onPressed: enabled
                        ? () {
                            Clipboard.setData(ClipboardData(text: line.$2));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制')),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
              if (line != lines.last) const Divider(height: 16),
            ],
          ],
        ),
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

  void _showAngle(BigQuestionAngle angle) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(angle.label, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(angle.usage, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
