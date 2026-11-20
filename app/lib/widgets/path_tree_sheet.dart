import 'package:material_ui/material_ui.dart';

import '../models/sheet_path.dart';
import '../services/sheet_tree_service.dart';

String sheetPathId(SheetPath path) =>
    '${path.subject?.name ?? ''}/${path.chapter ?? ''}/${path.cardType?.name ?? ''}';

Key sheetPathRowKey(SheetPath path) =>
    ValueKey('path-row-${sheetPathId(path)}');

Key sheetPathExpandKey(SheetPath path) =>
    ValueKey('path-expand-${sheetPathId(path)}');

class PathTreeSheet extends StatelessWidget {
  const PathTreeSheet({super.key, required this.tree, required this.current});

  final SheetNode tree;
  final SheetPath current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('pathTreeSheet'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
          child: Row(
            children: [
              Text('选择路径', style: theme.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              _PathRow(
                node: tree,
                current: current,
                depth: 0,
                onTap: () => Navigator.of(context).pop(tree.path),
              ),
              Divider(
                height: 8,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              for (final subject in tree.children)
                _PathNodeTile(node: subject, current: current, depth: 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _PathNodeTile extends StatefulWidget {
  const _PathNodeTile({
    required this.node,
    required this.current,
    required this.depth,
  });

  final SheetNode node;
  final SheetPath current;
  final int depth;

  @override
  State<_PathNodeTile> createState() => _PathNodeTileState();
}

class _PathNodeTileState extends State<_PathNodeTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded =
        widget.current != widget.node.path &&
        widget.current.isUnder(widget.node.path);
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    return Column(
      children: [
        _PathRow(
          node: node,
          current: widget.current,
          depth: widget.depth,
          onTap: () => Navigator.of(context).pop(node.path),
          trailing: node.hasChildren
              ? IconButton(
                  key: sheetPathExpandKey(node.path),
                  tooltip: _expanded ? '收起' : '展开',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                )
              : null,
        ),
        if (_expanded)
          for (final child in node.children)
            _PathNodeTile(
              node: child,
              current: widget.current,
              depth: widget.depth + 1,
            ),
      ],
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.node,
    required this.current,
    required this.depth,
    required this.onTap,
    this.trailing,
  });

  final SheetNode node;
  final SheetPath current;
  final int depth;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = current == node.path;
    final muted = theme.textTheme.bodySmall?.color;
    final highlight = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.24 : 0.14,
    );

    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: EdgeInsets.only(left: depth * 16.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: sheetPathRowKey(node.path),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: selected ? highlight : null,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Icon(
                    _iconFor(node.path),
                    size: 20,
                    color: selected ? theme.colorScheme.primary : muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: selected ? theme.colorScheme.primary : null,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          node.progress.summary,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  if (trailing != null) trailing! else const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(SheetPath path) {
    if (path.isRoot) return Icons.all_inbox_outlined;
    if (path.cardType != null) return Icons.label_outline;
    if (path.chapter != null) return Icons.article_outlined;
    return Icons.folder_outlined;
  }
}
