import 'dart:typed_data';

import 'package:archive/archive.dart';

/// WinZip AES-CTR 与 HMAC-SHA1。密钥按 archive 3.x 的口令字节派生，
/// 已导出的加密备份才能继续解开。
///
/// archive 4.x 的 `ZipFile.deriveKey` 改成 UTF-8，非 ASCII 口令会和旧备份
/// 对不上，所以这里仍取 UTF-16 码元的低 8 位，再用公开的 [pbkdf2HmacSha1]。
/// 旧的 Aes 辅助类不再导出；[AesCtr] 从 1 起按小端计数，和 WinZip 以及
/// 4.x 解码器同一条密钥流。计数器跨块连续，不必再把块长对齐到 16。
/// 处理会原地修改传入字节，不保留正文。
class BackupAesCipher {
  BackupAesCipher(
    String password,
    Uint8List salt,
    this.keySize, {
    this.encrypt = false,
  }) : _derived = _deriveKey(password, salt, keySize);

  final int keySize;
  final bool encrypt;
  final Uint8List _derived;
  Uint8List get _macKey =>
      Uint8List.sublistView(_derived, keySize, keySize * 2);
  late final _authenticator = HmacSha1(_macKey);
  late final _cipher = AesCtr(
    Uint8List.sublistView(_derived, 0, keySize),
    Uint8List(16)..[0] = 1,
    littleEndianCounter: true,
  );

  Uint8List get passwordVerifier =>
      Uint8List.sublistView(_derived, keySize * 2);

  void processChunk(Uint8List bytes) {
    // 认证码覆盖整段密文。加密先变成密文再累计，解密先累计再还原。
    if (encrypt) {
      _cipher.process(bytes);
      _authenticator.update(bytes, 0, bytes.length);
    } else {
      _authenticator.update(bytes, 0, bytes.length);
      _cipher.process(bytes);
    }
  }

  Uint8List finishAuthentication() {
    final result = Uint8List(HmacSha1.macSize);
    _authenticator.finish(result, 0);
    return Uint8List.sublistView(result, 0, 10);
  }
}

/// PBKDF2-HMAC-SHA1，长度是加密密钥、认证密钥和 2 字节口令校验。
/// 空口令沿用 archive 3.x：直接给出空密钥，不跑派生。
Uint8List _deriveKey(String password, Uint8List salt, int keySize) {
  if (password.isEmpty) return Uint8List(0);
  final passwordBytes = Uint8List(password.length);
  for (var i = 0; i < password.length; i++) {
    passwordBytes[i] = password.codeUnitAt(i) & 0xff;
  }
  return pbkdf2HmacSha1(passwordBytes, salt, 1000, keySize * 2 + 2);
}
