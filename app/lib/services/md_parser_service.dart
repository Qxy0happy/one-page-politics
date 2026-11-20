import 'dart:convert';

import '../models/knowledge_item.dart';

class ParseResult {
  final List<KnowledgeItem> items = [];
  final List<String> errors = [];
  final List<String> warnings = [];
  int ignoredLines = 0;

  bool get isValid => errors.isEmpty && items.isNotEmpty;
}

class MdParserService {
  ParseResult parse(String text) {
    final result = ParseResult();
    Subject? subject;
    var chapter = kUnchaptered;
    final seenIds = <String>{};

    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final lineNo = i + 1;
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) continue;

      if (line.startsWith('## ')) {
        final value = line.substring(3).trim();
        chapter = value.isEmpty ? kUnchaptered : value;
        continue;
      }
      if (line.startsWith('# ')) {
        final name = line.substring(2).trim();
        final matches = <Subject>{};
        for (final entry in subjectAliases.entries) {
          if (name.contains(entry.key)) matches.add(entry.value);
        }
        if (matches.length != 1) {
          result.errors.add('第 $lineNo 行：科目标题无法唯一匹配「$name」');
          subject = null;
        } else {
          subject = matches.first;
        }
        chapter = kUnchaptered;
        continue;
      }
      if (!line.startsWith('- ')) {
        result.ignoredLines++;
        continue;
      }
      if (subject == null) {
        result.errors.add('第 $lineNo 行：条目出现在科目标题之前');
        continue;
      }

      var body = line.substring(2).trim();
      var isRound2Focus = false;
      var isMappingDrill = false;
      while (true) {
        if (body.endsWith('#二轮')) {
          isRound2Focus = true;
          body = body.substring(0, body.length - 3).trimRight();
          continue;
        }
        if (body.endsWith('#配对')) {
          isMappingDrill = true;
          body = body.substring(0, body.length - 3).trimRight();
          continue;
        }
        break;
      }

      final parts = body.split('|');
      final main = parts.first.trim();
      final extensions = <String, String>{};
      var extensionError = false;
      for (final part in parts.skip(1)) {
        if (part.trim().isEmpty) continue;
        final idx = part.indexOf(':');
        if (idx <= 0) {
          result.warnings.add('第 $lineNo 行：扩展字段缺少冒号「${part.trim()}」');
          continue;
        }
        final key = part.substring(0, idx).trim();
        final value = part.substring(idx + 1).trim();
        if (!const {'口诀', '解析', '墓碑词', '备注', 'id'}.contains(key)) {
          result.warnings.add('第 $lineNo 行：未知扩展字段「$key」');
          continue;
        }
        if (extensions.containsKey(key)) {
          result.errors.add('第 $lineNo 行：重复扩展字段「$key」');
          extensionError = true;
          continue;
        }
        extensions[key] = value;
      }
      if (extensionError) continue;

      late CardType cardType;
      var prompt = '';
      var answer = '';
      var explanation = extensions['解析'] ?? '';
      bool? isTrue;
      String? pairAFeature;
      String? pairBFeature;

      if (main.startsWith('[配对]')) {
        cardType = CardType.mapping;
        final rest = main.substring(4).trim();
        final split = _splitOnce(rest, '==');
        if (split == null) {
          result.errors.add('第 $lineNo 行：[配对] 必须且只能有一个 ==');
          continue;
        }
        prompt = split.$1;
        answer = split.$2;
        if (prompt.isEmpty || answer.isEmpty) {
          result.errors.add('第 $lineNo 行：[配对] 题干或结论为空');
          continue;
        }
      } else if (main.startsWith('[对比]')) {
        cardType = CardType.pair;
        final rest = main.substring(4).trim();
        final split = _splitOnce(rest, '<>');
        if (split == null) {
          result.errors.add('第 $lineNo 行：[对比] 必须且只能有一个 <>');
          continue;
        }
        final sideA = _parsePairSide(split.$1, lineNo, result, isA: true);
        final sideB = _parsePairSide(split.$2, lineNo, result, isA: false);
        prompt = sideA.$1;
        pairAFeature = sideA.$2;
        answer = sideB.$1;
        pairBFeature = sideB.$2;
        if (prompt.isEmpty || answer.isEmpty) {
          result.errors.add('第 $lineNo 行：[对比] 名称不能为空');
          continue;
        }
      } else if (main.startsWith('[对]')) {
        cardType = CardType.trueFalse;
        isTrue = true;
        prompt = main.substring(3).trim();
      } else if (main.startsWith('[错]')) {
        cardType = CardType.trueFalse;
        isTrue = false;
        prompt = main.substring(3).trim();
      } else {
        result.errors.add('第 $lineNo 行：未识别行前缀「$main」');
        continue;
      }

