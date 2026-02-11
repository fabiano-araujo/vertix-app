import '../network/api_client.dart';
import '../constants/api_constants.dart';
import '../models/user_model.dart';

/// Auth Service for VERTIX
class AuthService {
  final ApiClient _client = ApiClient();

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  /// Login with email and password
  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _client.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      final authResponse = AuthResponse.fromJson(response.data);

      if (authResponse.success && authResponse.token != null) {
        await _client.setToken(authResponse.token!);
        _currentUser = authResponse.user;
      }

      return authResponse;
    } catch (e) {
      return AuthResponse(
        success: false,
        message: _handleError(e),
      );
    }
  }

  /// Register new user
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        ApiConstants.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);

      if (authResponse.success && authResponse.token != null) {
        await _client.setToken(authResponse.token!);
        _currentUser = authResponse.user;
      }

      return authResponse;
    } catch (e) {
      return AuthResponse(
        success: false,
        message: _handleError(e),
      );
    }
  }

  /// Google Sign In
  Future<AuthResponse> googleSignIn(String idToken) async {
    try {
      final response = await _client.post(
        ApiConstants.googleAuth,
        data: {'idToken': idToken},
      );

      final authResponse = AuthResponse.fromJson(response.data);

      if (authResponse.success && authResponse.token != null) {
        await _client.setToken(authResponse.token!);
        _currentUser = authResponse.user;
      }

      return authResponse;
    } catch (e) {
      return AuthResponse(
        success: false,
        message: _handleError(e),
      );
    }
  }

  /// Get current user profile
  Future<AuthResponse> getProfile() async {
    try {
      final response = await _client.get(ApiConstants.user);

      if (response.data['success'] == true && response.data['user'] != null) {
        _currentUser = UserModel.fromJson(response.data['user']);
        return AuthResponse(
          success: true,
          user: _currentUser,
        );
      }

      return AuthResponse(
        success: false,
        message: response.data['message'] ?? 'Failed to get profile',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: _handleError(e),
      );
    }
  }

  /// Logout
  Future<void> logout() async {
    await _client.clearToken();
    _currentUser = null;
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await _client.isAuthenticated();
  }

  /// Check if current user is admin
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// Check if current user is creator
  bool get isCreator => _currentUser?.isCreator ?? false;

  String _handleError(dynamic e) {
    if (e.toString().contains('401')) {
      return 'Email ou senha incorretos';
    } else if (e.toString().contains('409')) {
      return 'Este email ja esta cadastrado';
    } else if (e.toString().contains('SocketException')) {
      return 'Sem conexao com a internet';
    }
    return 'Erro ao conectar com o servidor';
  }
}
