import 'package:material_ui/material_ui.dart';

import '../models/knowledge_item.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

class TtsSheet extends StatefulWidget {
  const TtsSheet({super.key, required this.items});

  final List<KnowledgeItem> items;

  @override
  State<TtsSheet> createState() => _TtsSheetState();
}

class _TtsSheetState extends State<TtsSheet> {
  late final TtsService _service;
  var _initializing = true;
  var _failed = false;
  var _previewing = false;

  @override
  void initState() {
    super.initState();
    _service = TtsService();
    _init();
  }

  Future<void> _init() async {
    final ok = await _service.init();
    if (!mounted) return;
    setState(() {
      _initializing = false;
      _failed = !ok;
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _service.close();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _preview() async {
    if (_previewing) return;
    setState(() => _previewing = true);
    try {
      final ok = await _service.preview();
      if (!mounted || ok) return;
      final reason = _service.lastError.trim();
      _showSnack(reason.isEmpty ? '试听失败：系统未发出声音' : reason);
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _retry() async {
    final ok = await _service.retry();
    if (!mounted || ok) return;
    final reason = _service.lastError.trim();
    _showSnack(reason.isEmpty ? '重试失败，语音引擎仍不可用' : reason);
  }

  void _reinitialize() {
    setState(() {
      _initializing = true;
      _failed = false;
    });
    _init();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  String get _diagnostics {
    final engine = _service.engineName.trim();
    final language = _service.selectedLanguage.trim();
    return '引擎 ${engine.isEmpty ? '系统默认' : engine}'
        ' · 语言 ${language.isEmpty ? '未选择' : language}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.headphones, color: AppColors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('离线磨耳朵', style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: '关闭并停止朗读',
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_initializing)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_failed)
                  _unavailable(theme)
                else
                  _controls(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _unavailable(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.volume_off_outlined,
          size: 42,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 10),
        Text(
          '系统未安装中文离线语音',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '请到系统“设置 → 无障碍（辅助功能）→ 文字转语音”'
          '安装或启用中文语音数据（不同机型路径可能略有差异），然后重试。',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (_service.lastError.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _service.lastError,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _reinitialize,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ],
    );
  }

  Widget _controls(ThemeData theme) {
    final current = _service.current;
    final muted = AppColors.muted(theme.brightness);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.settings_voice_outlined, size: 16, color: muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _diagnostics,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _previewing || _service.playing ? null : _preview,
              icon: const Icon(Icons.hearing, size: 18),
              label: Text(_previewing ? '试听中…' : '试听'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_service.length == 0 ? 0 : _service.index + 1}'
                  ' / ${_service.length}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  current?.prompt ?? '按播放，从当前筛选列表开始朗读',
                  style: theme.textTheme.bodyLarge,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (current != null && current.answer.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    current.answer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.amber,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_service.hasPlaybackFailure) ...[
          const SizedBox(height: 8),
          _failure(theme),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _service.previous,
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton.filled(
              onPressed: () {
                if (_service.playing) {
                  _service.pause();
                } else if (_service.length == 0) {
                  _service.play(widget.items);
                } else {
                  _service.resume();
                }
              },
              icon: Icon(_service.playing ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              onPressed: _service.next,
              icon: const Icon(Icons.skip_next),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final entry in const [
              (0.5, '1.0x'),
              (0.6, '1.25x'),
              (0.7, '1.5x'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  label: Text(entry.$2),
                  selected: (_service.rate - entry.$1).abs() < 0.01,
                  showCheckmark: false,
                  onSelected: (_) => _service.setRate(entry.$1),
                ),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _service.loop,
          onChanged: (_) => _service.toggleLoop(),
          title: const Text('单列表循环'),
        ),
        Text(
          '朗读题干 → 停顿 1.5 秒 → 朗读结论；关闭本面板即停止。',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _failure(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final message = _service.lastError.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: dark ? AppColors.red.withValues(alpha: 0.16) : AppColors.redSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _service.degraded ? '语音引擎无响应' : '播报异常',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '已跳过 ${_service.skippedCount} 条'
                  '${message.isEmpty ? '' : ' · $message'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted(theme.brightness),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _retry,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
