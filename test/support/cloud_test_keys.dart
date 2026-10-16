import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 测试用 RSA 密钥对（1024 位、固定种子）：替换厂商公钥，测试用私钥解开
/// 请求信封里的会话密钥，以模拟加密的服务端。
final AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> cloudTestKeys = () {
  final generator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 12),
        FortunaRandom()..seed(KeyParameter(Uint8List(32))),
      ),
    );
  return generator.generateKeyPair();
}();

Uint8List unwrapCloudTestKey(List<int> wrapped) =>
    (PKCS1Encoding(RSAEngine())..init(
          false,
          PrivateKeyParameter<RSAPrivateKey>(cloudTestKeys.privateKey),
        ))
        .process(Uint8List.fromList(wrapped));
