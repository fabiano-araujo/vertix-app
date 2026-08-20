import '../network/api_client.dart';
import '../constants/api_constants.dart';

class CreditsSnapshot {
  final bool success;
  final int availableCredits;
  final bool locked;
  final String? message;

  const CreditsSnapshot({
    required this.success,
    this.availableCredits = 0,
    this.locked = false,
    this.message,
  });
}

class CreditsService {
  final ApiClient _client = ApiClient();

  static final CreditsService _instance = CreditsService._internal();
  factory CreditsService() => _instance;
  CreditsService._internal();

  Future<CreditsSnapshot> getMine() async {
    try {
      final response = await _client.get(ApiConstants.creditsMe);
      final data = response.data['data'] is Map
          ? response.data['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      return CreditsSnapshot(
        success: response.data['success'] == true,
        availableCredits: data['availableCredits'] as int? ?? 0,
        locked: data['locked'] as bool? ?? false,
      );
    } catch (e) {
      return const CreditsSnapshot(
        success: false,
        message: 'Erro ao carregar moedas',
      );
    }
  }
}
