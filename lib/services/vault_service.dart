import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/vault_item.dart';

class VaultService {
  static final VaultService _instance = VaultService._internal();
  factory VaultService() => _instance;
  VaultService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isInitialized = false;
  bool _hasPasscode = false;
  bool _isBiometricEnabled = false;
  String? _passcodeHash;
  enc.Key? _sessionKey;
  
  late Directory _vaultDir;
  late Directory _tempDir;
  late File _dbFile;
  late File _configFile;
  late File _biometricFile;

  List<VaultItem> _items = [];

  bool get isInitialized => _isInitialized;
  bool get hasPasscode => _hasPasscode;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isUnlocked => _sessionKey != null;
  List<VaultItem> get items => _items;

  Future<void> init() async {
    if (_isInitialized) return;

    final appDocDir = await getApplicationDocumentsDirectory();
    _vaultDir = Directory(p.join(appDocDir.path, 'vault_data'));
    if (!await _vaultDir.exists()) {
      await _vaultDir.create(recursive: true);
    }

    final systemTempDir = await getTemporaryDirectory();
    _tempDir = Directory(p.join(systemTempDir.path, 'vault_temp'));
    if (!await _tempDir.exists()) {
      await _tempDir.create(recursive: true);
    }

    _dbFile = File(p.join(_vaultDir.path, 'vault_db.json'));
    _configFile = File(p.join(_vaultDir.path, 'vault_config.json'));
    _biometricFile = File(p.join(_vaultDir.path, 'vault_bio.json'));

    // Load configuration
    if (await _configFile.exists()) {
      try {
        final configStr = await _configFile.readAsString();
        final config = jsonDecode(configStr) as Map<String, dynamic>;
        _passcodeHash = config['passcodeHash'] as String?;
        _hasPasscode = _passcodeHash != null && _passcodeHash!.isNotEmpty;
        _isBiometricEnabled = config['isBiometricEnabled'] as bool? ?? false;
      } catch (e) {
        _hasPasscode = false;
        _isBiometricEnabled = false;
      }
    } else {
      _hasPasscode = false;
      _isBiometricEnabled = false;
    }

    _isInitialized = true;
  }

  Future<void> setPasscode(String pin) async {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    _passcodeHash = digest.toString();

    final config = {
      'passcodeHash': _passcodeHash,
      'isBiometricEnabled': _isBiometricEnabled,
    };
    await _configFile.writeAsString(jsonEncode(config));
    _hasPasscode = true;

    // Set the session key so it's instantly unlocked
    _sessionKey = enc.Key(Uint8List.fromList(digest.bytes));
    await _loadDatabase();
  }

  bool verifyPasscode(String pin) {
    if (!_hasPasscode || _passcodeHash == null) return false;
    
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    final inputHash = digest.toString();

    if (inputHash == _passcodeHash) {
      _sessionKey = enc.Key(Uint8List.fromList(digest.bytes));
      _loadDatabase();
      return true;
    }
    return false;
  }

  Future<bool> changePasscode(String oldPin, String newPin) async {
    if (!verifyPasscode(oldPin)) return false;

    // Set new passcode
    await setPasscode(newPin);

    // If biometrics was enabled, we need to update the stored PIN in the biometric file
    if (_isBiometricEnabled) {
      await setBiometricEnabled(true, newPin);
    }
    return true;
  }

