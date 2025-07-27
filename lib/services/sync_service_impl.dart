import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/database.dart';
import 'sync_service.dart';
import 'auth_service.dart';

/// Implementation of SyncService using Supabase
/// 
/// Provides concrete implementation of data synchronization functionality
/// between local Drift database and Supabase cloud storage.
class SyncServiceImpl implements SyncService {
  final SupabaseClient _client;
  final MoneoDatabase _database;
  final AuthService _authService;
  final StreamController<SyncStatus> _statusController = StreamController<SyncStatus>.broadcast();
  
  bool _isAutoSyncEnabled = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastError;
  
  /// Create SyncService with dependencies
  SyncServiceImpl({
    required MoneoDatabase database,
    required AuthService authService,
    SupabaseClient? client,
  }) : _database = database,
       _authService = authService,
       _client = client ?? SupabaseConfig.client;
  
  @override
  Future<void> syncToCloud() async {
    if (!await _authService.isAuthenticated) {
      throw const AuthSyncException();
    }
    
    if (_isSyncing) {
      return; // Already syncing
    }
    
    _isSyncing = true;
    _lastError = null;
    _emitStatus();
    
    try {
      final userId = _authService.currentUserId!;
      
      // Sync wallets
      await _syncWalletsToCloud(userId);
      
      // Sync categories
      await _syncCategoriesToCloud(userId);
      
      // Sync transactions (simplified)
      await _syncTransactionsToCloud(userId);
      
      // Sync recurring transactions (simplified)
      await _syncRecurringTransactionsToCloud(userId);
      
      _lastSyncTime = DateTime.now();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      throw _mapException(e);
    } finally {
      _isSyncing = false;
      _emitStatus();
    }
  }
  
  @override
  Future<void> syncFromCloud() async {
    if (!await _authService.isAuthenticated) {
      throw const AuthSyncException();
    }
    
    if (_isSyncing) {
      return; // Already syncing
    }
    
    _isSyncing = true;
    _lastError = null;
    _emitStatus();
    
    try {
      final userId = _authService.currentUserId!;
      
      // Sync wallets from cloud
      await _syncWalletsFromCloud(userId);
      
      // Sync categories from cloud
      await _syncCategoriesFromCloud(userId);
      
      // Note: Transaction and recurring transaction sync from cloud
      // would require more complex ID mapping implementation
      
      _lastSyncTime = DateTime.now();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      throw _mapException(e);
    } finally {
      _isSyncing = false;
      _emitStatus();
    }
  }
  
  @override
  Future<void> replaceLocalWithCloud() async {
    if (!await _authService.isAuthenticated) {
      throw const AuthSyncException();
    }
    
    if (_isSyncing) {
      return; // Already syncing
    }
    
    _isSyncing = true;
    _lastError = null;
    _emitStatus();
    
    try {
      final userId = _authService.currentUserId!;
      
      // Clear all local data
      await _clearLocalData();
      
      // Download all cloud data
      await _downloadAllCloudData(userId);
      
      _lastSyncTime = DateTime.now();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      throw _mapException(e);
    } finally {
      _isSyncing = false;
      _emitStatus();
    }
  }
  
  @override
  Future<SyncStatus> getSyncStatus() async {
    return SyncStatus(
      isOnline: await _isOnline(),
      isSyncing: _isSyncing,
      lastSyncTime: _lastSyncTime,
      hasPendingChanges: await hasPendingChanges,
      lastError: _lastError,
      pendingChangesCount: await _getPendingChangesCount(),
    );
  }
  
  @override
  Future<void> enableAutoSync(bool enabled) async {
    _isAutoSyncEnabled = enabled;
    // TODO: Implement background sync scheduling
  }
  
  @override
  Future<bool> get isAutoSyncEnabled async => _isAutoSyncEnabled;
  
  @override
  Stream<SyncStatus> get syncStatusChanges => _statusController.stream;
  
  @override
  Future<void> performFullSync() async {
    if (!await _authService.isAuthenticated) {
      throw const AuthSyncException();
    }
    
    // First sync to cloud, then sync from cloud
    await syncToCloud();
    await syncFromCloud();
  }
  
  @override
  Future<bool> get hasPendingChanges async {
    // For now, assume there are always pending changes if user is authenticated
    // In a real implementation, you would track changes with timestamps
    return await _authService.isAuthenticated;
  }
  
  @override
  Future<DateTime?> get lastSyncTime async => _lastSyncTime;
  
  // Private helper methods
  
  Future<void> _syncWalletsToCloud(String userId) async {
    final localWallets = await _database.walletDao.getAllWallets();
    
    for (final wallet in localWallets) {
      await _client.from('user_wallets').upsert({
        'user_id': userId,
        'name': wallet.name,
        'balance': wallet.balance,
        'is_pinned': wallet.isPinned,
        'created_at': wallet.createdAt.toIso8601String(),
        'updated_at': wallet.updatedAt.toIso8601String(),
      });
    }
  }
  
