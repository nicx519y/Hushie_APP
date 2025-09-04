import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CustomWebView extends StatefulWidget {
  final String url;
  final Color? backgroundColor;
  final Color? loadingBackgroundColor;
  final Color? loadingIndicatorColor;

  const CustomWebView({
    super.key,
    required this.url,
    this.backgroundColor = const Color(0xFF000000),
    this.loadingBackgroundColor = const Color(0xFFF5F5F5),
    this.loadingIndicatorColor = const Color(0xFFF359AA),
  });

  @override
  State<CustomWebView> createState() => _CustomWebViewState();
}

class _CustomWebViewState extends State<CustomWebView> {
  late final WebViewController _controller;
  bool _webviewIsLoading = true;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _initializeController();
  }

  @override
  void didUpdateWidget(CustomWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 只有当URL发生变化时才重新加载
    if (oldWidget.url != widget.url) {
      _currentUrl = widget.url;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    
    // 更新背景色（如果发生变化）
    if (oldWidget.backgroundColor != widget.backgroundColor) {
      _controller.setBackgroundColor(widget.backgroundColor!);
    }
  }

  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor!)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // 可以在这里显示加载进度
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _webviewIsLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _webviewIsLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl!));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          // WebView
          Container(
            color: widget.backgroundColor,
            child: WebViewWidget(controller: _controller),
          ),

          // 加载指示器
          if (_webviewIsLoading)
            Container(
              color: widget.loadingBackgroundColor,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.loadingIndicatorColor!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
