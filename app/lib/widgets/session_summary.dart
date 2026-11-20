import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

class SessionSummary extends StatelessWidget {
  const SessionSummary({
    super.key,
    required this.title,
    required this.correct,
    required this.wrong,
    required this.onRestart,
    required this.onClose,
  });

  final String title;
  final int correct;
  final int wrong;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = correct + wrong;
    final rate = total == 0 ? 0 : (correct / total * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 48, color: AppColors.amber),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('本局 $total 题 · 正确率 $rate%', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stat(theme, '答对', correct, AppColors.green),
                const SizedBox(width: 12),
                _stat(theme, '答错', wrong, AppColors.red),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh),
              label: const Text('再来一局'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onClose, child: const Text('返回反射场')),
          ],
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, int value, Color color) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.headlineSmall?.copyWith(color: color),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
