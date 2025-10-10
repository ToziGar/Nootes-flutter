import 'package:flutter/material.dart';

/// Servicio de resaltado de sintaxis para el editor
class SyntaxHighlightService {
  static final SyntaxHighlightService _instance = SyntaxHighlightService._internal();
  factory SyntaxHighlightService() => _instance;
  SyntaxHighlightService._internal();

  /// Aplica resaltado de sintaxis a un texto
  TextSpan highlightText(String text, {SyntaxTheme? theme}) {
    final effectiveTheme = theme ?? SyntaxTheme.defaultTheme();
    
    // Detectar el tipo de contenido
    final contentType = _detectContentType(text);
    
    switch (contentType) {
      case ContentType.markdown:
        return _highlightMarkdown(text, effectiveTheme);
      case ContentType.code:
        return _highlightCode(text, effectiveTheme);
      case ContentType.json:
        return _highlightJson(text, effectiveTheme);
      case ContentType.yaml:
        return _highlightYaml(text, effectiveTheme);
      default:
        return _highlightPlainText(text, effectiveTheme);
    }
  }

  /// Detecta el tipo de contenido
  ContentType _detectContentType(String text) {
    // Verificar si es JSON
    if (text.trim().startsWith('{') || text.trim().startsWith('[')) {
      return ContentType.json;
    }
    
    // Verificar si es YAML
    if (text.contains('---') || RegExp(r'^\w+:\s*[\w\[\{]').hasMatch(text)) {
      return ContentType.yaml;
    }
    
    // Verificar si es código
    if (_hasCodePatterns(text)) {
      return ContentType.code;
    }
    
    // Verificar si es Markdown
    if (_hasMarkdownPatterns(text)) {
      return ContentType.markdown;
    }
    
    return ContentType.plainText;
  }

  /// Verifica si el texto tiene patrones de código
  bool _hasCodePatterns(String text) {
    final codePatterns = [
      r'function\s+\w+\s*\(',
      r'class\s+\w+',
      r'import\s+[\w\.\*]+',
      r'export\s+[\w\.\*]+',
      r'const\s+\w+\s*=',
      r'let\s+\w+\s*=',
      r'var\s+\w+\s*=',
      r'if\s*\(',
      r'for\s*\(',
      r'while\s*\(',
      r'def\s+\w+\s*\(',
      r'class\s+\w+\s*\(',
      r'public\s+\w+',
      r'private\s+\w+',
      r'protected\s+\w+',
      r'async\s+\w+',
      r'await\s+\w+',
      r'=>',
      r'\{[\s\S]*\}',
    ];
    
    return codePatterns.any((pattern) => RegExp(pattern).hasMatch(text));
  }

  /// Verifica si el texto tiene patrones de Markdown
  bool _hasMarkdownPatterns(String text) {
    final markdownPatterns = [
      r'^#+\s+',  // Headers
      r'\*\*.*\*\*',  // Bold
      r'\*.*\*',  // Italic
      r'`.*`',  // Inline code
      r'```',  // Code blocks
      r'^\s*[-\*\+]\s+',  // Lists
      r'^\s*\d+\.\s+',  // Numbered lists
      r'\[.*\]\(.*\)',  // Links
      r'!\[.*\]\(.*\)',  // Images
      r'^\s*>',  // Blockquotes
      r'^\s*\|.*\|',  // Tables
    ];
    
    return markdownPatterns.any((pattern) => RegExp(pattern, multiLine: true).hasMatch(text));
  }