  Future<void> _syncCategoriesToCloud(String userId) async {
    final localCategories = await _database.categoryDao.getAllCategories();
    
    for (final category in localCategories) {
      await _client.from('user_categories').upsert({
        'user_id': userId,
        'name': category.name,
        'type': category.type,
        'monthly_budget': category.monthlyBudget,
        'color': category.color,
        'created_at': category.createdAt.toIso8601String(),
      });
    }
  }
  
  Future<void> _syncTransactionsToCloud(String userId) async {
    final localTransactions = await _database.transactionDao.getAllTransactions();
    
    // This is a simplified implementation
    // In a real app, you would need proper ID mapping between local and cloud
    for (final transactionWithDetails in localTransactions) {
      final transaction = transactionWithDetails.transaction;
      // Note: This is incomplete - would need category and wallet ID mapping
      await _client.from('user_transactions').upsert({
        'user_id': userId,
        'amount': transaction.amount,
        'type': transaction.type,
        'notes': transaction.notes,
        'transaction_date': transaction.transactionDate.toIso8601String(),
        'created_at': transaction.createdAt.toIso8601String(),
        // category_id and wallet_id would need proper mapping
      });
    }
  }
  
  Future<void> _syncRecurringTransactionsToCloud(String userId) async {
    // This would need to be implemented with proper DAO methods
    // For now, this is a placeholder
    // final localRecurring = await _database.recurringTransactionDao.getAllRecurringTransactions();
    // Implementation would go here
  }
  
  Future<void> _syncWalletsFromCloud(String userId) async {
    final response = await _client
        .from('user_wallets')
        .select()
        .eq('user_id', userId);
    
    for (final cloudWallet in response) {
      // Check if wallet already exists locally (simplified approach)
      final existingWallets = await _database.walletDao.getAllWallets();
      final exists = existingWallets.any((w) => w.name == cloudWallet['name']);
      
      if (!exists) {
        await _database.walletDao.createWallet(
          cloudWallet['name'],
          initialBalance: cloudWallet['balance'].toDouble(),
          isPinned: cloudWallet['is_pinned'] ?? false,
        );
      }
    }
  }
  
  Future<void> _syncCategoriesFromCloud(String userId) async {
    final response = await _client
        .from('user_categories')
        .select()
        .eq('user_id', userId);
    
    for (final cloudCategory in response) {
      // Check if category already exists locally (simplified approach)
      final existingCategories = await _database.categoryDao.getAllCategories();
      final exists = existingCategories.any((c) => 
          c.name == cloudCategory['name'] && c.type == cloudCategory['type']);
      
      if (!exists) {
        await _database.categoryDao.createCategory(
          name: cloudCategory['name'],
          type: cloudCategory['type'],
          monthlyBudget: cloudCategory['monthly_budget']?.toDouble(),
          color: cloudCategory['color'] ?? '#2196F3',
        );
      }
    }
  }
  
  Future<void> _clearLocalData() async {
    await _database.transaction(() async {
      // Clear in reverse dependency order
      await _database.delete(_database.transactions).go();
      await _database.delete(_database.recurringTransactions).go();
      await _database.delete(_database.categories).go();
      await _database.delete(_database.wallets).go();
    });
  }
  
  Future<void> _downloadAllCloudData(String userId) async {
    await _syncWalletsFromCloud(userId);
    await _syncCategoriesFromCloud(userId);
    // Transaction sync would need more complex implementation
  }
  
  Future<bool> _isOnline() async {
    try {
      await _client.from('profiles').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<int> _getPendingChangesCount() async {
    // This is a simplified implementation
    // In a real app, you would track changes with timestamps
    if (!await _authService.isAuthenticated) return 0;
    
    final wallets = await _database.walletDao.getAllWallets();
    final categories = await _database.categoryDao.getAllCategories();
    final transactions = await _database.transactionDao.getAllTransactions();
    
    return wallets.length + categories.length + transactions.length;
  }
  
  void _emitStatus() {
    getSyncStatus().then((status) {
      _statusController.add(status);
    });
  }
  
  SyncException _mapException(dynamic exception) {
    if (exception is PostgrestException) {
      return NetworkSyncException('Database error: ${exception.message}');
    }
    
    if (exception.toString().contains('network') ||
        exception.toString().contains('connection')) {
      return const NetworkSyncException();
    }
    
    if (exception.toString().contains('auth') ||
        exception.toString().contains('unauthorized')) {
      return const AuthSyncException();
    }
    
    return DataSyncException(exception.toString());
  }
  
  void dispose() {
    _statusController.close();
  }
}