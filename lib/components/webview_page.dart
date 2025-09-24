import 'package:flutter/material.dart';
import 'custom_webview.dart';

class WebViewPage extends StatelessWidget {
  final String url;
  final String title;

  const WebViewPage({
    Key? key,
    required this.url,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            decoration: TextDecoration.none,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: CustomWebView(
        url: url,
        backgroundColor: const Color(0xFFF8F8F8),
      ),
    );
  }
}