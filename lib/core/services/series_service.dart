import '../network/api_client.dart';
import '../constants/api_constants.dart';
import '../models/series_model.dart';

/// Series Service for VERTIX
class SeriesService {
  final ApiClient _client = ApiClient();

  static final SeriesService _instance = SeriesService._internal();
  factory SeriesService() => _instance;
  SeriesService._internal();

  /// Get all series with pagination
  Future<SeriesListResponse> getSeries({
    int limit = 20,
    int offset = 0,
    String? genre,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (genre != null) queryParams['genre'] = genre;
      if (status != null) queryParams['status'] = status;

      final response = await _client.get(
        ApiConstants.series,
        queryParameters: queryParams,
      );

      return SeriesListResponse.fromJson(response.data);
    } catch (e) {
      return SeriesListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get single series by ID with episodes
  Future<SeriesResponse> getSeriesById(int id) async {
    try {
      final response = await _client.get('${ApiConstants.series}/$id');
      return SeriesResponse.fromJson(response.data);
    } catch (e) {
      return SeriesResponse(
        success: false,
        message: 'Erro ao carregar serie',
      );
    }
  }

  /// Get trending series
  Future<SeriesListResponse> getTrending({int limit = 10}) async {
    try {
      final response = await _client.get(
        ApiConstants.seriesTrending,
        queryParameters: {'limit': limit},
      );
      return SeriesListResponse.fromJson(response.data);
    } catch (e) {
      return SeriesListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get new series
  Future<SeriesListResponse> getNew({int limit = 10}) async {
    try {
      final response = await _client.get(
        ApiConstants.seriesNew,
        queryParameters: {'limit': limit},
      );
      return SeriesListResponse.fromJson(response.data);
    } catch (e) {
      return SeriesListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get series by genre
  Future<SeriesListResponse> getByGenre(String genre, {int limit = 10}) async {
    try {
      final response = await _client.get(
        '${ApiConstants.feed}/genre/$genre',
        queryParameters: {'limit': limit},
      );
      return SeriesListResponse.fromJson(response.data);
    } catch (e) {
      return SeriesListResponse(
        success: false,
        data: [],
      );
    }
  }
}
