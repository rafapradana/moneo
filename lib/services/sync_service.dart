/// Synchronization service interface for Moneo app
///
/// Provides data synchronization functionality between local Drift database
/// and Supabase cloud storage, including conflict resolution and data merging.
abstract class SyncService {
  /// Upload local data to cloud storage
  ///
  /// Synchronizes all local Drift data to Supabase cloud database.
  /// Only works for authenticated users.
  /// Throws [SyncException] if sync fails.
  Future<void> syncToCloud();

  /// Download cloud data to local database
  ///
  /// Downloads all cloud data and merges with local database.
  /// Handles conflict resolution automatically.
  /// Throws [SyncException] if sync fails.
  Future<void> syncFromCloud();

  /// Replace local data with cloud data
  ///
  /// Completely replaces local database with cloud data.
  /// This is a destructive operation that cannot be undone.
  /// Throws [SyncException] if operation fails.
  Future<void> replaceLocalWithCloud();

  /// Get current sync status
  ///
  /// Returns information about last sync time, pending changes, etc.
  Future<SyncStatus> getSyncStatus();

  /// Enable or disable automatic sync
  ///
  /// When enabled, sync operations will be performed automatically
  /// in the background when user is authenticated and online.
  Future<void> enableAutoSync(bool enabled);

  /// Check if auto sync is enabled
  Future<bool> get isAutoSyncEnabled;

  /// Get stream of sync status changes
  ///
  /// Emits [SyncStatus] whenever sync status changes
  Stream<SyncStatus> get syncStatusChanges;

  /// Force a full sync operation
  ///
  /// Performs a complete bidirectional sync between local and cloud
  /// with conflict resolution. Use this for manual sync operations.
  Future<void> performFullSync();

  /// Check if there are pending changes to sync
  Future<bool> get hasPendingChanges;

  /// Get the last sync timestamp
  Future<DateTime?> get lastSyncTime;
}

/// Sync status information
class SyncStatus {
  final bool isOnline;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final bool hasPendingChanges;
  final String? lastError;
  final int pendingChangesCount;

  const SyncStatus({
    required this.isOnline,
    required this.isSyncing,
    this.lastSyncTime,
    required this.hasPendingChanges,
    this.lastError,
    required this.pendingChangesCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatus &&
          runtimeType == other.runtimeType &&
          isOnline == other.isOnline &&
          isSyncing == other.isSyncing &&
          lastSyncTime == other.lastSyncTime &&
          hasPendingChanges == other.hasPendingChanges &&
          lastError == other.lastError &&
          pendingChangesCount == other.pendingChangesCount;

  @override
  int get hashCode =>
      isOnline.hashCode ^
      isSyncing.hashCode ^
      lastSyncTime.hashCode ^
      hasPendingChanges.hashCode ^
      lastError.hashCode ^
      pendingChangesCount.hashCode;

  @override
  String toString() {
    return 'SyncStatus{isOnline: $isOnline, isSyncing: $isSyncing, '
        'lastSyncTime: $lastSyncTime, hasPendingChanges: $hasPendingChanges, '
        'lastError: $lastError, pendingChangesCount: $pendingChangesCount}';
  }
}

/// Sync-related exceptions
class SyncException implements Exception {
  final String message;
  final String code;

  const SyncException(this.message, this.code);

  @override
  String toString() => 'SyncException: $message (Code: $code)';
}

/// Specific sync exception types
class NetworkSyncException extends SyncException {
  const NetworkSyncException([String message = 'Network error during sync'])
    : super(message, 'NETWORK_ERROR');
}

class AuthSyncException extends SyncException {
  const AuthSyncException([String message = 'Authentication required for sync'])
    : super(message, 'AUTH_REQUIRED');
}

class ConflictSyncException extends SyncException {
  const ConflictSyncException([String message = 'Data conflict during sync'])
    : super(message, 'CONFLICT_ERROR');
}

class DataSyncException extends SyncException {
  const DataSyncException([String message = 'Data error during sync'])
    : super(message, 'DATA_ERROR');
}
