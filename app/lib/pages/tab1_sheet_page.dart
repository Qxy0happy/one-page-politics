import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/knowledge_item.dart';
import '../models/sheet_path.dart';
import '../providers/study_provider.dart';
import '../providers/theme_controller.dart';
import '../widgets/item_card.dart';
import '../widgets/path_tree_sheet.dart';
import '../widgets/tts_sheet.dart';

class Tab1SheetPage extends StatefulWidget {
  const Tab1SheetPage({super.key});

  @override
  State<Tab1SheetPage> createState() => _Tab1SheetPageState();
}

class _Tab1SheetPageState extends State<Tab1SheetPage> {
  final _search = TextEditingController();
  Timer? _searchTimer;
  var _searchOpen = false;

  @override
  void dispose() {
    _searchTimer?.cancel();
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
                          onPressed: () => _toggleSearch(study),
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
                            onChanged: (value) =>
                                _onSearchChanged(study, value),
                            decoration: InputDecoration(
                              hintText: study.path.isRoot
                                  ? '搜索题干、结论、口诀、备注'
                                  : '在 ${study.pathLabel} 中搜索',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () => _clearSearch(study),
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

  void _toggleSearch(StudyProvider study) {
    if (_searchOpen) {
      _closeSearch(study);
    } else {
      setState(() => _searchOpen = true);
    }
  }

  void _onSearchChanged(StudyProvider study, String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(
      const Duration(milliseconds: 200),
      () => study.setQuery(value),
    );
    setState(() {});
  }

  void _clearSearch(StudyProvider study) {
    _searchTimer?.cancel();
    _search.clear();
    study.setQuery('');
    setState(() {});
  }

  void _closeSearch(StudyProvider study) {
    _searchTimer?.cancel();
    _search.clear();
    study.setQuery('');
    setState(() => _searchOpen = false);
  }

  Future<void> _openPathTree(StudyProvider study) async {
    final selected = await showModalBottomSheet<SheetPath>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: PathTreeSheet(tree: study.sheetTree, current: study.path),
      ),
    );
    if (!mounted || selected == null) return;
    await study.setPath(selected);
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
    final counts = study.statusCounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _pathBar(study),
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
                count: counts[StatusFilter.all] ?? 0,
              ),
              _statusChip(
                study,
                label: '仅标星',
                value: StatusFilter.starred,
                count: counts[StatusFilter.starred] ?? 0,
              ),
              _statusChip(
                study,
                label: '仅模糊',
                value: StatusFilter.fuzzy,
                count: counts[StatusFilter.fuzzy] ?? 0,
              ),
              _statusChip(
                study,
                label: '二轮冲刺',
                value: StatusFilter.round2,
                count: counts[StatusFilter.round2] ?? 0,
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

  Widget _pathBar(StudyProvider study) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('sheetPathBar'),
      color: theme.colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: () => _openPathTree(study),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  study.pathLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (!study.path.isRoot)
                IconButton(
                  tooltip: '回到全部',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () => study.setPath(SheetPath.root),
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              Icon(Icons.expand_more, color: theme.textTheme.bodySmall?.color),
            ],
          ),
        ),
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
    final query = study.query.trim();
    final hasQuery = query.isNotEmpty;
    final hasPath = !study.path.isRoot;
    final hasStatus = study.statusFilter != StatusFilter.all;
    final hasFilter = hasQuery || hasPath || hasStatus;
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
            hasQuery
                ? '「$query」在 ${hasPath ? study.pathLabel : "全部路径"} 中没有命中。'
                : hasFilter
                ? '试试切换路径、状态或清除搜索。'
                : '请到作战室导入 .md，或恢复内置一页纸。',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (hasFilter) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (hasQuery && hasPath)
                  FilledButton.tonal(
                    onPressed: () => study.setPath(SheetPath.root),
                    child: const Text('在全部中搜索'),
                  ),
                if (hasQuery)
                  TextButton(
                    onPressed: () => _clearSearch(study),
                    child: const Text('清除搜索'),
                  ),
                if (!hasQuery && hasPath)
                  TextButton(
                    onPressed: () => study.setPath(SheetPath.root),
                    child: const Text('回到全部路径'),
                  ),
                if (!hasQuery && hasStatus)
                  TextButton(
                    onPressed: () => study.setStatusFilter(StatusFilter.all),
                    child: const Text('清除状态筛选'),
                  ),
              ],
            ),
          ],
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
