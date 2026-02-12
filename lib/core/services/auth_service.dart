import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_client.dart';
import '../constants/api_constants.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';

/// Auth Service for VERTIX
class AuthService {
  final ApiClient _client = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _userKey = 'cached_user';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  /// Inicializa o servico carregando usuario do cache
  Future<void> init() async {
    await _loadCachedUser();
  }

  /// Carrega usuario do cache local
  Future<void> _loadCachedUser() async {
    try {
      final userJson = await _storage.read(key: _userKey);
      if (userJson != null) {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
        Logger.i(Logger.tagAuth, 'Usuario carregado do cache: ${_currentUser?.name}');
      }
    } catch (e) {
      Logger.e(Logger.tagAuth, 'Erro ao carregar usuario do cache', e);
    }
  }

  /// Salva usuario no cache local
  Future<void> _cacheUser(UserModel? user) async {
    try {
      if (user != null) {
        await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
      } else {
        await _storage.delete(key: _userKey);
      }
    } catch (e) {
      Logger.e(Logger.tagAuth, 'Erro ao salvar usuario no cache', e);
    }
  }

  /// Login with email and password
  Future<AuthResponse> login(String email, String password) async {
    try {
      Logger.auth('Fazendo login: $email');
      Logger.request('POST', '${ApiConstants.baseUrl}${ApiConstants.login}');

      final response = await _client.post(
        ApiConstants.login,
        data: {
          'email': email,
          'senha': password,  // Backend espera 'senha'
        },
      );

      Logger.response(response.statusCode ?? 200, ApiConstants.login);
      final authResponse = AuthResponse.fromJson(response.data);

      if (authResponse.success && authResponse.token != null) {
        await _client.setToken(authResponse.token!);
        _currentUser = authResponse.user;
        await _cacheUser(_currentUser);
        Logger.authSuccess('Login realizado: ${_currentUser?.name}');
      } else {
        Logger.w(Logger.tagAuth, 'Login falhou: ${authResponse.message}');
      }

      return authResponse;
    } catch (e) {
      Logger.authError('Erro no login', e);
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
      Logger.auth('Registrando usuario: $email');
      Logger.request('POST', '${ApiConstants.baseUrl}${ApiConstants.register}', {
        'nome': name,
        'email': email,
        'senha': '***',
      });

      final response = await _client.post(
        ApiConstants.register,
        data: {
          'nome': name,      // Backend espera 'nome'
          'email': email,
          'senha': password, // Backend espera 'senha'
        },
      );

      Logger.response(response.statusCode ?? 201, ApiConstants.register);
      final authResponse = AuthResponse.fromJson(response.data);

      if (authResponse.success && authResponse.token != null) {
        await _client.setToken(authResponse.token!);
        _currentUser = authResponse.user;
        await _cacheUser(_currentUser);
        Logger.authSuccess('Registro realizado: ${_currentUser?.name}');
      } else {
        Logger.w(Logger.tagAuth, 'Registro falhou: ${authResponse.message}');
      }

      return authResponse;
    } catch (e) {
      Logger.authError('Erro no registro', e);
      return AuthResponse(
        success: false,
        message: _handleError(e),
      );
    }
  }

  /// Google Sign In
  Future<AuthResponse> googleSignIn({
    required String email,
    required String name,
    required String googleId,
    String? photo,
  }) async {
    try {
      Logger.auth('Login com Google: $email');
      Logger.request('POST', '${ApiConstants.baseUrl}${ApiConstants.googleAuth}');

      final response = await _client.post(
        ApiConstants.googleAuth,
        data: {
          'email': email,
          'name': name,
          'googleId': googleId,
          'photo': photo,
        },
      );

      Logger.response(response.statusCode ?? 200, ApiConstants.googleAuth);
      final authResponse = AuthResponse.fromJson(response.data);

      if (authResponse.success && authResponse.token != null) {
        await _client.setToken(authResponse.token!);
        _currentUser = authResponse.user;
        await _cacheUser(_currentUser);
        Logger.authSuccess('Login Google realizado: ${_currentUser?.name}');
      }

      return authResponse;
    } catch (e) {
      Logger.authError('Erro no login Google', e);
      return AuthResponse(
        success: false,
        message: _handleError(e),
      );
    }
  }

  /// Get current user profile
  Future<AuthResponse> getProfile() async {
    try {
      Logger.auth('Buscando perfil do usuario');
      final response = await _client.get(ApiConstants.userProfile);

      if (response.data['success'] == true && response.data['user'] != null) {
        _currentUser = UserModel.fromJson(response.data['user']);
        Logger.authSuccess('Perfil carregado: ${_currentUser?.name}');
        return AuthResponse(
          success: true,
          user: _currentUser,
        );
      }

      Logger.w(Logger.tagAuth, 'Falha ao buscar perfil');
      return AuthResponse(
        success: false,
        message: response.data['message'] ?? 'Failed to get profile',
      );
    } catch (e) {
      Logger.authError('Erro ao buscar perfil', e);
      return AuthResponse(
        success: false,
        message: _handleError(e),
      );
    }
  }

  /// Logout
  Future<void> logout() async {
    Logger.auth('Fazendo logout: ${_currentUser?.email}');
    await _client.clearToken();
    await _cacheUser(null);
    _currentUser = null;
    Logger.authSuccess('Logout realizado');
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
    final errorStr = e.toString();

    if (errorStr.contains('400')) {
      // Tentar extrair mensagem do servidor
      if (errorStr.contains('message')) {
        return 'Dados invalidos - verifique os campos';
      }
      return 'Requisicao invalida';
    } else if (errorStr.contains('401')) {
      return 'Email ou senha incorretos';
    } else if (errorStr.contains('409')) {
      return 'Este email ja esta cadastrado';
    } else if (errorStr.contains('SocketException')) {
      return 'Sem conexao com a internet';
    } else if (errorStr.contains('XMLHttpRequest')) {
      return 'Erro de conexao com o servidor';
    } else if (errorStr.contains('404')) {
      return 'Servico nao encontrado';
    } else if (errorStr.contains('500')) {
      return 'Erro interno do servidor';
    }

    return 'Erro ao conectar com o servidor';
  }
}
