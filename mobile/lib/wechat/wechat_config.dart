/// WeChat Open Platform mobile app (for [fluwx]).
///
/// Build with:
/// `flutter run --dart-define=WECHAT_APP_ID=wx...`
///
/// iOS also needs a valid Universal Link (HTTPS) registered in the WeChat console:
/// `flutter run --dart-define=WECHAT_APP_ID=wx... --dart-define=WECHAT_UNIVERSAL_LINK=https://your.domain/wechat/`
class WechatConfig {
  static const String appId = String.fromEnvironment('WECHAT_APP_ID', defaultValue: '');

  /// Required for WeChat SDK registration on iOS when [appId] is set.
  static const String universalLink = String.fromEnvironment('WECHAT_UNIVERSAL_LINK', defaultValue: '');

  static bool get isConfigured => appId.isNotEmpty;
}
