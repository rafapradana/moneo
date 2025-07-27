import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart';
import 'auth_exceptions.dart';

/// Implementation of AuthService using Supabase Auth
///
/// Provides concrete implementation of authentication functionality
/// including user registration, login, logout, and session management.
class AuthServiceImpl implements AuthService {
  final SupabaseClient _client;

  /// Create AuthService with optional client for testing
  AuthServiceImpl([SupabaseClient? client])
    : _client = client ?? SupabaseConfig.client;

  @override
  Future<bool> get isAuthenticated async {
    return _client.auth.currentUser != null;
  }

  @override
  Future<User?> get currentUser async {
    return _client.auth.currentUser;
  }

  @override
  String? get currentUserId {
    return _client.auth.currentUser?.id;
  }

  @override
  Future<bool> get hasValidSession async {
    final session = _client.auth.currentSession;
    if (session == null) return false;

    // Check if session is expired
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    return session.expiresAt != null && session.expiresAt! > now;
  }

  @override
  Stream<AuthState> get authStateChanges {
    return _client.auth.onAuthStateChange;
  }

  @override
  Future<AuthResponse> signUp(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const AuthenticationFailedException(
          'Failed to create user account',
        );
      }

      return response;
    } on MoneoAuthException {
      rethrow;
    } catch (e) {
      throw AuthExceptionMapper.mapException(e);
    }
  }

  @override
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const InvalidCredentialsException();
      }

      return response;
    } on MoneoAuthException {
      rethrow;
    } catch (e) {
      throw AuthExceptionMapper.mapException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on MoneoAuthException {
      rethrow;
    } catch (e) {
      throw AuthExceptionMapper.mapException(e);
    }
  }

  @override
  Future<AuthResponse> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();

      if (response.session == null) {
        throw const InvalidSessionException('Failed to refresh session');
      }

      return response;
    } on MoneoAuthException {
      rethrow;
    } catch (e) {
      throw AuthExceptionMapper.mapException(e);
    }
  }
}
