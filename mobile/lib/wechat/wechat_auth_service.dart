import 'dart:async';

import 'package:family_mobile/wechat/wechat_config.dart';
import 'package:fluwx/fluwx.dart';
import 'package:flutter/foundation.dart';

/// Native WeChat OAuth (authorization code) via fluwx; code is exchanged by [AppState] + Flask.
class WechatAuthService {
  WechatAuthService._();
  static final WechatAuthService instance = WechatAuthService._();

  final Fluwx _fluwx = Fluwx();
  bool _registered = false;

  Future<void> prepare() async {
    if (kIsWeb) return;
    if (!WechatConfig.isConfigured) return;
    if (_registered) return;
    final ok = await _fluwx.registerApi(
      appId: WechatConfig.appId,
      doOnAndroid: defaultTargetPlatform == TargetPlatform.android,
      doOnIOS: defaultTargetPlatform == TargetPlatform.iOS && WechatConfig.universalLink.isNotEmpty,
      universalLink: WechatConfig.universalLink.isEmpty ? null : WechatConfig.universalLink,
    );
    _registered = ok;
  }

  /// Non-null code on success; null if user cancelled. Throws [StateError] for misconfiguration / missing WeChat.
  Future<String?> requestAuthCode() async {
    if (kIsWeb) {
      throw StateError('wechat_not_supported_on_web');
    }
    if (!WechatConfig.isConfigured) {
      throw StateError('wechat_not_configured');
    }
    await prepare();
    if (!await _fluwx.isWeChatInstalled) {
      throw StateError('wechat_not_installed');
    }

    final completer = Completer<String?>();
    late void Function(WeChatResponse) listener;
    listener = (WeChatResponse r) {
      if (r is! WeChatAuthResponse) return;
      _fluwx.removeSubscriber(listener);
      if (completer.isCompleted) return;
      if (r.isSuccessful && r.code != null && r.code!.isNotEmpty) {
        completer.complete(r.code);
      } else {
        completer.complete(null);
      }
    };

    _fluwx.addSubscriber(listener);
    final launched = await _fluwx.authBy(which: NormalAuth(scope: 'snsapi_userinfo'));
    if (!launched) {
      _fluwx.removeSubscriber(listener);
      if (!completer.isCompleted) {
        completer.completeError(StateError('wechat_auth_launch_failed'));
      }
    }

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _fluwx.removeSubscriber(listener);
        throw TimeoutException('wechat_auth_timeout');
      },
    );
  }
}
