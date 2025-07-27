import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:matcher/matcher.dart' as matcher;

import '../../lib/models/database.dart';
import '../../lib/services/wallet_service.dart';
import '../../lib/services/wallet_service_impl.dart';

void main() {
  late MoneoDatabase database;
  late WalletService walletService;

  setUp(() async {
    // Create in-memory database for testing
    database = MoneoDatabase.withExecutor(NativeDatabase.memory());
    walletService = WalletServiceImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('WalletService Tests', () {
    group('getAllWallets', () {
      test('should return empty list when no wallets exist', () async {
        final wallets = await walletService.getAllWallets();
        expect(wallets, isEmpty);
      });

      test('should return all wallets ordered by creation date', () async {
        // Create test wallets
        final wallet1 = await walletService.createWallet('Wallet 1');
        await Future.delayed(const Duration(milliseconds: 10));
        final wallet2 = await walletService.createWallet('Wallet 2');

        final wallets = await walletService.getAllWallets();
        expect(wallets, hasLength(2));

        // Check that wallets are ordered by creation date (newest first)
        expect(
          wallets[0].createdAt.isAfter(wallets[1].createdAt) ||
              wallets[0].createdAt.isAtSameMomentAs(wallets[1].createdAt),
          isTrue,
        );

        // Verify the wallets are present
        final walletNames = wallets.map((w) => w.name).toList();
        expect(walletNames, containsAll(['Wallet 1', 'Wallet 2']));
      });
    });

    group('getPinnedWallets', () {
      test('should return empty list when no pinned wallets exist', () async {
        await walletService.createWallet('Wallet 1');
        final pinnedWallets = await walletService.getPinnedWallets();
        expect(pinnedWallets, isEmpty);
      });

      test('should return only pinned wallets', () async {
        final wallet1 = await walletService.createWallet('Wallet 1');
        final wallet2 = await walletService.createWallet('Wallet 2');

        await walletService.togglePinWallet(wallet1.id);

        final pinnedWallets = await walletService.getPinnedWallets();
        expect(pinnedWallets, hasLength(1));
        expect(pinnedWallets[0].name, equals('Wallet 1'));
        expect(pinnedWallets[0].isPinned, isTrue);
      });

      test('should return maximum 4 pinned wallets', () async {
        // Create 5 wallets and pin all of them
        final wallets = <Wallet>[];
        for (int i = 1; i <= 5; i++) {
          wallets.add(await walletService.createWallet('Wallet $i'));
        }

        // Pin first 4 wallets
        for (int i = 0; i < 4; i++) {
          await walletService.togglePinWallet(wallets[i].id);
        }

        // Try to pin 5th wallet - should fail
        expect(
          () => walletService.togglePinWallet(wallets[4].id),
          throwsA(isA<WalletException>()),
        );

        final pinnedWallets = await walletService.getPinnedWallets();
        expect(pinnedWallets, hasLength(4));
      });
    });

    group('createWallet', () {
      test(
        'should create wallet with valid name and default balance',
        () async {
          final wallet = await walletService.createWallet('Test Wallet');

          expect(wallet.name, equals('Test Wallet'));
          expect(wallet.balance, equals(0.0));
          expect(wallet.isPinned, isFalse);
          expect(wallet.id, isPositive);
        },
      );

      test('should create wallet with initial balance', () async {
        final wallet = await walletService.createWallet(
          'Test Wallet',
          initialBalance: 100.0,
        );

        expect(wallet.name, equals('Test Wallet'));
        expect(wallet.balance, equals(100.0));
      });

      test('should trim wallet name', () async {
        final wallet = await walletService.createWallet('  Test Wallet  ');
        expect(wallet.name, equals('Test Wallet'));
      });

      test('should throw exception for empty name', () async {
        expect(
          () => walletService.createWallet(''),
          throwsA(
            isA<WalletException>().having(
              (e) => e.code,
              'code',
              'INVALID_WALLET_NAME',
            ),
          ),
        );
      });

      test('should throw exception for whitespace-only name', () async {
        expect(
          () => walletService.createWallet('   '),
          throwsA(
            isA<WalletException>().having(
              (e) => e.code,
              'code',
              'INVALID_WALLET_NAME',
            ),
          ),
        );
      });

      test('should throw exception for name too long', () async {
        final longName = 'a' * 101;
        expect(
          () => walletService.createWallet(longName),
          throwsA(
            isA<WalletException>().having(
              (e) => e.code,
              'code',
              'WALLET_NAME_TOO_LONG',
            ),
          ),
        );
      });

      test('should throw exception for negative initial balance', () async {
        expect(
          () => walletService.createWallet('Test', initialBalance: -10.0),
          throwsA(
            isA<WalletException>().having(
              (e) => e.code,
              'code',
              'INVALID_INITIAL_BALANCE',
            ),
          ),
        );
      });

      test('should throw exception for duplicate name', () async {
        await walletService.createWallet('Test Wallet');

        expect(
          () => walletService.createWallet('Test Wallet'),
          throwsA(
            isA<WalletException>().having(
              (e) => e.code,
              'code',
              'DUPLICATE_WALLET_NAME',
            ),
          ),
        );
      });

      test(
        'should throw exception for duplicate name case insensitive',
        () async {
          await walletService.createWallet('Test Wallet');

          expect(
            () => walletService.createWallet('test wallet'),
            throwsA(
              isA<WalletException>().having(
                (e) => e.code,
                'code',
                'DUPLICATE_WALLET_NAME',
              ),
            ),
          );
        },
      );
    });

    group('updateWallet', () {
      test('should update wallet name successfully', () async {
        final wallet = await walletService.createWallet('Original Name');

        await walletService.updateWallet(wallet.id, 'Updated Name');

        final updatedWallet = await walletService.getWalletById(wallet.id);
        expect(updatedWallet?.name, equals('Updated Name'));
      });

      test('should trim updated name', () async {
        final wallet = await walletService.createWallet('Original Name');

        await walletService.updateWallet(wallet.id, '  Updated Name  ');

        final updatedWallet = await walletService.getWalletById(wallet.id);
        expect(updatedWallet?.name, equals('Updated Name'));
      });

      test('should throw exception for non-existent wallet', () async {
        expect(
          () => walletService.updateWallet(999, 'New Name'),
          throwsA(
            isA<WalletException>().having(
              (e) => e.code,
              'code',
              'WALLET_NOT_FOUND',
            ),
          ),
        );
      });

      test('should throw exception for empty name', () async {
        final wallet = await walletService.createWallet('Test Wallet');

        expect(
          () => walletService.updateWallet(wallet.id, ''),
          throwsA(
            isA<WalletException>().having(
              (e) => e.code,
              'code',
              'INVALID_WALLET_NAME',
            ),
          ),
        );
      });

      test('should throw exception for duplicate name', () async {
        await walletService.createWallet('Wallet 1');
        final wallet2 = await walletService.createWallet('Wallet 2');

        expect(
          () => walletService.updateWallet(wallet2.id, 'Wallet 1'),
          throwsA(
            isA<WalletException>().having(
              (e) => e.code,
              'code',
              'DUPLICATE_WALLET_NAME',
            ),
          ),
        );
      });
    });

    group('deleteWallet', () {
      test('should delete wallet without transactions', () async {
        final wallet = await walletService.createWallet('Test Wallet');

        await walletService.deleteWallet(wallet.id);

        final deletedWallet = await walletService.getWalletById(wallet.id);
        expect(deletedWallet, matcher.isNull);
      });

      test('should throw exception for non-existent wallet', () async {
        expect(
          () => walletService.deleteWallet(999),
          throwsA(
            isA<WalletException>().having(
              (e) => e.code,
              'code',
              'WALLET_NOT_FOUND',
            ),
          ),
        );
      });
    });

    group('togglePinWallet', () {
      test('should pin unpinned wallet', () async {
        final wallet = await walletService.createWallet('Test Wallet');
        expect(wallet.isPinned, isFalse);

        await walletService.togglePinWallet(wallet.id);

        final pinnedWallet = await walletService.getWalletById(wallet.id);
        expect(pinnedWallet?.isPinned, isTrue);
      });

      test('should unpin pinned wallet', () async {
        final wallet = await walletService.createWallet('Test Wallet');
        await walletService.togglePinWallet(wallet.id);

        await walletService.togglePinWallet(wallet.id);

        final unpinnedWallet = await walletService.getWalletById(wallet.id);
        expect(unpinnedWallet?.isPinned, isFalse);
      });

      test('should throw exception for non-existent wallet', () async {
        expect(
          () => walletService.togglePinWallet(999),
          throwsA(
            isA<WalletException>().having(
              (e) => e.code,
              'code',
              'WALLET_NOT_FOUND',
            ),
          ),
        );
      });
    });

    group('getTotalBalance', () {
      test('should return 0 when no wallets exist', () async {
        final totalBalance = await walletService.getTotalBalance();
        expect(totalBalance, equals(0.0));
      });

      test('should calculate total balance across all wallets', () async {
        await walletService.createWallet('Wallet 1', initialBalance: 100.0);
        await walletService.createWallet('Wallet 2', initialBalance: 200.0);
        await walletService.createWallet('Wallet 3', initialBalance: 50.0);

        final totalBalance = await walletService.getTotalBalance();
        expect(totalBalance, equals(350.0));
      });
    });

    group('getWalletById', () {
      test('should return wallet when it exists', () async {
        final createdWallet = await walletService.createWallet('Test Wallet');

        final foundWallet = await walletService.getWalletById(createdWallet.id);

        expect(foundWallet, matcher.isNotNull);
        expect(foundWallet?.id, equals(createdWallet.id));
        expect(foundWallet?.name, equals('Test Wallet'));
      });

      test('should return null when wallet does not exist', () async {
        final wallet = await walletService.getWalletById(999);
        expect(wallet, matcher.isNull);
      });
    });

    group('Stream methods', () {
      test('watchAllWallets should emit wallet updates', () async {
        final stream = walletService.watchAllWallets();

        // Initial state - empty
        expect(await stream.first, isEmpty);

        // Create a wallet
        await walletService.createWallet('Test Wallet');

        // Should emit updated list
        final wallets = await stream.first;
        expect(wallets, hasLength(1));
        expect(wallets[0].name, equals('Test Wallet'));
      });

      test('watchPinnedWallets should emit pinned wallet updates', () async {
        final stream = walletService.watchPinnedWallets();

        // Initial state - empty
        expect(await stream.first, isEmpty);

        // Create and pin a wallet
        final wallet = await walletService.createWallet('Test Wallet');
        await walletService.togglePinWallet(wallet.id);

        // Should emit updated list
        final pinnedWallets = await stream.first;
        expect(pinnedWallets, hasLength(1));
        expect(pinnedWallets[0].isPinned, isTrue);
      });

      test('watchTotalBalance should emit balance updates', () async {
        final stream = walletService.watchTotalBalance();

        // Initial state - 0
        expect(await stream.first, equals(0.0));

        // Create wallet with balance
        await walletService.createWallet('Test Wallet', initialBalance: 100.0);

        // Should emit updated balance
        expect(await stream.first, equals(100.0));
      });
    });
  });
}
