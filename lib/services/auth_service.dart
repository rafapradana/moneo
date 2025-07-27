import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication service interface for Moneo app
///
/// Provides authentication functionality using Supabase Auth including
/// user registration, login, logout, and authentication state management.
abstract class AuthService {
  /// Check if user is currently authenticated
  Future<bool> get isAuthenticated;

  /// Get the current authenticated user
  Future<User?> get currentUser;

  /// Sign up a new user with email and password
  ///
  /// Returns [AuthResponse] containing user data and session information
  /// Throws [AuthException] if signup fails
  Future<AuthResponse> signUp(String email, String password);

  /// Sign in an existing user with email and password
  ///
  /// Returns [AuthResponse] containing user data and session information
  /// Throws [AuthException] if signin fails
  Future<AuthResponse> signIn(String email, String password);

  /// Sign out the current user
  ///
  /// Clears the current session and user data
  /// Throws [AuthException] if signout fails
  Future<void> signOut();

  /// Stream of authentication state changes
  ///
  /// Emits [AuthState] whenever the user's authentication status changes
  Stream<AuthState> get authStateChanges;

  /// Get the current user's ID
  ///
  /// Returns null if no user is authenticated
  String? get currentUserId;

  /// Check if the current session is valid
  ///
  /// Returns true if the user has a valid session
  Future<bool> get hasValidSession;

  /// Refresh the current session
  ///
  /// Returns [AuthResponse] with refreshed session data
  /// Throws [AuthException] if refresh fails
  Future<AuthResponse> refreshSession();
}
