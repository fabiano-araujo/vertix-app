/// API Constants for VERTIX
class ApiConstants {
  ApiConstants._();

  /// Base URL for the API
  /// Change this to your production URL when deploying
  static const String baseUrl = 'https://vertix-api.snapdark.com';

  /// API Endpoints
  static const String auth = '/auth';
  static const String login = '$auth/login';
  static const String register = '$auth/registro';
  static const String googleAuth = '$auth/google';

  // Series
  static const String series = '/series';
  static const String seriesTrending = '$series/trending';
  static const String seriesNew = '$series/new';

  // Episodes
  static const String episodes = '/episodes';

  // Feed
  static const String feed = '/feed';
  static const String feedForYou = '$feed/for-you';
  static const String feedTrending = '$feed/trending';
  static const String feedNew = '$feed/new';
  static const String feedHome = '$feed/home';
  static const String feedContinueWatching = '$feed/continue-watching';
  static const String feedHistory = '$feed/history';
  static const String feedLikes = '$feed/likes';

  // Search
  static const String search = '/search';
  static const String searchSuggestions = '$search/suggestions';
  static const String searchTrending = '$search/trending';
  static const String searchGenres = '$search/genres';

  // Comments
  static const String comments = '/comments';

  // Admin
  static const String admin = '/admin';
  static const String adminGenerateSeries = '$admin/series/generate';
  static const String adminJobs = '$admin/jobs';
  static const String adminAnalytics = '$admin/analytics';
  static const String adminUsers = '$admin/users';

  // User Profile
  static const String userProfile = '$auth/me';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
