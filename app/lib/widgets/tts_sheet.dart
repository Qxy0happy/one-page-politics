import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/knowledge_item.dart';
import '../services/deepseek_tts_engine.dart' show deepSeekVoiceLabel;
import '../services/tts_service.dart';
import '../services/tts_service_factory.dart';
import '../services/tts_settings.dart';
import '../theme/app_theme.dart';

class TtsSheet extends StatefulWidget {
  const TtsSheet({super.key, required this.items, this.serviceFactory});

  final List<KnowledgeItem> items;

  /// 测试替换朗读服务；生产代码使用 [createTtsService]。
  final TtsService Function(TtsSettings settings)? serviceFactory;

  @override
  State<TtsSheet> createState() => _TtsSheetState();
}

class _TtsSheetState extends State<TtsSheet> {
  late final TextEditingController _apiKeyController;
  SharedPreferences? _prefs;
  TtsSettings _settings = const TtsSettings();
  TtsService? _service;
  var _initializing = true;
  var _failed = false;
  var _previewing = false;
  var _settingsOpen = false;
  var _applying = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final settings = TtsSettings.load(prefs);
    _prefs = prefs;
    _apiKeyController.text = settings.deepseekApiKey;
    setState(() {
      _settings = settings;
      _settingsOpen = _needsDeepSeekKey(settings);
    });
    await _startService();
  }

  bool _needsDeepSeekKey(TtsSettings settings) =>
      settings.backend == TtsBackend.deepseek && !settings.hasDeepSeekKey;

  Future<void> _startService() async {
    final previous = _service;
    _service = null;
    if (previous != null) {
      await previous.close();
      previous.dispose();
    }
    if (!mounted) return;
    setState(() {
      _previewing = false;
      _failed = false;
      _initializing = true;
    });
    if (_needsDeepSeekKey(_settings)) {
      setState(() => _initializing = false);
      return;
    }

    final factory =
        widget.serviceFactory ?? ((settings) => createTtsService(settings));
    final service = factory(_settings);
    if (!mounted) {
      service.dispose();
      return;
    }
    setState(() {
      _service = service;
      _initializing = true;
      _failed = false;
    });
    final ok = await service.init();
    if (!mounted || !identical(_service, service)) {
      service.dispose();
      return;
    }
    setState(() {
      _initializing = false;
      _failed = !ok;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _service?.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _service?.close();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _preview() async {
    final service = _service;
    if (_previewing || service == null) return;
    setState(() => _previewing = true);
    try {
      final ok = await service.preview();
      if (!mounted || ok) return;
      final reason = service.lastError.trim();
      _showSnack(reason.isEmpty ? '试听失败：系统未发出声音' : reason);
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _retry() async {
    final service = _service;
    if (service == null) {
      await _reinitialize();
      return;
    }
    final ok = await service.retry();
    if (!mounted || ok) return;
    final reason = service.lastError.trim();
    _showSnack(reason.isEmpty ? '重试失败，语音引擎仍不可用' : reason);
  }

  Future<void> _reinitialize() async {
    if (_applying) return;
    _applying = true;
    try {
      await _startService();
    } finally {
      _applying = false;
    }
  }

  void _persist(TtsSettings settings) {
    final prefs = _prefs;
    if (prefs != null) unawaited(settings.save(prefs));
  }

  Future<void> _applySettings(TtsSettings next, {String? snack}) async {
    if (_applying) return;
    _applying = true;
    try {
      setState(() {
        _settings = next;
        if (_needsDeepSeekKey(next)) _settingsOpen = true;
      });
      _persist(next);
      await _startService();
      if (snack != null && mounted) _showSnack(snack);
    } finally {
      _applying = false;
    }
  }

  Future<void> _setBackend(TtsBackend backend) async {
    if (_settings.backend == backend) return;
    await _applySettings(_settings.copyWith(backend: backend));
  }

  Future<void> _setVoice(String voiceId) async {
    if (_settings.deepseekVoiceId == voiceId) return;
    await _applySettings(_settings.copyWith(deepseekVoiceId: voiceId));
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _showSnack('请填写 DeepSeek API Key');
      return;
    }
    FocusScope.of(context).unfocus();
    _apiKeyController.text = key;
    await _applySettings(
      _settings.copyWith(deepseekApiKey: key),
      snack: '已保存 DeepSeek 配置',
    );
  }

  void _setPromptPause(double seconds) {
    final next = _settings.copyWith(
      promptPause: Duration(milliseconds: (seconds * 1000).round()),
    );
    setState(() => _settings = next);
    _service?.setPromptPause(next.promptPause);
  }

  void _setAnswerPause(double seconds) {
    final next = _settings.copyWith(
      answerPause: Duration(milliseconds: (seconds * 1000).round()),
    );
    setState(() => _settings = next);
    _service?.setAnswerPause(next.answerPause);
  }

  void _commitPauses() => _persist(_settings);

  void _showSnack(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  String get _diagnostics {
    final service = _service;
    if (service == null) {
      return _settings.backend == TtsBackend.deepseek
          ? 'DeepSeek · 待配置'
          : '系统语音 · 待初始化';
    }
    if (_settings.backend == TtsBackend.deepseek) {
      return '${service.engineName} · '
          '${deepSeekVoiceLabel(_settings.deepseekVoiceId)} · 网络合成';
    }
    final engine = service.engineName.trim();
    final language = service.selectedLanguage.trim();
    return '引擎 ${engine.isEmpty ? '系统默认' : engine}'
        ' · 语言 ${language.isEmpty ? '未选择' : language}';
  }

  String get _settingsSummary {
    final backend = _settings.backend == TtsBackend.system
        ? '系统语音'
        : 'DeepSeek';
    return '$backend · 题干后 ${_formatPause(_settings.promptPause)} 秒';
  }

  static String _formatPause(Duration value) {
    final seconds = value.inMilliseconds / 1000;
    return seconds == seconds.roundToDouble()
        ? seconds.toStringAsFixed(0)
        : seconds.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = _service;
    return AnimatedBuilder(
      animation: service ?? const AlwaysStoppedAnimation<double>(0),
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
                      child: Text(
                        _settings.backend == TtsBackend.system
                            ? '离线磨耳朵'
                            : '磨耳朵',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭并停止朗读',
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _settingsCard(theme),
                const SizedBox(height: 8),
                if (_initializing)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (service == null)
                  _configureCloud(theme)
                else if (_failed)
                  _unavailable(theme, service)
                else
                  _controls(theme, service),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _settingsCard(ThemeData theme) {
    final muted = AppColors.muted(theme.brightness);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.tune, size: 20),
            title: const Text('朗读设置'),
            subtitle: Text(
              _settingsSummary,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            trailing: Icon(
              _settingsOpen ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(() => _settingsOpen = !_settingsOpen),
          ),
          if (_settingsOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<TtsBackend>(
                    segments: const [
                      ButtonSegment(
                        value: TtsBackend.system,
                        label: Text('系统语音'),
                        icon: Icon(Icons.phone_android, size: 16),
                      ),
                      ButtonSegment(
                        value: TtsBackend.deepseek,
                        label: Text('DeepSeek'),
                        icon: Icon(Icons.cloud_outlined, size: 16),
                      ),
                    ],
                    selected: {_settings.backend},
                    showSelectedIcon: false,
                    onSelectionChanged: _applying
                        ? null
                        : (selection) => _setBackend(selection.first),
                  ),
                  if (_settings.backend == TtsBackend.deepseek) ...[
                    const SizedBox(height: 14),
                    _deepSeekConfig(theme),
                  ],
                  const SizedBox(height: 8),
                  _pauseSlider(
                    theme,
                    label: '题干后停顿',
                    value: _settings.promptPause,
                    onChanged: _setPromptPause,
                  ),
                  _pauseSlider(
                    theme,
                    label: '结论后停顿',
                    value: _settings.answerPause,
                    onChanged: _setAnswerPause,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _deepSeekConfig(ThemeData theme) {
    final muted = AppColors.muted(theme.brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('API Key', style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        TextField(
          controller: _apiKeyController,
          obscureText: false,
          keyboardType: TextInputType.text,
          enableSuggestions: true,
          autocorrect: false,
          enableIMEPersonalizedLearning: false,
          onSubmitted: (_) => _saveApiKey(),
          decoration: const InputDecoration(
            hintText: 'sk-...',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '密钥保存在本机应用数据中，不随 Markdown 导出；云语音按 DeepSeek '
          '账户计费。合成音频会压制为本地缓存，同一音色与文本再次朗读时'
          '不再请求网络。',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: _applying ? null : _saveApiKey,
            child: const Text('保存并连接'),
          ),
        ),
        const SizedBox(height: 6),
        Text('音色', style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final voice in TtsSettings.voiceIds)
              ChoiceChip(
                label: Text(deepSeekVoiceLabel(voice)),
                selected: _settings.deepseekVoiceId == voice,
                showCheckmark: false,
                onSelected: _applying ? null : (_) => _setVoice(voice),
              ),
          ],
        ),
      ],
    );
  }

  Widget _pauseSlider(
    ThemeData theme, {
    required String label,
    required Duration value,
    required ValueChanged<double> onChanged,
  }) {
    final seconds = (value.inMilliseconds / 1000).clamp(0.0, 5.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              '${_formatPause(value)} 秒',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(theme.brightness),
              ),
            ),
          ],
        ),
        Slider(
          value: seconds,
          min: 0,
          max: 5,
          divisions: 50,
          label: '${_formatPause(value)} 秒',
          semanticFormatterCallback: (current) =>
              '$label ${current.toStringAsFixed(1)} 秒',
          onChanged: onChanged,
          onChangeEnd: (_) => _commitPauses(),
        ),
      ],
    );
  }

  Widget _configureCloud(ThemeData theme) {
    final muted = AppColors.muted(theme.brightness);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 42, color: AppColors.blue),
        const SizedBox(height: 10),
        Text('尚未配置 DeepSeek', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          '展开上方“朗读设置”，填写 DeepSeek API Key 后即可使用云语音。'
          '不配置时仍可使用系统离线语音。',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => setState(() => _settingsOpen = true),
          icon: const Icon(Icons.key_outlined),
          label: const Text('填写 API Key'),
        ),
      ],
    );
  }

  Widget _unavailable(ThemeData theme, TtsService service) {
    final cloud = _settings.backend == TtsBackend.deepseek;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          cloud ? Icons.cloud_off_outlined : Icons.volume_off_outlined,
          size: 42,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 10),
        Text(
          cloud ? 'DeepSeek 语音未就绪' : '系统未安装中文离线语音',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        if (!cloud)
          Text(
            '请到系统“设置 → 无障碍（辅助功能）→ 文字转语音”'
            '安装或启用中文语音数据（不同机型路径可能略有差异），然后重试。',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        if (service.lastError.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            service.lastError,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
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

  Widget _controls(ThemeData theme, TtsService service) {
    final current = service.current;
    final promptText = current == null ? null : ttsPromptText(current);
    final answerText = current == null ? '' : ttsAnswerText(current);
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
              onPressed: _previewing || service.playing ? null : _preview,
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
                  '${service.length == 0 ? 0 : service.index + 1}'
                  ' / ${service.length}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  promptText ?? '按播放，从当前筛选列表开始朗读',
                  style: theme.textTheme.bodyLarge,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (answerText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    answerText,
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
        if (service.hasPlaybackFailure) ...[
          const SizedBox(height: 8),
          _failure(theme, service),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: service.previous,
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton.filled(
              onPressed: () {
                if (service.playing) {
                  service.pause();
                } else if (service.length == 0) {
                  service.play(widget.items);
                } else {
                  service.resume();
                }
              },
              icon: Icon(service.playing ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              onPressed: service.next,
              icon: const Icon(Icons.skip_next),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (service.supportsRate)
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
                    selected: (service.rate - entry.$1).abs() < 0.01,
                    showCheckmark: false,
                    onSelected: (_) => service.setRate(entry.$1),
                  ),
                ),
            ],
          )
        else
          Text(
            'DeepSeek 云端合成不支持调节语速',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: service.loop,
          onChanged: (_) => service.toggleLoop(),
          title: const Text('单列表循环'),
        ),
        Text(
          _footerText,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String get _footerText {
    final prefix = _settings.backend == TtsBackend.system
        ? ''
        : 'DeepSeek 云语音按条目缓存到本机；';
    return '$prefix朗读题干 → 停顿 ${_formatPause(_settings.promptPause)} 秒'
        ' → 朗读结论 → 停顿 ${_formatPause(_settings.answerPause)} 秒'
        ' → 下一条；关闭本面板即停止。';
  }

  Widget _failure(ThemeData theme, TtsService service) {
    final dark = theme.brightness == Brightness.dark;
    final message = service.lastError.trim();
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
                  service.degraded ? '语音引擎无响应' : '播报异常',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '已跳过 ${service.skippedCount} 条'
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
