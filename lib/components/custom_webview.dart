import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CustomWebView extends StatefulWidget {
  final String url;
  final Color? backgroundColor;
  final Color? loadingBackgroundColor;
  final Color? loadingIndicatorColor;
  final bool clearCache;
  final String? fallbackAssetUrl; // 网络加载失败时的回退本地页面

  const CustomWebView({
    super.key,
    required this.url,
    this.backgroundColor = const Color(0xFF000000),
    this.loadingBackgroundColor = const Color(0xFFF5F5F5),
    this.loadingIndicatorColor = const Color(0xFFF359AA),
    this.clearCache = false,
    this.fallbackAssetUrl,
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
      
      // 如果需要清除缓存，则在加载新URL前清除缓存
      if (widget.clearCache) {
        _controller.clearCache();
        _controller.clearLocalStorage();
      }
      
      _loadUrl(widget.url);
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
          onWebResourceError: (WebResourceError error) {
            // 处理网络加载错误
            
            if (mounted && !_currentUrl!.startsWith('assets/')) {
              // 检查是否是主页面加载错误（不是子资源错误）
              bool isMainPageError = error.isForMainFrame ?? true;
              
              // 如果是主页面错误且有回退的本地页面，则加载本地页面
              if (isMainPageError && widget.fallbackAssetUrl != null) {
                _loadFallbackAsset();
              }
            }
          },
        ),
      );
    
    // 如果需要清除缓存，则清除所有缓存数据
    if (widget.clearCache) {
      _controller.clearCache();
      _controller.clearLocalStorage();
    }
    
    _loadUrl(_currentUrl!);
  }

  /// 加载URL的统一方法
  void _loadUrl(String url) {
    if (url.startsWith('assets/')) {
      _controller.loadFlutterAsset(url);
    } else {
      _controller.loadRequest(Uri.parse(url));
    }
  }

  /// 加载回退的本地assets页面
  void _loadFallbackAsset() {
    if (widget.fallbackAssetUrl != null) {
      _currentUrl = widget.fallbackAssetUrl!;
      _controller.loadFlutterAsset(widget.fallbackAssetUrl!);
      
      if (mounted) {
        setState(() {
          _webviewIsLoading = true;
        });
      }
    }
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