  /// Resalta texto Markdown
  TextSpan _highlightMarkdown(String text, SyntaxTheme theme) {
    final spans = <TextSpan>[];
    final lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Headers
      if (RegExp(r'^(#{1,6})\s+(.*)').hasMatch(line)) {
        final match = RegExp(r'^(#{1,6})\s+(.*)').firstMatch(line)!;
        final level = match.group(1)!.length;
        final content = match.group(2)!;
        
        spans.add(TextSpan(
          text: '${match.group(1)!} ',
          style: theme.markdown.header.copyWith(
            fontSize: theme.markdown.header.fontSize! * (1.5 - (level * 0.1)),
            fontWeight: FontWeight.bold,
          ),
        ));
        spans.add(TextSpan(
          text: content,
          style: theme.markdown.header.copyWith(
            fontSize: theme.markdown.header.fontSize! * (1.5 - (level * 0.1)),
            fontWeight: FontWeight.bold,
          ),
        ));
      }
      // Code blocks
      else if (line.trim().startsWith('```')) {
        spans.add(TextSpan(
          text: line,
          style: theme.markdown.codeBlock,
        ));
      }
      // Lists
      else if (RegExp(r'^\s*[-\*\+]\s+').hasMatch(line)) {
        final match = RegExp(r'^(\s*[-\*\+]\s+)(.*)').firstMatch(line)!;
        spans.add(TextSpan(
          text: match.group(1)!,
          style: theme.markdown.listMarker,
        ));
        spans.add(_highlightInlineMarkdown(match.group(2)!, theme));
      }
      // Numbered lists
      else if (RegExp(r'^\s*\d+\.\s+').hasMatch(line)) {
        final match = RegExp(r'^(\s*\d+\.\s+)(.*)').firstMatch(line)!;
        spans.add(TextSpan(
          text: match.group(1)!,
          style: theme.markdown.listMarker,
        ));
        spans.add(_highlightInlineMarkdown(match.group(2)!, theme));
      }
      // Blockquotes
      else if (RegExp(r'^\s*>').hasMatch(line)) {
        spans.add(TextSpan(
          text: line,
          style: theme.markdown.blockquote,
        ));
      }
      // Tables
      else if (RegExp(r'^\s*\|.*\|').hasMatch(line)) {
        spans.add(TextSpan(
          text: line,
          style: theme.markdown.table,
        ));
      }
      // Normal text with inline formatting
      else {
        spans.add(_highlightInlineMarkdown(line, theme));
      }
      
      // Add newline except for last line
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    
    return TextSpan(children: spans);
  }

  /// Resalta formato inline de Markdown
  TextSpan _highlightInlineMarkdown(String text, SyntaxTheme theme) {
    final spans = <TextSpan>[];
    int lastIndex = 0;
    
    // Patterns for inline formatting
    final patterns = [
      // Bold
      RegExp(r'\*\*(.*?)\*\*'),
      // Italic
      RegExp(r'\*(.*?)\*'),
      // Inline code
      RegExp(r'`(.*?)`'),
      // Links
      RegExp(r'\[(.*?)\]\((.*?)\)'),
      // Images
      RegExp(r'!\[(.*?)\]\((.*?)\)'),
    ];
    
    final allMatches = <RegExpMatch>[];
    
    for (final pattern in patterns) {
      allMatches.addAll(pattern.allMatches(text));
    }
    
    // Sort matches by start position
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    for (final match in allMatches) {
      // Add text before match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: theme.plainText,
        ));
      }
      
      // Add formatted match
      final matchText = match.group(0)!;
      TextStyle style = theme.plainText;
      
      if (matchText.startsWith('**')) {
        style = theme.markdown.bold;
      } else if (matchText.startsWith('*')) {
        style = theme.markdown.italic;
      } else if (matchText.startsWith('`')) {
        style = theme.markdown.inlineCode;
      } else if (matchText.startsWith('![')) {
        style = theme.markdown.image;
      } else if (matchText.startsWith('[')) {
        style = theme.markdown.link;
      }
      
      spans.add(TextSpan(
        text: matchText,
        style: style,
      ));
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: theme.plainText,
      ));
    }
    
    return TextSpan(children: spans.isEmpty ? [TextSpan(text: text, style: theme.plainText)] : spans);
  }

  /// Resalta código genérico
  TextSpan _highlightCode(String text, SyntaxTheme theme) {
    final spans = <TextSpan>[];
    final lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      spans.add(_highlightCodeLine(line, theme));
      
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    
    return TextSpan(children: spans);
  }

  /// Resalta una línea de código
  TextSpan _highlightCodeLine(String line, SyntaxTheme theme) {
    final spans = <TextSpan>[];
    int lastIndex = 0;
    
    // Keywords
    final keywords = [
      'function', 'class', 'import', 'export', 'const', 'let', 'var',
      'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'default',
      'try', 'catch', 'finally', 'throw', 'return', 'break', 'continue',
      'async', 'await', 'yield', 'new', 'delete', 'typeof', 'instanceof',
      'public', 'private', 'protected', 'static', 'final', 'abstract',
      'interface', 'extends', 'implements', 'super', 'this', 'null',
      'true', 'false', 'undefined', 'void', 'def', 'lambda', 'pass',
    ];
    
    // Find all keyword matches
    final keywordAlternation = keywords.join('|');
    final keywordPattern = RegExp('\\b($keywordAlternation)\\b');
    final keywordMatches = keywordPattern.allMatches(line).toList();
    
    // Find string matches
  final stringPattern = RegExp("\"[^\"]*\"|'[^']*'");
    final stringMatches = stringPattern.allMatches(line).toList();
    
    // Find comment matches
    final commentPattern = RegExp(r'//.*$|/\*.*?\*/|#.*$');
    final commentMatches = commentPattern.allMatches(line).toList();
    
    // Find number matches
    final numberPattern = RegExp(r'\b\d+(\.\d+)?\b');
    final numberMatches = numberPattern.allMatches(line).toList();
    
    // Combine all matches and sort by position
    final allMatches = <RegExpMatch>[];
    allMatches.addAll(keywordMatches);
    allMatches.addAll(stringMatches);
    allMatches.addAll(commentMatches);
    allMatches.addAll(numberMatches);
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    for (final match in allMatches) {
      // Add text before match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: line.substring(lastIndex, match.start),
          style: theme.code.text,
        ));
      }
      
      // Add formatted match
      final matchText = match.group(0)!;
      TextStyle style = theme.code.text;
      
      if (keywordMatches.contains(match)) {
        style = theme.code.keyword;
      } else if (stringMatches.contains(match)) {
        style = theme.code.string;
      } else if (commentMatches.contains(match)) {
        style = theme.code.comment;
      } else if (numberMatches.contains(match)) {
        style = theme.code.number;
      }
      
      spans.add(TextSpan(
        text: matchText,
        style: style,
      ));
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastIndex),
        style: theme.code.text,
      ));
    }
    
    return TextSpan(children: spans.isEmpty ? [TextSpan(text: line, style: theme.code.text)] : spans);
  }

  /// Resalta JSON
  TextSpan _highlightJson(String text, SyntaxTheme theme) {
    // Simple JSON highlighting
    return TextSpan(
      text: text,
      style: theme.json.text,
    );
  }

  /// Resalta YAML
  TextSpan _highlightYaml(String text, SyntaxTheme theme) {
    // Simple YAML highlighting
    return TextSpan(
      text: text,
      style: theme.yaml.text,
    );
  }

  /// Resalta texto plano
  TextSpan _highlightPlainText(String text, SyntaxTheme theme) {
    return TextSpan(
      text: text,
      style: theme.plainText,
    );
  }
}

