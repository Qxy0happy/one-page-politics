import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/exam_record.dart';
import '../theme/app_theme.dart';

class ScoreLineChart extends StatelessWidget {
  const ScoreLineChart({super.key, required this.records});

  final List<ExamRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: CustomPaint(
        painter: _ScorePainter(
          records: records,
          lineColor: AppColors.amber,
          gridColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          textColor: theme.textTheme.bodySmall?.color ?? Colors.grey,
          surfaceColor: theme.cardColor,
        ),
      ),
    );
  }
}

class _ScorePainter extends CustomPainter {
  _ScorePainter({
    required this.records,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.surfaceColor,
  });

  final List<ExamRecord> records;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final Color surfaceColor;

  static const _maxScore = 50.0;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    const top = 18.0;
    const right = 16.0;
    const bottom = 26.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;
    if (width <= 0 || height <= 0) return;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final score in [0, 10, 20, 30, 40, 50]) {
      final y = top + height * (1 - score / _maxScore);
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      _label(canvas, '$score', Offset(0, y - 7), 10, textColor);
    }

    _dashedLine(
      canvas,
      left,
      top + height * (1 - 35 / _maxScore),
      left + width,
      AppColors.amber,
    );
    _label(
      canvas,
      '35',
      Offset(left + width - 18, top + height * (1 - 35 / _maxScore) - 14),
      10,
      AppColors.amber,
    );
    _dashedLine(
      canvas,
      left,
      top + height * (1 - 40 / _maxScore),
      left + width,
      AppColors.green,
    );
    _label(
      canvas,
      '40',
      Offset(left + width - 18, top + height * (1 - 40 / _maxScore) - 14),
      10,
      AppColors.green,
    );

    if (records.isEmpty) {
      _label(
        canvas,
        '还没有记录',
        Offset(left + width / 2 - 30, top + height / 2),
        12,
        textColor,
      );
      return;
    }

    final points = <Offset>[];
    for (var i = 0; i < records.length; i++) {
      final x = records.length == 1
          ? left + width / 2
          : left + width * i / (records.length - 1);
      final y = top + height * (1 - records[i].totalScore / _maxScore);
      points.add(Offset(x, y));
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    final pointPaint = Paint()..color = lineColor;
    final dotPaint = Paint()..color = surfaceColor;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 5, pointPaint);
      canvas.drawCircle(points[i], 2.2, dotPaint);
      _label(
        canvas,
        '${records[i].totalScore}',
        Offset(points[i].dx - 7, points[i].dy - 18),
        10,
        textColor,
      );
      _label(
        canvas,
        _date(records[i].date),
        Offset(points[i].dx - 14, top + height + 8),
        9,
        textColor,
      );
    }
  }

  void _dashedLine(
    Canvas canvas,
    double x1,
    double y1,
    double x2,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dash = 6.0;
    const gap = 4.0;
    var x = x1;
    while (x < x2) {
      canvas.drawLine(Offset(x, y1), Offset(math.min(x + dash, x2), y1), paint);
      x += dash + gap;
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  String _date(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  bool shouldRepaint(covariant _ScorePainter oldDelegate) {
    if (oldDelegate.records.length != records.length) return true;
    if (oldDelegate.lineColor != lineColor) return true;
    for (var i = 0; i < records.length; i++) {
      if (oldDelegate.records[i].id != records[i].id) return true;
      if (oldDelegate.records[i].totalScore != records[i].totalScore) {
        return true;
      }
    }
    return false;
  }
}
