import 'dart:convert';

import 'probe_trace.dart';

/// Version 1: one explicit generation, no prefetch or implicit consumption.
abstract interface class NarrativeProviderV1 {
  Future<String> generate(
    String model,
    String prompt,
    void Function(String) onPartial, {
    ProbeTrace? trace,
  });
}

enum NarrativeAction { intro, more, surprise }

class EvidenceClaim {
  const EvidenceClaim(this.id, this.fact, this.source);
  final String id, fact, source;
}

const evidenceRevision = 'peterborough-cathedral/2026-10-19/v1';
const evidenceSources = {
  'history': 'https://peterborough-cathedral.org.uk/about/history/',
  'architecture':
      'https://www.nationalchurchestrust.org/church/peterborough-cathedral',
};
const cathedralClaims = [
  EvidenceClaim(
    'fire',
    'В 1116 году пожар опустошил монастырь и значительную часть города.',
    'history',
  ),
  EvidenceClaim(
    'building',
    'Строительство нынешней церкви началось в 1118 году.',
    'history',
  ),
  EvidenceClaim(
    'consecration',
    'Монастырскую церковь освятили в 1238 году.',
    'history',
  ),
  EvidenceClaim('dissolution', 'Аббатство распустили в 1539 году.', 'history'),
  EvidenceClaim(
    'cathedral',
    'В 1541 году Генрих VIII учредил здесь собор и епископскую кафедру.',
    'history',
  ),
  EvidenceClaim(
    'ceiling',
    'В нефе сохранился расписной деревянный потолок.',
    'architecture',
  ),
  EvidenceClaim(
    'vaulting',
    'Среди особенностей собора — веерные своды в части, называемой новым зданием.',
    'architecture',
  ),
];

class NarrativeRequest {
  NarrativeRequest(this.action, Set<String> consumed)
    : consumed = Set.unmodifiable(consumed);
  final NarrativeAction action;
  final Set<String> consumed;
  List<EvidenceClaim> get selected {
    final group = switch (action) {
      NarrativeAction.intro => {'fire', 'building', 'consecration'},
      NarrativeAction.more => {'dissolution', 'cathedral'},
      NarrativeAction.surprise => {'ceiling', 'vaulting'},
    };
    return cathedralClaims
        .where((c) => group.contains(c.id) && !consumed.contains(c.id))
        .toList();
  }

  String get prompt =>
      '''Ты русскоязычный гид по Питерборскому собору. Версия контракта 1.
Составь короткий связный рассказ (50–100 слов, можно короче, если фактов мало).
Используй ТОЛЬКО факты ниже. Не добавляй даты, причины, легенды, цитаты или ссылки из памяти.
Не повторяй использованные claim IDs: ${jsonEncode(consumed.toList())}.
Действие: ${action.name}. Используй все выбранные факты, не выдумывай детали для увеличения длины.
Верни только JSON без Markdown: {"version":1,"text":"рассказ","claimIds":["id"],"sourceIds":["id"]}.
Источники перечисляй только по ID. Не помещай URL в text.
Пакет: $evidenceRevision. Факты: ${jsonEncode(selected.map((c) => {'id': c.id, 'fact': c.fact, 'sourceId': c.source}).toList())}''';
}

class NarrativeSegment {
  NarrativeSegment(this.text, this.claimIds, this.sourceIds);
  final String text;
  final Set<String> claimIds, sourceIds;
  static NarrativeSegment parse(String raw, NarrativeRequest request) {
    if (raw.length > 16000 || request.selected.isEmpty) {
      throw const NarrativeValidationFailure('size_or_empty_request');
    }
    dynamic value;
    try {
      value = jsonDecode(raw);
    } catch (_) {
      throw const NarrativeValidationFailure('invalid_json');
    }
    if (value is! Map ||
        value['version'] != 1 ||
        value['text'] is! String ||
        value['claimIds'] is! List ||
        value['sourceIds'] is! List) {
      throw const NarrativeValidationFailure('schema');
    }
    final text = (value['text'] as String).trim();
    if (text.isEmpty ||
        text.length > 6000 ||
        RegExp(r'https?://|www\.', caseSensitive: false).hasMatch(text)) {
      throw const NarrativeValidationFailure('text');
    }
    Set<String> ids(dynamic list) {
      if ((list as List).any((v) => v is! String)) {
        throw const NarrativeValidationFailure('id_type');
      }
      final result = list.cast<String>().toSet();
      if (result.length != list.length) {
        throw const NarrativeValidationFailure('duplicate_id');
      }
      return result;
    }

    final claims = ids(value['claimIds']);
    final sources = ids(value['sourceIds']);
    final expectedClaims = request.selected.map((c) => c.id).toSet();
    final expectedSources = request.selected.map((c) => c.source).toSet();
    if (claims.length != expectedClaims.length ||
        !claims.containsAll(expectedClaims) ||
        sources.length != expectedSources.length ||
        !sources.containsAll(expectedSources)) {
      throw const NarrativeValidationFailure('evidence_set');
    }
    return NarrativeSegment(
      text,
      Set.unmodifiable(claims),
      Set.unmodifiable(sources),
    );
  }
}

class NarrativeValidationFailure extends FormatException {
  const NarrativeValidationFailure(this.code);
  final String code;
}
