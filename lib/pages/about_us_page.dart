import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../components/custom_webview.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

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
          child: CustomWebView(
            url: ApiConfig.WebviewAboutUsUrl,
            backgroundColor: const Color(0xFFF8F8F8),
            loadingBackgroundColor: const Color(0xFFF8F8F8),
            loadingIndicatorColor: const Color(0xFFF359AA),
          ),
        ),
      ),
    );
  }
}
