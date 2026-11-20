import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/knowledge_item.dart';
import '../providers/study_provider.dart';
import '../providers/theme_controller.dart';
import '../widgets/item_card.dart';
import '../widgets/tts_sheet.dart';

class Tab1SheetPage extends StatefulWidget {
  const Tab1SheetPage({super.key});

  @override
  State<Tab1SheetPage> createState() => _Tab1SheetPageState();
}

class _Tab1SheetPageState extends State<Tab1SheetPage> {
  final _search = TextEditingController();
  var _searchOpen = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProvider>();
    final themeController = context.watch<ThemeController>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: study.loading
            ? const Center(child: CircularProgressIndicator())
            : study.error != null
            ? _errorView(study, theme)
            : RefreshIndicator(
                onRefresh: study.load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      titleSpacing: 16,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('一页纸'),
                          Text(
                            '${study.filteredItems.length} / ${study.items.length} 条',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      actions: [
                        IconButton(
                          tooltip: study.maskMode ? '关闭遮罩' : '开启遮罩',
                          onPressed: study.toggleMaskMode,
                          icon: Icon(
                            study.maskMode
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: study.maskMode
                                ? const Color(0xFFD97706)
                                : null,
                          ),
                        ),
                        IconButton(
                          tooltip: '切换主题',
                          onPressed: themeController.toggle,
                          icon: Icon(
                            theme.brightness == Brightness.dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                        ),
                        IconButton(
                          tooltip: '搜索',
                          onPressed: () {
                            setState(() => _searchOpen = !_searchOpen);
                            if (!_searchOpen) {
                              _search.clear();
                              study.setQuery('');
                            }
                          },
                          icon: Icon(
                            _searchOpen ? Icons.search_off : Icons.search,
                          ),
                        ),
                      ],
                    ),
                    if (_searchOpen)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: TextField(
                            controller: _search,
                            autofocus: true,
                            onChanged: study.setQuery,
                            decoration: InputDecoration(
                              hintText: '搜索题干、结论、口诀、备注',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _search.clear();
                                        study.setQuery('');
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(child: _filters(study)),
                    if (study.filteredItems.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _emptyView(study),
                      )
                    else
                      SliverList.builder(
                        itemCount: study.filteredItems.length,
                        itemBuilder: (context, index) =>
                            ItemCard(item: study.filteredItems[index]),
                      ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTts(study),
        icon: const Icon(Icons.headphones),
        label: const Text('磨耳朵'),
      ),
    );
  }

  void _openTts(StudyProvider study) {
    final items = study.filteredItems;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前筛选没有可朗读的条目')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TtsSheet(items: items),
    );
  }

  Widget _filters(StudyProvider study) {
    final theme = Theme.of(context);
    final round2 = study.items.where((item) => item.isRound2Focus).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              _chip(
                label: '全部',
                selected: study.subject == null,
                onTap: () => study.setSubject(null),
              ),
              for (final subject in Subject.values)
                _chip(
                  label:
                      '${subject.label} ${study.subjectCounts[subject] ?? 0}',
                  selected: study.subject == subject,
                  onTap: () => study.setSubject(subject),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              _statusChip(
                study,
                label: '全量',
                value: StatusFilter.all,
                count: study.items.length,
              ),
              _statusChip(
                study,
                label: '仅标星',
                value: StatusFilter.starred,
                count: study.starredCount,
              ),
              _statusChip(
                study,
                label: '仅模糊',
                value: StatusFilter.fuzzy,
                count: study.fuzzyCount,
              ),
              _statusChip(
                study,
                label: '二轮冲刺',
                value: StatusFilter.round2,
                count: round2,
              ),
            ],
          ),
        ),
        if (study.maskMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.visibility_off,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text('遮罩模式：先回忆，再点琥珀色块揭晓', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _statusChip(
    StudyProvider study, {
    required String label,
    required StatusFilter value,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label $count'),
        selected: study.statusFilter == value,
        showCheckmark: false,
        onSelected: (_) => study.setStatusFilter(value),
      ),
    );
  }

  Widget _emptyView(StudyProvider study) {
    final theme = Theme.of(context);
    final hasFilter =
        study.subject != null ||
        study.statusFilter != StatusFilter.all ||
        study.query.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilter ? Icons.filter_alt_off_outlined : Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter ? '没有符合条件的条目' : '一页纸为空',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter ? '试试切换科目、状态或清除搜索。' : '请到作战室导入 .md，或恢复内置一页纸。',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _errorView(StudyProvider study, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('一页纸加载失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              study.error ?? '',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: study.load, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
