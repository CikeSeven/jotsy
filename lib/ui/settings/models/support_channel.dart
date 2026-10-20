/// 打赏（支持开发者）的收款渠道：收款码图片、相册文件名与付款跳转的唯一登记处。
///
/// - 收款码只取 `assets/img/support/`，与 README 共用同一份裁切图（只含码本身、
///   四周留白色静区，圆角只落在留白里）；
/// - 支付宝收款码里的链接只在 [alipayPaymentCodeUrl] 登记，经 [alipayLaunchUri]
///   交给支付宝按“扫到这个码”处理，直接进入付款页；
/// - 微信赞赏码是小程序码，第三方应用无法直接拉起付款，只能保存到相册后在微信
///   「扫一扫」里从相册选图；[weChatLaunchUri] 只负责打开微信。
enum SupportChannel {
  wechat(
    assetPath: 'assets/img/support/wechat.png',
    galleryName: 'jotsy_support_wechat',
  ),
  alipay(
    assetPath: 'assets/img/support/alipay.png',
    galleryName: 'jotsy_support_alipay',
  );

  const SupportChannel({required this.assetPath, required this.galleryName});

  /// 收款码图片资源。
  final String assetPath;

  /// 保存到相册时的文件名（不含扩展名，gal 按内容补上 `.png`）。
  final String galleryName;
}

/// 支付宝收款码的内容（由收款码图片解码得到，改收款码时同步更新）。
const String alipayPaymentCodeUrl =
    'https://qr.alipay.com/fkx112949yjleherrvp3m48';

/// 让支付宝把 [alipayPaymentCodeUrl] 当作扫码结果打开（`saId=10000007` 为支付宝
/// 的扫码入口），直接进入付款页。收款码链接作为查询参数整体编码。
final Uri alipayLaunchUri = Uri(
  scheme: 'alipays',
  host: 'platformapi',
  path: '/startapp',
  queryParameters: <String, String>{
    'saId': '10000007',
    'qrcode': alipayPaymentCodeUrl,
  },
);

/// 打开微信首页（微信不接受第三方应用直接拉起扫一扫或付款）。
final Uri weChatLaunchUri = Uri.parse('weixin://');