      if (prompt.isEmpty) {
        result.errors.add('第 $lineNo 行：题干为空');
        continue;
      }

      final explicitId = extensions['id'];
      final id = explicitId ?? _computeId(subject, cardType, prompt);
      if (explicitId != null) {
        final prefix = '${subject.name}.${cardType.name}.';
        final valid =
            RegExp(r'^[a-z]+\.[a-zA-Z]+\.[0-9a-f]{8}$').hasMatch(explicitId) &&
            explicitId.startsWith(prefix);
        if (!valid) {
          result.errors.add('第 $lineNo 行：id 前缀或格式不合法「$explicitId」');
          continue;
        }
      }
      if (!seenIds.add(id)) {
        result.errors.add('第 $lineNo 行：重复 id「$id」');
        continue;
      }

      final tombstoneWords = (extensions['墓碑词'] ?? '')
          .split(RegExp(r'[,，、]'))
          .map((word) => word.trim())
          .where((word) => word.isNotEmpty)
          .toList(growable: false);

      result.items.add(
        KnowledgeItem(
          id: id,
          subject: subject,
          chapter: chapter,
          cardType: cardType,
          prompt: prompt,
          answer: answer,
          explanation: explanation,
          isTrue: isTrue,
          mnemonic: extensions['口诀'] ?? '',
          pairAFeature: pairAFeature,
          pairBFeature: pairBFeature,
          tombstoneWords: tombstoneWords,
          sourceNote: extensions['备注'] ?? '',
          isRound2Focus: isRound2Focus,
          isMappingDrill: isMappingDrill,
        ),
      );
    }

    if (result.items.isEmpty && result.errors.isEmpty) {
      result.errors.add('未解析到任何条目');
    }
    return result;
  }

  (String, String)? _splitOnce(String value, String delimiter) {
    final first = value.indexOf(delimiter);
    if (first < 0) return null;
    if (value.indexOf(delimiter, first + delimiter.length) >= 0) return null;
    return (
      value.substring(0, first).trim(),
      value.substring(first + delimiter.length).trim(),
    );
  }

  (String, String?) _parsePairSide(
    String side,
    int lineNo,
    ParseResult result, {
    required bool isA,
  }) {
    final close = side.lastIndexOf(RegExp(r'[）)]'));
    if (close < 0) {
      result.warnings.add('第 $lineNo 行：对比侧缺少特征括号「$side」');
      return (side.trim(), null);
    }
    final open = side.lastIndexOf(RegExp(r'[（(]'), close);
    if (open < 0) {
      result.warnings.add('第 $lineNo 行：对比侧括号不匹配「$side」');
      return (side.trim(), null);
    }
    final name = side.substring(0, open).trim();
    final feature = side.substring(open + 1, close).trim();
    if (name.isEmpty || feature.isEmpty) {
      result.errors.add('第 $lineNo 行：对比侧名称或特征为空「$side」');
    }
    return (name, feature);
  }

  String _computeId(Subject subject, CardType cardType, String prompt) {
    final input = _normalizeForId('${subject.name}|${cardType.name}|$prompt');
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return '${subject.name}.${cardType.name}.${hash.toRadixString(16).padLeft(8, '0')}';
  }

  String _normalizeForId(String input) {
    const punctuation = <int, int>{
      0x3002: 0x2E, // 。
      0x3001: 0x2C, // 、
      0x201C: 0x22, // “
      0x201D: 0x22, // ”
      0x2018: 0x27, // ‘
      0x2019: 0x27, // ’
    };
    final buffer = StringBuffer();
    for (var code in input.runes) {
      if (code >= 0xFF01 && code <= 0xFF5E) code -= 0xFEE0;
      if (code == 0x3000) code = 0x20;
      code = punctuation[code] ?? code;
      if (code >= 0x41 && code <= 0x5A) code += 0x20;
      buffer.writeCharCode(code);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
