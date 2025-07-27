import 'package:flutter_test/flutter_test.dart';
import 'package:moneo/services/sync_service.dart';

void main() {
  group('SyncService Tests', () {
    group('SyncStatus Tests', () {
      test('should create SyncStatus with all properties', () {
        // Arrange
        final now = DateTime.now();
        
        // Act
        final status = SyncStatus(
          isOnline: true,
          isSyncing: false,
          lastSyncTime: now,
          hasPendingChanges: true,
          lastError: 'Test error',
          pendingChangesCount: 5,
        );

        // Assert
        expect(status.isOnline, isTrue);
        expect(status.isSyncing, isFalse);
        expect(status.lastSyncTime, equals(now));
        expect(status.hasPendingChanges, isTrue);
        expect(status.lastError, equals('Test error'));
        expect(status.pendingChangesCount, equals(5));
      });

      test('should implement equality correctly', () {
        // Arrange
        final now = DateTime.now();
        final status1 = SyncStatus(
          isOnline: true,
          isSyncing: false,
          lastSyncTime: now,
          hasPendingChanges: true,
          lastError: 'Test error',
          pendingChangesCount: 5,
        );
        final status2 = SyncStatus(
          isOnline: true,
          isSyncing: false,
          lastSyncTime: now,
          hasPendingChanges: true,
          lastError: 'Test error',
          pendingChangesCount: 5,
        );

        // Act & Assert
        expect(status1, equals(status2));
        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('should implement toString correctly', () {
        // Arrange
        final now = DateTime.now();
        final status = SyncStatus(
          isOnline: true,
          isSyncing: false,
          lastSyncTime: now,
          hasPendingChanges: true,
          lastError: 'Test error',
          pendingChangesCount: 5,
        );

        // Act
        final string = status.toString();

        // Assert
        expect(string, contains('SyncStatus'));
        expect(string, contains('isOnline: true'));
        expect(string, contains('isSyncing: false'));
        expect(string, contains('hasPendingChanges: true'));
        expect(string, contains('pendingChangesCount: 5'));
      });
    });

    group('Sync Exceptions Tests', () {
      test('should create SyncException with message and code', () {
        // Act
        const exception = SyncException('Test message', 'TEST_CODE');

        // Assert
        expect(exception.message, equals('Test message'));
        expect(exception.code, equals('TEST_CODE'));
        expect(exception.toString(), contains('Test message'));
        expect(exception.toString(), contains('TEST_CODE'));
      });

      test('should create NetworkSyncException with default message', () {
        // Act
        const exception = NetworkSyncException();

        // Assert
        expect(exception.code, equals('NETWORK_ERROR'));
        expect(exception.message, equals('Network error during sync'));
      });

      test('should create AuthSyncException with default message', () {
        // Act
        const exception = AuthSyncException();

        // Assert
        expect(exception.code, equals('AUTH_REQUIRED'));
        expect(exception.message, equals('Authentication required for sync'));
      });

      test('should create ConflictSyncException with default message', () {
        // Act
        const exception = ConflictSyncException();

        // Assert
        expect(exception.code, equals('CONFLICT_ERROR'));
        expect(exception.message, equals('Data conflict during sync'));
      });

      test('should create DataSyncException with default message', () {
        // Act
        const exception = DataSyncException();

        // Assert
        expect(exception.code, equals('DATA_ERROR'));
        expect(exception.message, equals('Data error during sync'));
      });
    });
  });
}