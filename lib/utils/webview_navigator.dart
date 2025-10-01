import 'package:flutter/material.dart';
import '../components/webview_page.dart';
import '../config/api_config.dart';

/// WebView页面类型枚举
enum WebViewPageType {
  /// 使用条款
  termsOfUse,

  /// 最终用户许可协议
  endUserLicenseAgreement,

  /// 隐私政策
  privacyPolicy,

  /// 自动续费信息
  autoRenewInfo,
}

/// WebView页面导航工具类
class WebViewNavigator {
  /// 根据页面类型获取对应的URL和标题
  static Map<String, String> _getPageInfo(WebViewPageType pageType) {
    switch (pageType) {
      case WebViewPageType.termsOfUse:
        return {
          'url': ApiConfig.TermsOfUseUrl, // 网络URL
          'fallbackUrl': ApiConfig.TermsOfUseFallback, // 本地回退页面
          'title': 'Terms of Use',
        };
      case WebViewPageType.endUserLicenseAgreement:
        return {
          'url': ApiConfig.EndUserLicenseAgreementUrl, // 网络URL
          'fallbackUrl': ApiConfig.EndUserLicenseAgreementFallback, // 本地回退页面
          'title': 'End User License Agreement',
        };
      case WebViewPageType.privacyPolicy:
        return {
          'url': ApiConfig.PrivacyPolicyUrl, // 网络URL
          'fallbackUrl': ApiConfig.PrivacyPolicyFallback, // 本地回退页面
          'title': 'Privacy Policy',
        };
      case WebViewPageType.autoRenewInfo:
        return {
          'url': ApiConfig.AutoRenewInfoUrl, // 网络URL
          'fallbackUrl': ApiConfig.AutoRenewInfoFallback, // 本地回退页面
          'title': 'Auto-renew Information',
        };
    }
  }

  /// 导航到指定的WebView页面
  ///
  /// [context] - 当前的BuildContext
  /// [pageType] - 要打开的页面类型
  /// [clearCache] - 是否清除缓存
  static void navigateToPage(BuildContext context, WebViewPageType pageType, {bool clearCache = false}) {
    final pageInfo = _getPageInfo(pageType);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebViewPage(
          url: pageInfo['url']!,
          title: pageInfo['title']!,
          clearCache: clearCache,
          fallbackAssetUrl: pageInfo['fallbackUrl'], // 传递回退页面URL
        ),
      ),
    );
  }

  /// 显示使用条款页面
  static void showTermsOfUse(BuildContext context, {bool clearCache = false}) {
    navigateToPage(context, WebViewPageType.termsOfUse, clearCache: clearCache);
  }

  /// 显示最终用户许可协议页面
  static void showLicenseAgreement(BuildContext context, {bool clearCache = false}) {
    navigateToPage(context, WebViewPageType.endUserLicenseAgreement, clearCache: clearCache);
  }

  /// 显示隐私政策页面
  static void showPrivacyPolicy(BuildContext context, {bool clearCache = false}) {
    navigateToPage(context, WebViewPageType.privacyPolicy, clearCache: clearCache);
  }

  /// 显示自动续费信息页面
  static void showAutoRenewInfo(BuildContext context, {bool clearCache = false}) {
    navigateToPage(context, WebViewPageType.autoRenewInfo, clearCache: clearCache);
  }

  // 为了保持向后兼容性，提供旧的方法名
  /// 打开使用条款页面
  static void openTermsOfUse(BuildContext context, {bool clearCache = false}) {
    showTermsOfUse(context, clearCache: clearCache);
  }

  /// 打开隐私政策页面
  static void openPrivacyPolicy(BuildContext context, {bool clearCache = false}) {
    showPrivacyPolicy(context, clearCache: clearCache);
  }

  /// 打开自动续费信息页面
  static void openAutoRenewInfo(BuildContext context, {bool clearCache = false}) {
    showAutoRenewInfo(context, clearCache: clearCache);
  }
}
