import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _privateKeyKey = 'rsa_private_key';

  static Future<bool> hasPrivateKey() async {
    return (await _storage.read(key: _privateKeyKey)) != null;
  }

  // 1. Generate RSA Keypair
  static Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>> generateRSAKeyPair() async {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom));

    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(pair.publicKey as RSAPublicKey, pair.privateKey as RSAPrivateKey);
  }

  // Helper to format keys (very basic serialization for this example)
  // In a real app, use PEM encoding
  static String encodePublicKey(RSAPublicKey key) {
    return '${key.modulus}:${key.exponent}';
  }

  static RSAPublicKey decodePublicKey(String keyString) {
    final parts = keyString.split(':');
    return RSAPublicKey(BigInt.parse(parts[0]), BigInt.parse(parts[1]));
  }

  static String encodePrivateKey(RSAPrivateKey key) {
    return '${key.modulus}:${key.privateExponent}:${key.p}:${key.q}';
  }

  static RSAPrivateKey decodePrivateKey(String keyString) {
    final parts = keyString.split(':');
    return RSAPrivateKey(BigInt.parse(parts[0]), BigInt.parse(parts[1]), BigInt.parse(parts[2]), BigInt.parse(parts[3]));
  }

  // 2. Init keys on login
  static Future<String> initKeys() async {
    String? privKeyStr = await _storage.read(key: _privateKeyKey);
    if (privKeyStr == null) {
      final pair = await generateRSAKeyPair();
      final pubKeyStr = encodePublicKey(pair.publicKey);
      privKeyStr = encodePrivateKey(pair.privateKey);
      await _storage.write(key: _privateKeyKey, value: privKeyStr);
      return pubKeyStr; // Return public key to be saved in Supabase profiles
    }
    // We already have keys
    // We would need to retrieve the public key or regenerate it from private key
    // For simplicity, we just return empty, meaning keys exist
    return ''; 
  }

  // 3. E2EE PIN Backup & Restore
  static encrypt.Key deriveKeyFromPin(String pin, String userId) {
    final salt = utf8.encode(userId);
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(Uint8List.fromList(salt), 250000, 32));
    final derivedKey = derivator.process(Uint8List.fromList(utf8.encode(pin)));
    return encrypt.Key(derivedKey);
  }

  static Future<String?> backupPrivateKey(String pin, String userId) async {
    final privKeyStr = await _storage.read(key: _privateKeyKey);
    if (privKeyStr == null) return null;

    final aesKey = deriveKeyFromPin(pin, userId);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.gcm));
    
    final encrypted = encrypter.encrypt(privKeyStr, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static Future<bool> restorePrivateKey(String pin, String userId, String encryptedData) async {
    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) return false;
      
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encryptedBase64 = parts[1];
      
      final aesKey = deriveKeyFromPin(pin, userId);
      final encrypter = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.gcm));
      
      final decryptedPrivKeyStr = encrypter.decrypt(encrypt.Encrypted.fromBase64(encryptedBase64), iv: iv);
      
      decodePrivateKey(decryptedPrivKeyStr); // Validate decoding
      await _storage.write(key: _privateKeyKey, value: decryptedPrivKeyStr);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 4. Encrypt Message
  static Future<String> encryptMessage(String plainText, String receiverPubKeyStr, {String? senderPubKeyStr}) async {
    final receiverPubKey = decodePublicKey(receiverPubKeyStr);
    
    // Generate random AES key and IV
    final aesKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);
    
    // Encrypt text with AES
    final encrypterAES = encrypt.Encrypter(encrypt.AES(aesKey));
    final encryptedText = encrypterAES.encrypt(plainText, iv: iv);
    
    // Encrypt AES key + IV with RSA for receiver
    final rsaEncrypter = encrypt.Encrypter(encrypt.RSA(publicKey: receiverPubKey));
    final payload = '${aesKey.base64}|${iv.base64}';
    final receiverEncryptedPayload = rsaEncrypter.encrypt(payload);
    
    String? senderEncryptedPayloadBase64;
    if (senderPubKeyStr != null) {
      final senderPubKey = decodePublicKey(senderPubKeyStr);
      final senderRsaEncrypter = encrypt.Encrypter(encrypt.RSA(publicKey: senderPubKey));
      senderEncryptedPayloadBase64 = senderRsaEncrypter.encrypt(payload).base64;
    }

    final result = {
      'encryptedText': encryptedText.base64,
      'receiverPayload': receiverEncryptedPayload.base64,
      if (senderEncryptedPayloadBase64 != null) 'senderPayload': senderEncryptedPayloadBase64,
    };
    return jsonEncode(result);
  }

  // 4. Decrypt Message
  static Future<String> decryptMessage(String cipherText) async {
    if (!cipherText.startsWith('{')) {
      if (!cipherText.contains(':')) return cipherText; // Not encrypted or very old format
      // Old string format fallback
      try {
        final parts = cipherText.split(':');
        final encryptedPayloadBase64 = parts[0];
        final encryptedTextBase64 = parts[1];

        String? privKeyStr = await _storage.read(key: _privateKeyKey);
        if (privKeyStr == null) return "Error: Private key missing";
        final myPrivKey = decodePrivateKey(privKeyStr);

        final rsaEncrypter = encrypt.Encrypter(encrypt.RSA(privateKey: myPrivKey));
        final payload = rsaEncrypter.decrypt(encrypt.Encrypted.fromBase64(encryptedPayloadBase64));
        
        final payloadParts = payload.split('|');
        final aesKey = encrypt.Key.fromBase64(payloadParts[0]);
        final iv = encrypt.IV.fromBase64(payloadParts[1]);

        final encrypterAES = encrypt.Encrypter(encrypt.AES(aesKey));
        return encrypterAES.decrypt(encrypt.Encrypted.fromBase64(encryptedTextBase64), iv: iv);
      } catch (e) {
        return "🔒 Encrypted Message (Cannot decrypt)";
      }
    }

    try {
      final map = jsonDecode(cipherText);
      final encryptedTextBase64 = map['encryptedText'];
      final receiverPayloadBase64 = map['receiverPayload'];
      final senderPayloadBase64 = map['senderPayload'];

      // Get my private key
      String? privKeyStr = await _storage.read(key: _privateKeyKey);
      if (privKeyStr == null) return "Error: Private key missing";
      final myPrivKey = decodePrivateKey(privKeyStr);

      // Decrypt AES key + IV with RSA
      final rsaEncrypter = encrypt.Encrypter(encrypt.RSA(privateKey: myPrivKey));
      
      String payload;
      try {
        payload = rsaEncrypter.decrypt(encrypt.Encrypted.fromBase64(receiverPayloadBase64));
      } catch (e) {
        if (senderPayloadBase64 != null) {
          payload = rsaEncrypter.decrypt(encrypt.Encrypted.fromBase64(senderPayloadBase64));
        } else {
          throw Exception("Cannot decrypt payload");
        }
      }
      
      final payloadParts = payload.split('|');
      final aesKey = encrypt.Key.fromBase64(payloadParts[0]);
      final iv = encrypt.IV.fromBase64(payloadParts[1]);

      // Decrypt text with AES
      final encrypterAES = encrypt.Encrypter(encrypt.AES(aesKey));
      final plainText = encrypterAES.decrypt(encrypt.Encrypted.fromBase64(encryptedTextBase64), iv: iv);
      
      return plainText;
    } catch (e) {
      return "🔒 Encrypted Message (Cannot decrypt)";
    }
  }
}

