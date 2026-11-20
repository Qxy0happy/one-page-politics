import 'dart:math';

enum CalcQuestionType { profit, surplusRate }

class CalcQuestion {
  const CalcQuestion({
    required this.prompt,
    required this.answer,
    required this.explanation,
    required this.type,
  });

  final String prompt;
  final double answer;
  final String explanation;
  final CalcQuestionType type;
}

class CalcGenerator {
  CalcGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  CalcQuestion next(CalcQuestionType type) {
    return type == CalcQuestionType.profit ? _profit() : _surplusRate();
  }

  CalcQuestion _profit() {
    const values = [20, 25, 30, 40, 50, 60];
    const ratios = <(int, int)>[(2, 1), (3, 1), (4, 1), (7, 3)];
    const rates = [100, 150, 200];

    for (var attempt = 0; attempt < 100; attempt++) {
      final v = values[_random.nextInt(values.length)];
      final ratio = ratios[_random.nextInt(ratios.length)];
      final cNumerator = v * ratio.$1;
      if (cNumerator % ratio.$2 != 0) continue;
      final c = cNumerator ~/ ratio.$2;
      final rate = rates[_random.nextInt(rates.length)];
      final mNumerator = v * rate;
      if (mNumerator % 100 != 0) continue;
      final m = mNumerator ~/ 100;
      final total = c + v;
      return CalcQuestion(
        prompt:
            '某企业总投资 C+V = $total 万元，资本有机构成 C:V = '
            '${ratio.$1}:${ratio.$2}，剩余价值率 m′ = $rate%。求利润 M（万元）。',
        answer: m.toDouble(),
        explanation:
            'V = $total ÷ (1 + ${ratio.$1}/${ratio.$2}) = $v 万元；'
            'M = V × $rate% = $m 万元。',
        type: CalcQuestionType.profit,
      );
    }
    // 理论上不可达；保留一个固定的合法题，避免生成器抛异常。
    return const CalcQuestion(
      prompt:
          '某企业总投资 C+V = 100 万元，资本有机构成 C:V = 3:1，'
          '剩余价值率 m′ = 200%。求利润 M（万元）。',
      answer: 50,
      explanation: 'V = 100 ÷ (1 + 3/1) = 25 万元；M = 25 × 200% = 50 万元。',
      type: CalcQuestionType.profit,
    );
  }

  CalcQuestion _surplusRate() {
    const totalHours = [8, 10, 12];
    const necessaryHours = [3, 4, 5];

    for (var attempt = 0; attempt < 100; attempt++) {
      final total = totalHours[_random.nextInt(totalHours.length)];
      final candidates = necessaryHours
          .where((value) => value < total)
          .toList(growable: false);
      final necessary = candidates[_random.nextInt(candidates.length)];
      final surplus = total - necessary;
      final absolute = _random.nextBool();

      if (absolute) {
        final extra = 1 + _random.nextInt(2);
        final newSurplus = surplus + extra;
        final rate = newSurplus / necessary * 100;
        return CalcQuestion(
          prompt:
              '原工作日 $total 小时，必要劳动时间 $necessary 小时、'
              '剩余劳动时间 $surplus 小时。绝对方式把剩余劳动时间延长 $extra 小时，'
              '求新的剩余价值率（%）。',
          answer: rate,
          explanation:
              '新剩余劳动时间 = $surplus + $extra = $newSurplus 小时；'
              'm′ = $newSurplus ÷ $necessary × 100% = ${rate.toStringAsFixed(1)}%。',
          type: CalcQuestionType.surplusRate,
        );
      }

      final newSurplus = surplus + 1 + _random.nextInt(2);
      if (newSurplus >= total) continue;
      final newNecessary = total - newSurplus;
      final rate = newSurplus / newNecessary * 100;
      return CalcQuestion(
        prompt:
            '原工作日 $total 小时，必要劳动时间 $necessary 小时、'
            '剩余劳动时间 $surplus 小时。相对方式总工时不变，剩余劳动时间变为 '
            '$newSurplus 小时，求新的剩余价值率（%）。',
        answer: rate,
        explanation:
            '新必要劳动时间 = $total - $newSurplus = $newNecessary 小时；'
            'm′ = $newSurplus ÷ $newNecessary × 100% = ${rate.toStringAsFixed(1)}%。',
        type: CalcQuestionType.surplusRate,
      );
    }
    return const CalcQuestion(
      prompt:
          '原工作日 8 小时，必要劳动时间 4 小时、剩余劳动时间 4 小时。'
          '绝对方式把剩余劳动时间延长 2 小时，求新的剩余价值率（%）。',
      answer: 150,
      explanation: '新剩余劳动时间 = 4 + 2 = 6 小时；m′ = 6 ÷ 4 × 100% = 150.0%。',
      type: CalcQuestionType.surplusRate,
    );
  }
}
