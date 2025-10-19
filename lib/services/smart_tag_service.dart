import 'dart:math';

/// SmartTagService provides advanced heuristics to suggest tags from note text.
/// It does not require network access and works offline using rules:
/// - Extract hashtags like #projectX
/// - Detect frequent keywords (after stop-word filtering)
/// - Simple language guess (en/es) to adapt stop-words
/// - Basic entities: dates, emails, urls, code blocks
class SmartTagService {
  static final SmartTagService _instance = SmartTagService._internal();
  factory SmartTagService() => _instance;
  SmartTagService._internal();

  /// Generate tag suggestions from note [title] and [content].
  /// Returns up to [maxTags] unique tags.
  List<String> suggestTags({
    required String title,
    required String content,
    int maxTags = 8,
  }) {
    final text = '${title.trim()}\n${content.trim()}';
    if (text.isEmpty) return const [];

    final lang = _guessLanguage(text);
    final stop = _stopWords(lang);

    final tags = <String>{};

    // 1) Collect explicit hashtags
    final hashRe = RegExp(r'(^|\s)#([\p{L}\p{N}_-]{2,})', unicode: true);
    for (final m in hashRe.allMatches(text)) {
      final t = m.group(2)!.toLowerCase();
      tags.add(_sanitizeTag(t));
      if (tags.length >= maxTags) return tags.toList();
    }

    // 2) Tokenize and count keyword frequencies
    final tokens = RegExp(r"[\p{L}\p{N}][\p{L}\p{N}_'-]*", unicode: true)
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .where((w) => w.length >= 3 && !stop.contains(w))
        .toList();

    final freq = <String, int>{};
    for (final w in tokens) {
      freq[w] = (freq[w] ?? 0) + 1;
    }

    // 3) Boost words that appear in title
    final titleWords = title.toLowerCase().split(RegExp(r'\W+'));
    for (final w in titleWords) {
      if (w.isEmpty || stop.contains(w)) continue;
      freq[w] = (freq[w] ?? 0) + 2;
    }

    // 4) Entities
    final urlRe = RegExp(r'https?://[^\s)]+');
    if (urlRe.hasMatch(text)) tags.add('web');
    final emailRe = RegExp(r'[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}');
    if (emailRe.hasMatch(text)) tags.add('contact');
    final dateRe = RegExp(r'\b(\d{4}-\d{2}-\d{2}|\d{1,2}/\d{1,2}/\d{2,4})\b');
    if (dateRe.hasMatch(text)) tags.add('schedule');
    final codeRe = RegExp(r'```[\s\S]*?```');
    if (codeRe.hasMatch(text)) tags.add('code');

    // 5) Pick top-N frequent meaningful keywords
    final top = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in top.take(max(0, maxTags - tags.length))) {
      tags.add(_sanitizeTag(e.key));
      if (tags.length >= maxTags) break;
    }

    return tags.toList();
  }

  /// Very small language guess between English/Spanish using stopword hits.
  String _guessLanguage(String text) {
    final lower = text.toLowerCase();
    final hitsEs = _stopEs.where(lower.contains).length;
    final hitsEn = _stopEn.where(lower.contains).length;
    return hitsEs >= hitsEn ? 'es' : 'en';
  }

  Set<String> _stopWords(String lang) => lang == 'es' ? _stopEs : _stopEn;

  String _sanitizeTag(String s) {
    final t = s.trim().toLowerCase();
    return t.replaceAll(RegExp(r'[^\p{L}\p{N}_-]+', unicode: true), '-');
  }
}

// Minimal but effective stop words
const Set<String> _stopEn = {
  'the',
  'and',
  'for',
  'you',
  'are',
  'with',
  'that',
  'this',
  'have',
  'from',
  'not',
  'but',
  'all',
  'any',
  'can',
  'had',
  'her',
  'was',
  'one',
  'our',
  'out',
  'day',
  'get',
  'has',
  'she',
  'his',
  'him',
  'its',
  'who',
  'how',
  'why',
  'what',
  'your',
  'about',
  'into',
  'over',
  'also',
  'use',
  'used',
  'using',
  'after',
  'before',
  'between',
  'more',
  'less',
  'very',
  'too',
  'just',
  'here',
  'there',
  'where',
  'when',
  'then',
  'than',
  'these',
  'those',
  'will',
  'would',
  'could',
  'should',
  'may',
  'might',
  'must',
};

const Set<String> _stopEs = {
  'el',
  'la',
  'los',
  'las',
  'y',
  'o',
  'de',
  'del',
  'para',
  'con',
  'sin',
  'por',
  'que',
  'como',
  'cuando',
  'donde',
  'quien',
  'cual',
  'cuales',
  'cualquier',
  'mas',
  'menos',
  'muy',
  'tambien',
  'solo',
  'a',
  'al',
  'en',
  'un',
  'una',
  'unos',
  'unas',
  'es',
  'son',
  'ser',
  'fue',
  'fueron',
  'era',
  'eran',
  'tiene',
  'tener',
  'tienen',
  'tenia',
  'tenian',
  'sobre',
  'entre',
  'antes',
  'despues',
  'ya',
  'aqui',
  'alli',
  'allí',
  'esto',
  'eso',
  'esta',
  'este',
  'estos',
  'estas',
};
