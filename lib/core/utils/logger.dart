import 'dart:developer' as developer;

/// Logger com cores e tags para VERTIX
class Logger {
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';
  static const String _white = '\x1B[37m';

  // Tags
  static const String tagAuth = 'AUTH';
  static const String tagApi = 'API';
  static const String tagFeed = 'FEED';
  static const String tagPlayer = 'PLAYER';
  static const String tagComment = 'COMMENT';
  static const String tagSearch = 'SEARCH';
  static const String tagAdmin = 'ADMIN';
  static const String tagNav = 'NAV';
  static const String tagError = 'ERROR';

  static void _log(String tag, String color, String emoji, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final logMessage = '$color[$timestamp] $emoji [$tag] $message$_reset';
    print(logMessage);
    developer.log(message, name: tag);
  }

  /// Log de info (azul)
  static void i(String tag, String message) {
    _log(tag, _blue, 'ℹ️', message);
  }

  /// Log de sucesso (verde)
  static void s(String tag, String message) {
    _log(tag, _green, '✅', message);
  }

  /// Log de warning (amarelo)
  static void w(String tag, String message) {
    _log(tag, _yellow, '⚠️', message);
  }

  /// Log de erro (vermelho)
  static void e(String tag, String message, [dynamic error]) {
    _log(tag, _red, '❌', message);
    if (error != null) {
      _log(tag, _red, '  ', error.toString());
    }
  }

  /// Log de debug (magenta)
  static void d(String tag, String message) {
    _log(tag, _magenta, '🔍', message);
  }

  /// Log de requisição HTTP (cyan)
  static void request(String method, String url, [dynamic data]) {
    _log(tagApi, _cyan, '→', '$method $url');
    if (data != null) {
      _log(tagApi, _cyan, '  ', 'Body: $data');
    }
  }

  /// Log de resposta HTTP (cyan)
  static void response(int statusCode, String url, [dynamic data]) {
    final color = statusCode >= 200 && statusCode < 300 ? _green : _red;
    final emoji = statusCode >= 200 && statusCode < 300 ? '←' : '✗';
    _log(tagApi, color, emoji, '[$statusCode] $url');
    if (data != null && statusCode >= 400) {
      _log(tagApi, color, '  ', 'Response: $data');
    }
  }

  /// Log de autenticação
  static void auth(String message) => i(tagAuth, message);
  static void authSuccess(String message) => s(tagAuth, message);
  static void authError(String message, [dynamic error]) => e(tagAuth, message, error);

  /// Log de feed
  static void feed(String message) => i(tagFeed, message);
  static void feedSuccess(String message) => s(tagFeed, message);
  static void feedError(String message, [dynamic error]) => e(tagFeed, message, error);

  /// Log de player
  static void player(String message) => i(tagPlayer, message);
  static void playerSuccess(String message) => s(tagPlayer, message);
  static void playerError(String message, [dynamic error]) => e(tagPlayer, message, error);

  /// Log de comentários
  static void comment(String message) => i(tagComment, message);
  static void commentSuccess(String message) => s(tagComment, message);
  static void commentError(String message, [dynamic error]) => e(tagComment, message, error);

  /// Log de busca
  static void search(String message) => i(tagSearch, message);
  static void searchSuccess(String message) => s(tagSearch, message);
  static void searchError(String message, [dynamic error]) => e(tagSearch, message, error);

  /// Log de admin
  static void admin(String message) => i(tagAdmin, message);
  static void adminSuccess(String message) => s(tagAdmin, message);
  static void adminError(String message, [dynamic error]) => e(tagAdmin, message, error);

  /// Log de navegação
  static void nav(String message) => i(tagNav, message);
}