  Future<bool> canUseBiometrics() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricEnabled) return false;
    if (!await _biometricFile.exists()) return false;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock your secure Document Vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        final bioDataStr = await _biometricFile.readAsString();
        final bioData = jsonDecode(bioDataStr) as Map<String, dynamic>;
        final encryptedPin = bioData['encryptedPin'] as String;

        // Decrypt/de-obfuscate the saved PIN
        final pin = utf8.decode(base64Decode(encryptedPin));
        
        final bytes = utf8.encode(pin);
        final digest = sha256.convert(bytes);
        _sessionKey = enc.Key(Uint8List.fromList(digest.bytes));
        await _loadDatabase();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled, String currentPin) async {
    _isBiometricEnabled = enabled;
    
    final config = {
      'passcodeHash': _passcodeHash,
      'isBiometricEnabled': _isBiometricEnabled,
    };
    await _configFile.writeAsString(jsonEncode(config));

    if (enabled) {
      final obfuscated = base64Encode(utf8.encode(currentPin));
      await _biometricFile.writeAsString(jsonEncode({'encryptedPin': obfuscated}));
    } else {
      if (await _biometricFile.exists()) {
        await _biometricFile.delete();
      }
    }
  }

  void lock() {
    _sessionKey = null;
    _items.clear();
  }

  Future<void> _loadDatabase() async {
    if (!await _dbFile.exists()) {
      _items = [];
      return;
    }

    try {
      final dbStr = await _dbFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(dbStr) as List<dynamic>;
      _items = jsonList
          .map((item) => VaultItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _items = [];
    }
  }

  Future<void> _saveDatabase() async {
    final jsonList = _items.map((item) => item.toJson()).toList();
    await _dbFile.writeAsString(jsonEncode(jsonList));
  }

  Future<VaultItem> encryptAndAddFile(File sourceFile) async {
    if (_sessionKey == null) throw Exception('Vault is locked');

    final originalName = p.basename(sourceFile.path);
    final ext = p.extension(sourceFile.path).toLowerCase();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final encryptedFileName = '$id.enc';
    final encryptedFilePath = p.join(_vaultDir.path, encryptedFileName);

    // Read bytes
    final fileBytes = await sourceFile.readAsBytes();

    // Generate random IV
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_sessionKey!, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);

    // We store the 16 bytes of IV followed by the encrypted payload
    final File encryptedFile = File(encryptedFilePath);
    final combinedBytes = Uint8List(iv.bytes.length + encrypted.bytes.length);
    combinedBytes.setRange(0, iv.bytes.length, iv.bytes);
    combinedBytes.setRange(iv.bytes.length, combinedBytes.length, encrypted.bytes);

    await encryptedFile.writeAsBytes(combinedBytes);

    final category = getCategoryForExtension(ext);
    final item = VaultItem(
      id: id,
      originalName: originalName,
      fileExtension: ext,
      sizeBytes: fileBytes.length,
      addedDate: DateTime.now(),
      category: category,
      encryptedFileName: encryptedFileName,
    );

    _items.add(item);
    await _saveDatabase();

    return item;
  }

  Future<File> decryptFile(VaultItem item, String targetPath) async {
    if (_sessionKey == null) throw Exception('Vault is locked');

    final encryptedFilePath = p.join(_vaultDir.path, item.encryptedFileName);
    final encryptedFile = File(encryptedFilePath);
    if (!await encryptedFile.exists()) {
      throw Exception('Encrypted file not found on disk');
    }

    final combinedBytes = await encryptedFile.readAsBytes();
    if (combinedBytes.length < 16) {
      throw Exception('Encrypted file is corrupted');
    }

    // Extract IV (first 16 bytes) and payload (rest)
    final ivBytes = combinedBytes.sublist(0, 16);
    final payloadBytes = combinedBytes.sublist(16);

    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(_sessionKey!, mode: enc.AESMode.cbc));

    final decryptedBytes = encrypter.decryptBytes(enc.Encrypted(payloadBytes), iv: iv);

    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(decryptedBytes);
    return targetFile;
  }

  Future<String> decryptToTemp(VaultItem item) async {
    // Decrypt to temp folder with its original name
    final tempFilePath = p.join(_tempDir.path, '${item.id}_${item.originalName}');
    await decryptFile(item, tempFilePath);
    return tempFilePath;
  }

  Future<void> cleanTempFolder() async {
    if (await _tempDir.exists()) {
      await _tempDir.delete(recursive: true);
      await _tempDir.create(recursive: true);
    }
  }

  Future<void> deleteFile(VaultItem item) async {
    final encryptedFilePath = p.join(_vaultDir.path, item.encryptedFileName);
    final encryptedFile = File(encryptedFilePath);
    if (await encryptedFile.exists()) {
      await encryptedFile.delete();
    }

    _items.removeWhere((i) => i.id == item.id);
    await _saveDatabase();
  }

  String getCategoryForExtension(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
      case '.bmp':
        return 'Images';
      case '.pdf':
        return 'PDFs';
      case '.doc':
      case '.docx':
      case '.txt':
      case '.rtf':
      case '.xls':
      case '.xlsx':
      case '.ppt':
      case '.pptx':
      case '.csv':
        return 'Documents';
      case '.mp3':
      case '.wav':
      case '.m4a':
      case '.mp4':
      case '.mkv':
      case '.avi':
      case '.mov':
        return 'Audio/Video';
      default:
        return 'Others';
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
