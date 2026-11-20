/// Markdown 中没有二级标题时使用的章节名。
const String kUnchaptered = '未分章';

enum Subject { mayuan, shigang, sixiu, xinsixiang, shizheng }

const Map<String, Subject> subjectAliases = {
  '马原': Subject.mayuan,
  '马克思主义基本原理': Subject.mayuan,
  '史纲': Subject.shigang,
  '中国近现代史纲要': Subject.shigang,
  '思修': Subject.sixiu,
  '思想道德与法治': Subject.sixiu,
  '思想道德修养与法律基础': Subject.sixiu,
  '新思想': Subject.xinsixiang,
  '习近平新时代中国特色社会主义思想': Subject.xinsixiang,
  '时政': Subject.shizheng,
  '形势与政策': Subject.shizheng,
  '当代': Subject.shizheng,
};

extension SubjectX on Subject {
  String get label => switch (this) {
    Subject.mayuan => '马原',
    Subject.shigang => '史纲',
    Subject.sixiu => '思修',
    Subject.xinsixiang => '新思想',
    Subject.shizheng => '时政',
  };
}

enum CardType { mapping, trueFalse, pair }

extension CardTypeX on CardType {
  String get label => switch (this) {
    CardType.mapping => '配对',
    CardType.trueFalse => '判断',
    CardType.pair => '对比',
  };
}

enum StudyStatus { unseen, familiar, fuzzy }

extension StudyStatusX on StudyStatus {
  String get label => switch (this) {
    StudyStatus.unseen => '未看',
    StudyStatus.familiar => '眼熟',
    StudyStatus.fuzzy => '模糊',
  };
}

enum StatusFilter { all, starred, fuzzy, round2 }

class KnowledgeItem {
  const KnowledgeItem({
    required this.id,
    required this.subject,
    required this.chapter,
    required this.cardType,
    required this.prompt,
    this.answer = '',
    this.explanation = '',
    this.isTrue,
    this.mnemonic = '',
    this.pairAFeature,
    this.pairBFeature,
    this.tombstoneWords = const [],
    this.sourceNote = '',
    this.isRound2Focus = false,
    this.isMappingDrill = false,
    this.status = StudyStatus.unseen,
    this.isStarred = false,
    this.userNote = '',
    this.isCustomEdited = false,
    this.reviewCount = 0,
  });

  final String id;
  final Subject subject;
  final String chapter;
  final CardType cardType;

  final String prompt;
  final String answer;
  final String explanation;
  final bool? isTrue;
  final String mnemonic;

  final String? pairAFeature;
  final String? pairBFeature;

  final List<String> tombstoneWords;
  final String sourceNote;
  final bool isRound2Focus;
  final bool isMappingDrill;

  final StudyStatus status;
  final bool isStarred;
  final String userNote;
  final bool isCustomEdited;
  final int reviewCount;

  static const Object _unset = Object();

  KnowledgeItem copyWith({
    String? id,
    Subject? subject,
    String? chapter,
    CardType? cardType,
    String? prompt,
    String? answer,
    String? explanation,
    Object? isTrue = _unset,
    String? mnemonic,
    Object? pairAFeature = _unset,
    Object? pairBFeature = _unset,
    List<String>? tombstoneWords,
    String? sourceNote,
    bool? isRound2Focus,
    bool? isMappingDrill,
    StudyStatus? status,
    bool? isStarred,
    String? userNote,
    bool? isCustomEdited,
    int? reviewCount,
  }) {
    return KnowledgeItem(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      cardType: cardType ?? this.cardType,
      prompt: prompt ?? this.prompt,
      answer: answer ?? this.answer,
      explanation: explanation ?? this.explanation,
      isTrue: identical(isTrue, _unset) ? this.isTrue : isTrue as bool?,
      mnemonic: mnemonic ?? this.mnemonic,
      pairAFeature: identical(pairAFeature, _unset)
          ? this.pairAFeature
          : pairAFeature as String?,
      pairBFeature: identical(pairBFeature, _unset)
          ? this.pairBFeature
          : pairBFeature as String?,
      tombstoneWords: tombstoneWords ?? this.tombstoneWords,
      sourceNote: sourceNote ?? this.sourceNote,
      isRound2Focus: isRound2Focus ?? this.isRound2Focus,
      isMappingDrill: isMappingDrill ?? this.isMappingDrill,
      status: status ?? this.status,
      isStarred: isStarred ?? this.isStarred,
      userNote: userNote ?? this.userNote,
      isCustomEdited: isCustomEdited ?? this.isCustomEdited,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject.name,
    'chapter': chapter,
    'cardType': cardType.name,
    'prompt': prompt,
    'answer': answer,
    'explanation': explanation,
    'isTrue': isTrue,
    'mnemonic': mnemonic,
    'pairAFeature': pairAFeature,
    'pairBFeature': pairBFeature,
    'tombstoneWords': tombstoneWords,
    'sourceNote': sourceNote,
    'isRound2Focus': isRound2Focus,
    'isMappingDrill': isMappingDrill,
    'status': status.name,
    'isStarred': isStarred,
    'userNote': userNote,
    'isCustomEdited': isCustomEdited,
    'reviewCount': reviewCount,
  };

  factory KnowledgeItem.fromJson(Map<String, dynamic> json) {
    return KnowledgeItem(
      id: json['id'] as String? ?? '',
      subject: _enumByName(Subject.values, json['subject'], Subject.mayuan),
      chapter: json['chapter'] as String? ?? kUnchaptered,
      cardType: _enumByName(
        CardType.values,
        json['cardType'],
        CardType.mapping,
      ),
      prompt: json['prompt'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      isTrue: json['isTrue'] as bool?,
      mnemonic: json['mnemonic'] as String? ?? '',
      pairAFeature: json['pairAFeature'] as String?,
      pairBFeature: json['pairBFeature'] as String?,
      tombstoneWords: _stringList(json['tombstoneWords']),
      sourceNote: json['sourceNote'] as String? ?? '',
      isRound2Focus: json['isRound2Focus'] as bool? ?? false,
      isMappingDrill: json['isMappingDrill'] as bool? ?? false,
      status: _enumByName(
        StudyStatus.values,
        json['status'],
        StudyStatus.unseen,
      ),
      isStarred: json['isStarred'] as bool? ?? false,
      userNote: json['userNote'] as String? ?? '',
      isCustomEdited: json['isCustomEdited'] as bool? ?? false,
      reviewCount: json['reviewCount'] as int? ?? 0,
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? name,
    T fallback,
  ) {
    if (name is String) {
      for (final value in values) {
        if (value.name == name) return value;
      }
    }
    return fallback;
  }
}
