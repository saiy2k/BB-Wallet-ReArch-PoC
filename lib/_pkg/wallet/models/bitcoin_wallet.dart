// ignore_for_file: avoid_print, invalid_annotation_target

import 'package:bb_arch/_pkg/constants.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
// import 'package:json_annotation/json_annotation.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'wallet.dart';

part 'bitcoin_wallet.freezed.dart';
part 'bitcoin_wallet.g.dart';

@freezed
class BitcoinWallet extends Wallet with _$BitcoinWallet {
  factory BitcoinWallet({
    required String id,
    required String name,
    required int balance,
    required WalletType type,
    required NetworkType network,
    @Default(false) bool backupTested,
    DateTime? lastSync,
    DateTime? lastBackupTested,
    @Default('') String mnemonic,
    @JsonKey(includeFromJson: false, includeToJson: false) bdk.Blockchain? bdkBlockchain,
    @JsonKey(includeFromJson: false, includeToJson: false) bdk.Wallet? bdkWallet,
  }) = _BitcoinWallet;
  BitcoinWallet._();

  factory BitcoinWallet.fromJson(Map<String, dynamic> json) => _$BitcoinWalletFromJson(json);

  static Future<Wallet> setupNewWallet(String mnemonicStr, NetworkType network, {String name = 'Wallet'}) async {
    return BitcoinWallet(
        id: 'hi', name: name, balance: 0, type: WalletType.Bitcoin, network: network, mnemonic: mnemonicStr);
  }

  static Future<BitcoinWallet> loadNativeSdk(BitcoinWallet w) async {
    print('Loading native sdk for bitcoin wallet');

    final mnem = await bdk.Mnemonic.fromString(w.mnemonic);

    final descriptorSecretKey = await bdk.DescriptorSecretKey.create(network: bdk.Network.Testnet, mnemonic: mnem);

    final externalDescriptor = await bdk.Descriptor.newBip84(
        secretKey: descriptorSecretKey, network: bdk.Network.Testnet, keychain: bdk.KeychainKind.External);
    final internalDescriptor = await bdk.Descriptor.newBip84(
        secretKey: descriptorSecretKey, network: bdk.Network.Testnet, keychain: bdk.KeychainKind.Internal);

    // TODO: Make this common across all wallets
    final bdkBlockchain = await bdk.Blockchain.create(
        config: const bdk.BlockchainConfig.electrum(
            config: bdk.ElectrumConfig(stopGap: 10, timeout: 5, retry: 5, url: btcElectrumUrl, validateDomain: true)));

    final wallet = await bdk.Wallet.create(
        descriptor: externalDescriptor,
        changeDescriptor: internalDescriptor,
        network: bdk.Network.Testnet,
        databaseConfig: const bdk.DatabaseConfig.memory());

    return w.copyWith(bdkWallet: wallet, bdkBlockchain: bdkBlockchain);
  }

  @override
  List<Map<String, dynamic>> getTransactions() {
    return [
      {
        'id': '1',
        'amount': 100,
        'date': '2021-01-01',
        'comment': 'btc txn sycned with bdk',
      },
      {
        'id': '2',
        'amount': 300,
        'date': '2021-01-02',
        'comment': 'btc txn sycned with bdk',
      }
    ];
  }

  static Future<Wallet> syncWallet(BitcoinWallet w) async {
    print('Syncing via bdk');

    if (w.bdkWallet == null) {
      print('Wallet is not loaded with bdk. Loading it now');
      w = await loadNativeSdk(w);
    }

    await w.bdkWallet?.sync(w.bdkBlockchain!);

    final bal = await w.bdkWallet?.getBalance();
    final balance = bal?.confirmed ?? 0;
    print('balance is $balance');

    return w.copyWith(balance: balance, lastSync: DateTime.now());
  }
}
