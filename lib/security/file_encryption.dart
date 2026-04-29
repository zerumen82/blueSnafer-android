import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

/// Sistema de cifrado de archivos para proteger datos exfiltrados
/// Implementación real con AES-256-CBC + HMAC-SHA256
class FileEncryption {
  static const int _keySize = 32; // 256 bits
  static const int _ivSize = 16; // 128 bits for CBC
  static const int _macSize = 32; // SHA-256 HMAC

  final String _masterKeyBase64;

  /// Crea una instancia con una clave maestra
  /// Si no se proporciona, genera una clave aleatoria
  FileEncryption({String? masterKeyBase64})
      : _masterKeyBase64 = masterKeyBase64 ?? _generateRandomKey();

  /// Genera una clave aleatoria segura de 256 bits
  static String _generateRandomKey() {
    final random = Random.secure();
    final keyBytes = List<int>.generate(_keySize, (_) => random.nextInt(256));
    return base64.encode(keyBytes);
  }

  /// Deriva una clave a partir de una contraseña usando PBKDF2
  static String deriveKeyFromPassword(String password, String salt) {
    final saltBytes = utf8.encode(salt);
    final key = pbkdf2(
      utf8.encode(password),
      saltBytes,
      100000,
      _keySize,
    );
    return base64.encode(key);
  }

  /// Función PBKDF2 para derivación de claves
  static List<int> pbkdf2(List<int> password, List<int> salt, int iterations, int keyLen) {
    var hmac = Hmac(sha256, password);
    var derivedKey = <int>[];

    for (var block = 1; derivedKey.length < keyLen; block++) {
      var blockSalt = List<int>.from(salt)..addAll(_encodeInt(block));
      var u = hmac.convert(blockSalt).bytes;
      var result = List<int>.from(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < u.length; j++) {
          result[j] ^= u[j];
        }
      }
      derivedKey.addAll(result);
    }

    return derivedKey.sublist(0, keyLen);
  }

  /// Codifica un entero en 4 bytes big-endian
  static List<int> _encodeInt(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Genera un IV aleatorio
  Uint8List _generateIV() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(_ivSize, (_) => random.nextInt(256)));
  }

  /// Cifrar un archivo usando AES-256-CBC con HMAC-SHA256
  Future<File> encryptFile(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('Archivo no encontrado', file.path);
    }

    final key = Key.fromBase64(_masterKeyBase64);
    final ivBytes = _generateIV();
    final iv = IV(ivBytes);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    final bytes = await file.readAsBytes();
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    // Calcular HMAC
    final hmac = Hmac(sha256, key.bytes);
    final authData = Uint8List.fromList([...ivBytes, ...encrypted.bytes]);
    final mac = hmac.convert(authData).bytes;

    final encryptedFile = File('${file.path}.enc');
    final outputBytes = Uint8List.fromList([...ivBytes, ...encrypted.bytes, ...mac]);
    await encryptedFile.writeAsBytes(outputBytes);
    return encryptedFile;
  }

  /// Descifrar un archivo usando AES-256-CBC con verificación HMAC
  Future<File> decryptFile(File encryptedFile) async {
    if (!await encryptedFile.exists()) {
      throw FileSystemException('Archivo cifrado no encontrado', encryptedFile.path);
    }

    final key = Key.fromBase64(_masterKeyBase64);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    final bytes = await encryptedFile.readAsBytes();

    if (bytes.length < _ivSize + _macSize) {
      throw StateError('Archivo cifrado corrupto: tamaño inválido');
    }

    final ivBytes = bytes.sublist(0, _ivSize);
    final iv = IV(Uint8List.fromList(ivBytes));
    final macBytes = bytes.sublist(bytes.length - _macSize);
    final cipherBytes = bytes.sublist(_ivSize, bytes.length - _macSize);

    // Verificar HMAC
    final hmac = Hmac(sha256, key.bytes);
    final authData = Uint8List.fromList([...ivBytes, ...cipherBytes]);
    final expectedMac = hmac.convert(authData).bytes;

    if (!_constantTimeCompare(Uint8List.fromList(macBytes), Uint8List.fromList(expectedMac))) {
      throw StateError('Autenticación fallida: el archivo puede haber sido modificado');
    }

    final decryptedBytes = encrypter.decryptBytes(Encrypted(Uint8List.fromList(cipherBytes)), iv: iv);

    final originalPath = encryptedFile.path.replaceAll('.enc', '');
    final decryptedFile = File(originalPath);
    await decryptedFile.writeAsBytes(decryptedBytes);

    return decryptedFile;
  }

  /// Comparación en tiempo constante
  bool _constantTimeCompare(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Cifrar bytes directamente
  List<int> encryptBytes(List<int> bytes) {
    final key = Key.fromBase64(_masterKeyBase64);
    final ivBytes = _generateIV();
    final iv = IV(ivBytes);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    final hmac = Hmac(sha256, key.bytes);
    final authData = Uint8List.fromList([...ivBytes, ...encrypted.bytes]);
    final mac = hmac.convert(authData).bytes;

    return [...ivBytes, ...encrypted.bytes, ...mac];
  }

  /// Descifrar bytes directamente
  List<int> decryptBytes(List<int> encryptedData) {
    if (encryptedData.length < _ivSize + _macSize) {
      throw StateError('Datos cifrados corruptos: tamaño inválido');
    }

    final key = Key.fromBase64(_masterKeyBase64);
    final ivBytes = encryptedData.sublist(0, _ivSize);
    final iv = IV(Uint8List.fromList(ivBytes));
    final macBytes = encryptedData.sublist(encryptedData.length - _macSize);
    final cipherBytes = encryptedData.sublist(_ivSize, encryptedData.length - _macSize);

    final hmac = Hmac(sha256, key.bytes);
    final authData = Uint8List.fromList([...ivBytes, ...cipherBytes]);
    final expectedMac = hmac.convert(authData).bytes;

    if (!_constantTimeCompare(Uint8List.fromList(macBytes), Uint8List.fromList(expectedMac))) {
      throw StateError('Autenticación fallida');
    }

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decryptBytes(Encrypted(Uint8List.fromList(cipherBytes)), iv: iv);
  }

  /// Obtener hash SHA-256 de un archivo
  Future<String> getFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Generar una contraseña segura aleatoria
  static String generateSecurePassword({int length = 32}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()_+-=[]{}|;:,.<>?';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

