import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneo/services/auth_service.dart';
import 'package:moneo/services/auth_service_impl.dart';
import 'package:moneo/services/auth_exceptions.dart';

// Generate mocks
@GenerateMocks([SupabaseClient, GoTrueClient, User, Session])
import 'auth_service_test.mocks.dart';

void main() {
  group('AuthService Tests', () {
    late AuthService authService;
    late MockSupabaseClient mockClient;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late MockSession mockSession;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      mockSession = MockSession();

      // Setup mock client to return mock auth
      when(mockClient.auth).thenReturn(mockAuth);

      // Create service with mocked dependencies
      authService = AuthServiceImpl(mockClient);
    });

    group('Authentication Status', () {
      test('should return true when user is authenticated', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Act
        final result = await authService.isAuthenticated;

        // Assert
        expect(result, isTrue);
      });

      test('should return false when user is not authenticated', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final result = await authService.isAuthenticated;

        // Assert
        expect(result, isFalse);
      });

      test('should return current user when authenticated', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Act
        final result = await authService.currentUser;

        // Assert
        expect(result, equals(mockUser));
      });

      test('should return null when no user is authenticated', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final result = await authService.currentUser;

        // Assert
        expect(result, isNull);
      });

      test('should return current user ID when authenticated', () {
        // Arrange
        const userId = 'test-user-id';
        when(mockUser.id).thenReturn(userId);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Act
        final result = authService.currentUserId;

        // Assert
        expect(result, equals(userId));
      });

      test('should return null user ID when not authenticated', () {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final result = authService.currentUserId;

        // Assert
        expect(result, isNull);
      });
    });

    group('Session Management', () {
      test('should return true for valid session', () async {
        // Arrange
        final futureTime = DateTime.now().add(const Duration(hours: 1));
        final futureTimestamp = futureTime.millisecondsSinceEpoch / 1000;

        when(mockSession.expiresAt).thenReturn(futureTimestamp.toInt());
        when(mockAuth.currentSession).thenReturn(mockSession);

        // Act
        final result = await authService.hasValidSession;

        // Assert
        expect(result, isTrue);
      });

      test('should return false for expired session', () async {
        // Arrange
        final pastTime = DateTime.now().subtract(const Duration(hours: 1));
        final pastTimestamp = pastTime.millisecondsSinceEpoch / 1000;

        when(mockSession.expiresAt).thenReturn(pastTimestamp.toInt());
        when(mockAuth.currentSession).thenReturn(mockSession);

        // Act
        final result = await authService.hasValidSession;

        // Assert
        expect(result, isFalse);
      });

      test('should return false when no session exists', () async {
        // Arrange
        when(mockAuth.currentSession).thenReturn(null);

        // Act
        final result = await authService.hasValidSession;

        // Assert
        expect(result, isFalse);
      });
    });

    group('Sign Up', () {
      test('should successfully sign up user', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        final authResponse = AuthResponse(user: mockUser, session: mockSession);

        when(
          mockAuth.signUp(email: email, password: password),
        ).thenAnswer((_) async => authResponse);

        // Act
        final result = await authService.signUp(email, password);

        // Assert
        expect(result, equals(authResponse));
        expect(result.user, equals(mockUser));
      });

      test(
        'should throw AuthenticationFailedException when signup fails',
        () async {
          // Arrange
          const email = 'test@example.com';
          const password = 'password123';
          final authResponse = AuthResponse(user: null, session: null);

          when(
            mockAuth.signUp(email: email, password: password),
          ).thenAnswer((_) async => authResponse);

          // Act & Assert
          expect(
            () => authService.signUp(email, password),
            throwsA(isA<AuthenticationFailedException>()),
          );
        },
      );

      test(
        'should map AuthException to appropriate custom exception',
        () async {
          // Arrange
          const email = 'test@example.com';
          const password = 'password123';

          when(
            mockAuth.signUp(email: email, password: password),
          ).thenThrow(const AuthException('User already registered'));

          // Act & Assert
          expect(
            () => authService.signUp(email, password),
            throwsA(isA<UserAlreadyExistsException>()),
          );
        },
      );
    });

    group('Sign In', () {
      test('should successfully sign in user', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        final authResponse = AuthResponse(user: mockUser, session: mockSession);

        when(
          mockAuth.signInWithPassword(email: email, password: password),
        ).thenAnswer((_) async => authResponse);

        // Act
        final result = await authService.signIn(email, password);

        // Assert
        expect(result, equals(authResponse));
        expect(result.user, equals(mockUser));
      });

      test(
        'should throw InvalidCredentialsException when signin fails',
        () async {
          // Arrange
          const email = 'test@example.com';
          const password = 'wrongpassword';
          final authResponse = AuthResponse(user: null, session: null);

          when(
            mockAuth.signInWithPassword(email: email, password: password),
          ).thenAnswer((_) async => authResponse);

          // Act & Assert
          expect(
            () => authService.signIn(email, password),
            throwsA(isA<InvalidCredentialsException>()),
          );
        },
      );

      test('should map AuthException to InvalidCredentialsException', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'wrongpassword';

        when(
          mockAuth.signInWithPassword(email: email, password: password),
        ).thenThrow(const AuthException('Invalid login credentials'));

        // Act & Assert
        expect(
          () => authService.signIn(email, password),
          throwsA(isA<InvalidCredentialsException>()),
        );
      });
    });

    group('Sign Out', () {
      test('should successfully sign out user', () async {
        // Arrange
        when(mockAuth.signOut()).thenAnswer((_) async {});

        // Act & Assert
        expect(() => authService.signOut(), returnsNormally);
      });

      test('should handle sign out errors', () async {
        // Arrange
        when(
          mockAuth.signOut(),
        ).thenThrow(const AuthException('Sign out failed'));

        // Act & Assert
        expect(
          () => authService.signOut(),
          throwsA(isA<AuthenticationFailedException>()),
        );
      });
    });

    group('Session Refresh', () {
      test('should successfully refresh session', () async {
        // Arrange
        final authResponse = AuthResponse(user: mockUser, session: mockSession);

        when(mockAuth.refreshSession()).thenAnswer((_) async => authResponse);

        // Act
        final result = await authService.refreshSession();

        // Assert
        expect(result, equals(authResponse));
        expect(result.session, equals(mockSession));
      });

      test('should throw InvalidSessionException when refresh fails', () async {
        // Arrange
        final authResponse = AuthResponse(user: mockUser, session: null);

        when(mockAuth.refreshSession()).thenAnswer((_) async => authResponse);

        // Act & Assert
        expect(
          () => authService.refreshSession(),
          throwsA(isA<InvalidSessionException>()),
        );
      });
    });

    group('Auth State Changes', () {
      test('should provide auth state changes stream', () {
        // Arrange
        final authStateStream = Stream<AuthState>.empty();
        when(mockAuth.onAuthStateChange).thenAnswer((_) => authStateStream);

        // Act
        final result = authService.authStateChanges;

        // Assert
        expect(result, equals(authStateStream));
      });
    });
  });

  group('AuthExceptionMapper Tests', () {
    test('should map invalid credentials exception', () {
      // Arrange
      const authException = AuthException('Invalid login credentials');

      // Act
      final result = AuthExceptionMapper.mapException(authException);

      // Assert
      expect(result, isA<InvalidCredentialsException>());
    });

    test('should map user already exists exception', () {
      // Arrange
      const authException = AuthException('User already registered');

      // Act
      final result = AuthExceptionMapper.mapException(authException);

      // Assert
      expect(result, isA<UserAlreadyExistsException>());
    });

    test('should map session expired exception', () {
      // Arrange
      const authException = AuthException('JWT expired');

      // Act
      final result = AuthExceptionMapper.mapException(authException);

      // Assert
      expect(result, isA<InvalidSessionException>());
    });

    test('should map network exception', () {
      // Arrange
      final networkError = Exception('Network connection failed');

      // Act
      final result = AuthExceptionMapper.mapException(networkError);

      // Assert
      expect(result, isA<NetworkException>());
    });

    test('should map unknown exception to AuthenticationFailedException', () {
      // Arrange
      final unknownException = Exception('Unknown error');

      // Act
      final result = AuthExceptionMapper.mapException(unknownException);

      // Assert
      expect(result, isA<AuthenticationFailedException>());
    });
  });
}
