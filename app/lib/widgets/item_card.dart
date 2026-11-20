import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/knowledge_item.dart';
import '../providers/study_provider.dart';
import '../theme/app_theme.dart';
import 'item_edit_sheet.dart';

class ItemCard extends StatefulWidget {
  const ItemCard({super.key, required this.item});

  final KnowledgeItem item;

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  var _mnemonicOpen = false;

  KnowledgeItem get item => widget.item;

  bool _revealed(StudyProvider study, String field) =>
      !study.maskMode || study.isRevealed(item.id, field);

  bool _answerRevealed(StudyProvider study) {
    if (!study.maskMode) return true;
    return switch (item.cardType) {
      CardType.mapping => study.isRevealed(item.id, 'answer'),
      CardType.trueFalse => study.isRevealed(item.id, 'verdict'),
      CardType.pair =>
        study.isRevealed(item.id, 'a') && study.isRevealed(item.id, 'b'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onLongPress: _edit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _tag(theme, item.subject.label, AppColors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.chapter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (item.isRound2Focus) _tag(theme, '二轮', AppColors.amber),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => study.toggleStar(item.id),
                      icon: Icon(
                        item.isStarred ? Icons.star : Icons.star_border,
                        size: 22,
                        color: item.isStarred
                            ? AppColors.amber
                            : AppColors.muted(theme.brightness),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _body(study, theme, isDark),
                if (item.explanation.isNotEmpty && _answerRevealed(study)) ...[
                  const SizedBox(height: 8),
                  Text(
                    '解析：${item.explanation}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (item.mnemonic.isNotEmpty && _answerRevealed(study)) ...[
                  const SizedBox(height: 8),
                  _mnemonic(theme),
                ],
                const SizedBox(height: 6),
                const Divider(height: 12),
                _actions(study, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(StudyProvider study, ThemeData theme, bool isDark) {
    switch (item.cardType) {
      case CardType.mapping:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.prompt, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _masked(
                    study,
                    item.answer,
                    'answer',
                    theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        );
      case CardType.trueFalse:
        final correct = item.isTrue == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.prompt, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            if (_revealed(study, 'verdict'))
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: correct ? AppColors.greenSoft : AppColors.redSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  correct ? '对' : '错',
                  style: TextStyle(
                    color: correct ? AppColors.green : AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              _maskBlock(study, 'verdict', '对 / 错？', isDark),
          ],
        );
      case CardType.pair:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pairRow(
              study,
              theme,
              isDark,
              'A',
              item.prompt,
              item.pairAFeature,
              'a',
            ),
            const SizedBox(height: 8),
            _pairRow(
              study,
              theme,
              isDark,
              'B',
              item.answer,
              item.pairBFeature,
              'b',
            ),
          ],
        );
    }
  }

  Widget _pairRow(
    StudyProvider study,
    ThemeData theme,
    bool isDark,
    String label,
    String name,
    String? feature,
    String field,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · $name',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (feature != null && feature.isNotEmpty) ...[
          const SizedBox(height: 4),
          _masked(study, feature, field, theme.textTheme.bodyMedium, isDark),
        ],
      ],
    );
  }

  Widget _masked(
    StudyProvider study,
    String text,
    String field,
    TextStyle? style,
    bool isDark,
  ) {
    if (_revealed(study, field)) {
      return InkWell(
        onTap: study.maskMode ? () => study.toggleReveal(item.id, field) : null,
        child: Text(text, style: style),
      );
    }
    return _maskBlock(study, field, '点击揭晓', isDark);
  }

  Widget _maskBlock(
    StudyProvider study,
    String field,
    String label,
    bool isDark,
  ) {
    final color = isDark
        ? AppColors.amber.withValues(alpha: 0.22)
        : AppColors.amberSoft;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => study.toggleReveal(item.id, field),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.amber,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _mnemonic(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActionChip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.lightbulb_outline, size: 16),
          label: const Text('口诀'),
          backgroundColor: AppColors.blueSoft,
          side: BorderSide.none,
          onPressed: () => setState(() => _mnemonicOpen = !_mnemonicOpen),
        ),
        if (_mnemonicOpen)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              item.mnemonic,
              style: const TextStyle(color: AppColors.blue, height: 1.5),
            ),
          ),
      ],
    );
  }

  Widget _actions(StudyProvider study, ThemeData theme) {
    return Row(
      children: [
        _action(
          theme,
          icon: Icons.check_circle_outline,
          label: '眼熟',
          active: item.status == StudyStatus.familiar,
          color: AppColors.green,
          onTap: () => study.toggleStatus(item.id, StudyStatus.familiar),
        ),
        _action(
          theme,
          icon: Icons.blur_on,
          label: '模糊',
          active: item.status == StudyStatus.fuzzy,
          color: AppColors.amber,
          onTap: () => study.toggleStatus(item.id, StudyStatus.fuzzy),
        ),
        _action(
          theme,
          icon: Icons.star_border,
          label: '标星',
          active: item.isStarred,
          color: AppColors.blue,
          onTap: () => study.toggleStar(item.id),
        ),
      ],
    );
  }

  Widget _action(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    final inactive = AppColors.muted(theme.brightness);
    return Expanded(
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: active ? color : inactive,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: active ? color : inactive),
        label: Text(label, style: TextStyle(fontSize: 12)),
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

  Future<void> _edit() async {
    final updated = await showItemEditSheet(context, item);
    if (!mounted || updated == null) return;
    await context.read<StudyProvider>().updateItem(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存到本机')));
  }
}