/// Tipos de contenido soportados
enum ContentType {
  plainText,
  markdown,
  code,
  json,
  yaml,
}

/// Tema de resaltado de sintaxis
class SyntaxTheme {
  final TextStyle plainText;
  final MarkdownTheme markdown;
  final CodeTheme code;
  final JsonTheme json;
  final YamlTheme yaml;

  const SyntaxTheme({
    required this.plainText,
    required this.markdown,
    required this.code,
    required this.json,
    required this.yaml,
  });

  static SyntaxTheme defaultTheme() {
    return SyntaxTheme(
      plainText: const TextStyle(
        color: Colors.black87,
        fontSize: 16,
        height: 1.5,
      ),
      markdown: MarkdownTheme.defaultTheme(),
      code: CodeTheme.defaultTheme(),
      json: JsonTheme.defaultTheme(),
      yaml: YamlTheme.defaultTheme(),
    );
  }

  static SyntaxTheme darkTheme() {
    return SyntaxTheme(
      plainText: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        height: 1.5,
      ),
      markdown: MarkdownTheme.darkTheme(),
      code: CodeTheme.darkTheme(),
      json: JsonTheme.darkTheme(),
      yaml: YamlTheme.darkTheme(),
    );
  }
}

/// Tema para Markdown
class MarkdownTheme {
  final TextStyle header;
  final TextStyle bold;
  final TextStyle italic;
  final TextStyle inlineCode;
  final TextStyle codeBlock;
  final TextStyle link;
  final TextStyle image;
  final TextStyle blockquote;
  final TextStyle listMarker;
  final TextStyle table;

  const MarkdownTheme({
    required this.header,
    required this.bold,
    required this.italic,
    required this.inlineCode,
    required this.codeBlock,
    required this.link,
    required this.image,
    required this.blockquote,
    required this.listMarker,
    required this.table,
  });

