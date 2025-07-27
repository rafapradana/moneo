import 'package:supabase_flutter/supabase_flutter.dart';

/// Custom authentication exceptions for Moneo app
///
/// Provides specific exception types for different authentication scenarios
/// to enable better error handling and user feedback.

/// Base authentication exception
class MoneoAuthException implements Exception {
  final String message;
  final String code;

  const MoneoAuthException(this.message, this.code);

  @override
  String toString() => 'MoneoAuthException: $message (Code: $code)';
}

/// Exception thrown when user credentials are invalid
class InvalidCredentialsException extends MoneoAuthException {
  const InvalidCredentialsException([
    String message = 'Invalid email or password',
  ]) : super(message, 'INVALID_CREDENTIALS');
}

/// Exception thrown when user account already exists
class UserAlreadyExistsException extends MoneoAuthException {
  const UserAlreadyExistsException([
    String message = 'User account already exists',
  ]) : super(message, 'USER_ALREADY_EXISTS');
}

/// Exception thrown when user account is not found
class UserNotFoundException extends MoneoAuthException {
  const UserNotFoundException([String message = 'User account not found'])
    : super(message, 'USER_NOT_FOUND');
}

/// Exception thrown when session is invalid or expired
class InvalidSessionException extends MoneoAuthException {
  const InvalidSessionException([
    String message = 'Session is invalid or expired',
  ]) : super(message, 'INVALID_SESSION');
}

/// Exception thrown when network connection fails
class NetworkException extends MoneoAuthException {
  const NetworkException([String message = 'Network connection failed'])
    : super(message, 'NETWORK_ERROR');
}

/// Exception thrown for general authentication failures
class AuthenticationFailedException extends MoneoAuthException {
  const AuthenticationFailedException([
    String message = 'Authentication failed',
  ]) : super(message, 'AUTH_FAILED');
}

/// Utility class to convert Supabase AuthException to Moneo exceptions
class AuthExceptionMapper {
  /// Map Supabase AuthException to appropriate Moneo exception
  static MoneoAuthException mapException(dynamic exception) {
    if (exception is AuthException) {
      switch (exception.message.toLowerCase()) {
        case 'invalid login credentials':
        case 'invalid email or password':
          return const InvalidCredentialsException();
        case 'user already registered':
        case 'email address is already registered':
          return const UserAlreadyExistsException();
        case 'user not found':
          return const UserNotFoundException();
        case 'jwt expired':
        case 'invalid jwt':
        case 'session not found':
          return const InvalidSessionException();
        default:
          return AuthenticationFailedException(exception.message);
      }
    }

    // Handle network-related errors
    if (exception.toString().contains('network') ||
        exception.toString().contains('connection')) {
      return const NetworkException();
    }

    // Default to general authentication failure
    return AuthenticationFailedException(exception.toString());
  }
}
