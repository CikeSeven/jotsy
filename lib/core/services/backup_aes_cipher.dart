import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 复用 archive 的 WinZip AES 密码派生和计数器，累计整条目的认证码。
/// 每块除最后一块外需按 16 字节对齐；处理会原地修改传入字节，不保留正文。
class BackupAesCipher {
  BackupAesCipher(
    String password,
    Uint8List salt,
    this.keySize, {
    this.encrypt = false,
  }) : _derived = ZipFile.deriveKey(password, salt, derivedKeyLength: keySize);

  final int keySize;
  final bool encrypt;
  final Uint8List _derived;
  Uint8List get _macKey =>
      Uint8List.sublistView(_derived, keySize, keySize * 2);
  late final _authenticator = AesCipherUtil.getMacBasedPRF(_macKey);
  late final _cipher = Aes(
    Uint8List.sublistView(_derived, 0, keySize),
    _macKey,
    keySize,
    encrypt: encrypt,
  );

  Uint8List get passwordVerifier =>
      Uint8List.sublistView(_derived, keySize * 2);

  void processChunk(Uint8List bytes) {
    // Aes.processData 每次重置自己的 MAC；独立累计密文，不能仅校验最后一块。
    if (encrypt) {
      _cipher.processData(bytes, 0, bytes.length);
      _authenticator.update(bytes, 0, bytes.length);
    } else {
      _authenticator.update(bytes, 0, bytes.length);
      _cipher.processData(bytes, 0, bytes.length);
    }
  }

  Uint8List finishAuthentication() {
    final result = Uint8List(_authenticator.macSize);
    _authenticator.doFinal(result, 0);
    return Uint8List.sublistView(result, 0, 10);
  }
}