  static MarkdownTheme defaultTheme() {
    return MarkdownTheme(
      header: const TextStyle(
        color: Colors.blue,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      bold: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      italic: const TextStyle(
        fontStyle: FontStyle.italic,
        color: Colors.black87,
      ),
      inlineCode: const TextStyle(
        fontFamily: 'monospace',
        backgroundColor: Colors.grey,
        color: Colors.red,
      ),
      codeBlock: const TextStyle(
        fontFamily: 'monospace',
        backgroundColor: Colors.grey,
        color: Colors.black87,
      ),
      link: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
      image: const TextStyle(
        color: Colors.green,
      ),
      blockquote: const TextStyle(
        color: Colors.grey,
        fontStyle: FontStyle.italic,
      ),
      listMarker: const TextStyle(
        color: Colors.orange,
        fontWeight: FontWeight.bold,
      ),
      table: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.purple,
      ),
    );
  }

  static MarkdownTheme darkTheme() {
    return MarkdownTheme(
      header: const TextStyle(
        color: Colors.lightBlue,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      bold: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      italic: const TextStyle(
        fontStyle: FontStyle.italic,
        color: Colors.white,
      ),
      inlineCode: const TextStyle(
        fontFamily: 'monospace',
        backgroundColor: Colors.grey,
        color: Colors.redAccent,
      ),
      codeBlock: const TextStyle(
        fontFamily: 'monospace',
        backgroundColor: Colors.grey,
        color: Colors.white,
      ),
      link: const TextStyle(
        color: Colors.lightBlue,
        decoration: TextDecoration.underline,
      ),
      image: const TextStyle(
        color: Colors.lightGreen,
      ),
      blockquote: const TextStyle(
        color: Colors.grey,
        fontStyle: FontStyle.italic,
      ),
      listMarker: const TextStyle(
        color: Colors.orangeAccent,
        fontWeight: FontWeight.bold,
      ),
      table: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.purpleAccent,
      ),
    );
  }
}

/// Tema para código
class CodeTheme {
  final TextStyle text;
  final TextStyle keyword;
  final TextStyle string;
  final TextStyle comment;
  final TextStyle number;
  final TextStyle operator;

  const CodeTheme({
    required this.text,
    required this.keyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.operator,
  });

  static CodeTheme defaultTheme() {
    return CodeTheme(
      text: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.black87,
      ),
      keyword: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
      string: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.green,
      ),
      comment: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.grey,
        fontStyle: FontStyle.italic,
      ),
      number: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.orange,
      ),
      operator: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.red,
      ),
    );
  }

  static CodeTheme darkTheme() {
    return CodeTheme(
      text: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.white,
      ),
      keyword: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.lightBlue,
        fontWeight: FontWeight.bold,
      ),
      string: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.lightGreen,
      ),
      comment: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.grey,
        fontStyle: FontStyle.italic,
      ),
      number: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.orangeAccent,
      ),
      operator: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.redAccent,
      ),
    );
  }
}

/// Tema para JSON
class JsonTheme {
  final TextStyle text;
  final TextStyle key;
  final TextStyle value;
  final TextStyle string;
  final TextStyle number;
  final TextStyle boolean;

  const JsonTheme({
    required this.text,
    required this.key,
    required this.value,
    required this.string,
    required this.number,
    required this.boolean,
  });

  static JsonTheme defaultTheme() {
    return JsonTheme(
      text: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.black87,
      ),
      key: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.blue,
      ),
      value: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.black87,
      ),
      string: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.green,
      ),
      number: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.orange,
      ),
      boolean: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.purple,
      ),
    );
  }

  static JsonTheme darkTheme() {
    return JsonTheme(
      text: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.white,
      ),
      key: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.lightBlue,
      ),
      value: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.white,
      ),
      string: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.lightGreen,
      ),
      number: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.orangeAccent,
      ),
      boolean: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.purpleAccent,
      ),
    );
  }
}

/// Tema para YAML
class YamlTheme {
  final TextStyle text;
  final TextStyle key;
  final TextStyle value;
  final TextStyle comment;

  const YamlTheme({
    required this.text,
    required this.key,
    required this.value,
    required this.comment,
  });

  static YamlTheme defaultTheme() {
    return YamlTheme(
      text: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.black87,
      ),
      key: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.blue,
      ),
      value: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.green,
      ),
      comment: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.grey,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  static YamlTheme darkTheme() {
    return YamlTheme(
      text: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.white,
      ),
      key: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.lightBlue,
      ),
      value: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.lightGreen,
      ),
      comment: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.grey,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}