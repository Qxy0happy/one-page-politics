import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/knowledge_item.dart';
import '../providers/study_provider.dart';
import '../services/reflex_service.dart';
import '../theme/app_theme.dart';
import 'reflex/calc_session_page.dart';
import 'reflex/mapping_session_page.dart';
import 'reflex/pair_session_page.dart';
import 'reflex/true_false_session_page.dart';

class Tab2ReflexPage extends StatelessWidget {
  const Tab2ReflexPage({super.key});

  static final _service = ReflexService();

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProvider>();
    final theme = Theme.of(context);
    final trueFalseCount = _service.availableCount(
      study.items,
      CardType.trueFalse,
    );
    final mappingCount = _service.availableCount(study.items, CardType.mapping);
    final pairCount = _service.availableCount(study.items, CardType.pair);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Text('反射场', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '四种微训练：是非滑卡、帽子配对、双胞胎辨析、政经计算器。'
              '判错会把条目置为模糊；判对只增加复习次数。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _modeCard(
              theme,
              icon: Icons.swipe,
              title: '是非滑卡',
              subtitle: '左滑判错 · 右滑判对；错题回炉一次。',
              count: trueFalseCount,
              enabled: trueFalseCount > 0,
              onTap: () => _startTrueFalse(context, study),
            ),
            _modeCard(
              theme,
              icon: Icons.grid_view,
              title: '帽子配对',
              subtitle: '每批 4 组，左题右答；至少需要 4 条配对。',
              count: mappingCount,
              enabled: mappingCount >= ReflexService.mappingBatch,
              onTap: () => _startMapping(context, study),
            ),
            _modeCard(
              theme,
              icon: Icons.compare_arrows,
              title: '双胞胎辨析',
              subtitle: '随机问一侧特征，A/B 二选一；需要两侧特征齐全。',
              count: pairCount,
              enabled: pairCount > 0,
              onTap: () => _startPair(context, study),
            ),
            _modeCard(
              theme,
              icon: Icons.calculate_outlined,
              title: '政经计算器',
              subtitle: '利润 / 剩余价值率；纯算法生成，不依赖题库。',
              count: 0,
              showCount: false,
              enabled: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CalcSessionPage(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blueSoft.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '题源：当前 ${study.items.length} 条一页纸。'
                '选题优先模糊与标星，其次未看，最后眼熟；'
                '同一优先级内复习次数少的先出。',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTrueFalse(BuildContext context, StudyProvider study) {
    final queue = _service.buildQueue(study.items, CardType.trueFalse);
    if (queue.isEmpty) {
      _empty(context, '没有可用于是非判断的条目');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrueFalseSessionPage(initialQueue: queue),
      ),
    );
  }

  void _startMapping(BuildContext context, StudyProvider study) {
    final queue = _service.buildQueue(study.items, CardType.mapping);
    if (queue.length < ReflexService.mappingBatch) {
      _empty(context, '至少需要 4 条配对条目');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MappingSessionPage(initialQueue: queue),
      ),
    );
  }

  void _startPair(BuildContext context, StudyProvider study) {
    final queue = _service.buildQueue(study.items, CardType.pair);
    if (queue.isEmpty) {
      _empty(context, '没有两侧特征齐全的对比条目');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PairSessionPage(initialQueue: queue),
      ),
    );
  }

  void _empty(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _modeCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
    required bool enabled,
    required VoidCallback onTap,
    bool showCount = true,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.amberSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (showCount)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$count',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.amber,
                        ),
                      ),
                      Text('条', style: theme.textTheme.bodySmall),
                    ],
                  ),
                if (enabled)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.chevron_right),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
