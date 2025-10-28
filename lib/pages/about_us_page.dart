import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../components/custom_webview.dart';
import '../utils/webview_navigator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});
  static const Color linkColor = Color(0xFF2A4EFF);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Container(
          color: const Color(0xFFF8F8F8),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Transform.translate(
                offset: const Offset(10, 2),
                child: SvgPicture.asset(
                  'assets/icons/logo.svg',
                  width: 150,
                  // height: 25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'V${ApiConfig.getAppVersion()}',
                style: TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Expanded(
                child: CustomWebView(
                  url: ApiConfig.WebviewAboutUsUrl,
                  // url: 'assets/html/about_with_out_version.html',
                  backgroundColor: const Color(0xFFF8F8F8),
                  loadingBackgroundColor: const Color(0xFFF8F8F8),
                  loadingIndicatorColor: const Color(0xFFF359AA),
                  fallbackAssetUrl: ApiConfig.WebviewAboutUsFallback, // 添加回退页面
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 38,
                ),
                child: RichText(
                  textAlign: TextAlign.center,

                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 10,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(color: linkColor),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => WebViewNavigator.showPrivacyPolicy(
                            context,
                            clearCache: true,
                          ),
                      ),
                      const TextSpan(text: ', '),
                      TextSpan(
                        text: 'Terms of Use',
                        style: TextStyle(color: linkColor),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => WebViewNavigator.showTermsOfUse(
                            context,
                            clearCache: true,
                          ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'End User License Agreement',
                        style: TextStyle(color: linkColor),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => WebViewNavigator.showLicenseAgreement(
                            context,
                            clearCache: true,
                          ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
