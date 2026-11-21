import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/update_provider.dart';

Future<void> showUpdateDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const UpdateDialog(),
  );
}

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateProvider>();
    final manifest = update.available;
    final theme = Theme.of(context);

    if (manifest == null) {
      return AlertDialog(
        title: const Text('版本更新'),
        content: Text(
          update.phase == UpdatePhase.upToDate ? '当前已是最新版本。' : '没有可用的更新。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    final downloading = update.phase == UpdatePhase.downloading;
    final verifying = update.phase == UpdatePhase.verifying;
    final installed = update.installed;
    final blockedBySdk =
        installed != null && manifest.minSdk > installed.sdkInt;

    return PopScope(
      canPop: !downloading && !verifying,
      child: AlertDialog(
        title: Text('发现新版本 v${manifest.versionName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本 ${update.currentVersionLabel}'),
              const SizedBox(height: 4),
              Text(
                '${manifest.sizeLabel} · ${_dateLabel(manifest.publishedAt)}',
                style: theme.textTheme.bodySmall,
              ),
              if (manifest.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(manifest.notes, style: theme.textTheme.bodyMedium),
              ],
              if (blockedBySdk) ...[
                const SizedBox(height: 12),
                Text(
                  '该版本要求 Android ${manifest.minSdk} 或更高，当前设备为 Android ${installed.sdkInt}。',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (downloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: update.progress),
                const SizedBox(height: 8),
                Text(
                  '${_mb(update.receivedBytes)} / ${_mb(update.totalBytes)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (verifying) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text('正在校验安装包…', style: theme.textTheme.bodySmall),
              ],
              if (update.message != null) ...[
                const SizedBox(height: 12),
                Text(
                  update.message!,
                  style: TextStyle(
                    color: update.phase == UpdatePhase.error
                        ? theme.colorScheme.error
                        : theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: _actions(context, update, blockedBySdk),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    UpdateProvider update,
    bool blockedBySdk,
  ) {
    if (update.phase == UpdatePhase.downloading) {
      return [
        TextButton(onPressed: update.cancelDownload, child: const Text('取消下载')),
      ];
    }
    if (update.phase == UpdatePhase.verifying) {
      return const [TextButton(onPressed: null, child: Text('校验中…'))];
    }
    return [
      if (!blockedBySdk)
        TextButton(
          onPressed: () async {
            await update.skipVersion();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('跳过此版本'),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('稍后'),
      ),
      if (update.needsInstallPermission)
        TextButton(
          onPressed: update.openInstallPermissionSettings,
          child: const Text('打开安装权限设置'),
        ),
      FilledButton(
        onPressed: update.canInstall ? update.downloadAndInstall : null,
        child: Text(update.phase == UpdatePhase.error ? '重试' : '下载并安装'),
      ),
    ];
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
