class TombstoneCategory {
  const TombstoneCategory({
    required this.name,
    required this.words,
    required this.strategy,
    required this.boundary,
  });

  final String name;
  final List<String> words;
  final String strategy;
  final String boundary;
}

class ChoiceStrategy {
  const ChoiceStrategy({required this.title, required this.points});

  final String title;
  final List<String> points;
}

class BigQuestionAngle {
  const BigQuestionAngle({required this.label, required this.usage});

  final String label;
  final String usage;
}

class FrameworkCard {
  const FrameworkCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

class SubjectPocketCard {
  const SubjectPocketCard({required this.subject, required this.sections});

  final String subject;
  final List<String> sections;
}

class ThreeInOneTemplate {
  const ThreeInOneTemplate({
    required this.cause,
    required this.meaning,
    required this.measure,
  });

  final String cause;
  final String meaning;
  final String measure;
}
