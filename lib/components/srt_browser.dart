import 'package:flutter/material.dart';
import '../models/srt_model.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

// 控制器：用于外部设置 activeIndex 并触发滚动
class SrtBrowserController {
  _SrtBrowserState? _state;
  void _attach(_SrtBrowserState state) => _state = state;
  void _detach(_SrtBrowserState state) {
    if (_state == state) _state = null;
  }
  void setActiveIndex(int index, [bool animate = true]) {
    _state?._setActiveIndex(index, animate);
  }
  // 修改：按具体时间定位字幕，而不是进度比例
  void setActiveByProgress(Duration position, [bool animate = true]) {
    _state?._setActiveByProgress(position, animate);
  }
  // 新增：重置到自动滚动状态
  void resetToAutoScroll() {
    _state?._resetToAutoScroll();
  }
  int? get activeIndex => _state?._activeIndex;
}

/// 字幕浏览组件：根据 SrtParagraphModel 渲染标题与正文段落
class SrtBrowser extends StatefulWidget {
  const SrtBrowser({
    super.key, 
    required this.paragraphs, 
    this.controller, 
    this.initPorgress,
    this.onScrollStateChanged,
  });

  final List<SrtParagraphModel> paragraphs;
  final SrtBrowserController? controller;
  final double? initPorgress; // 0.0 ~ 1.0 的初始进度
  final Function(bool isUserScrolling)? onScrollStateChanged; // 滚动状态变化回调

  @override
  State<SrtBrowser> createState() => _SrtBrowserState();
}

class _SrtBrowserState extends State<SrtBrowser> {
  // 替换为按索引滚动的控制器
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  // 移除 GlobalKey 列表与传统 ScrollController
  int _activeIndex = 0; // 当前激活的段落索引
  bool _isUserScrolling = false; // 用户是否在手动滚动
  bool _isAutoScrolling = false; // 是否正在自动滚动

  @override
  void initState() {
    super.initState();
    // 移除 _itemKeys 与 _scrollController 监听
    widget.controller?._attach(this);
    // 根据入参 initPorgress 设置初始 activeIndex
    if (widget.initPorgress != null && widget.paragraphs.isNotEmpty) {
      final p = widget.initPorgress!.clamp(0.0, 1.0);
      final idx = (p * (widget.paragraphs.length - 1)).round();
      _activeIndex = idx;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isAutoScrolling = true;
        _itemScrollController.scrollTo(
          index: idx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.0,
        ).then((_) => _isAutoScrolling = false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant SrtBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 移除 itemKeys 同步逻辑，仅保留控制器绑定处理
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  // 外部调用的设置激活索引方法：设置后可选择是否滚动动画（true=1s，false=无动画）
  void _setActiveIndex(int index, [bool animate = true]) {
    if (index < 0 || index >= widget.paragraphs.length) return;
    if (index == _activeIndex) return;
    setState(() => _activeIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isAutoScrolling = true;
      _itemScrollController.scrollTo(
        index: index,
        duration: animate ? const Duration(seconds: 1) : Duration.zero,
        curve: Curves.easeInOut,
        alignment: 0.0,
      ).then((_) => _isAutoScrolling = false);
    });
  }

  // 根据进度设置激活索引：progress 为 0.0 ~ 1.0
  void _setActiveByProgress(Duration position, [bool animate = true]) {
    if (widget.paragraphs.isEmpty) return;
    debugPrint('[srt_browser: _setActiveByProgress]  position: $position');
    final int positionSeconds = position.inSeconds;
    int targetIndex = 0;

    // 获取所有字幕段落的开始时间（秒）
    final List<int> paragraphTimes = widget.paragraphs
        .map((p) => _parseTimeToSeconds(p.startTime))
        .toList();

    // 遍历时间边界，定位当前时间所在的段落
    for (int i = 0; i < paragraphTimes.length; i++) {
      final int currentParagraphTime = paragraphTimes[i];
      final int nextParagraphTime = i < paragraphTimes.length - 1
          ? paragraphTimes[i + 1]
          : currentParagraphTime + 5; // 最后段落追加少量缓冲

      if (positionSeconds >= currentParagraphTime && positionSeconds < nextParagraphTime) {
        debugPrint('[srt_browser: _setActiveByProgress]  positionSeconds: $positionSeconds; currentParagraphTime: $currentParagraphTime; nextParagraphTime: $nextParagraphTime');
        targetIndex = i;
        break;
      }

      // 如果时间超过最后一个段落的开始时间，选中最后一个段落
      if (i == paragraphTimes.length - 1 && positionSeconds >= currentParagraphTime) {
        targetIndex = i;
      }
    }

    debugPrint('[srt_browser: _setActiveByProgress]  targetIndex: $targetIndex; len: ${widget.paragraphs.length}');

    // 用户正在手动滚动：仅更新高亮，不滚动
    if (_isUserScrolling) {
      if (targetIndex != _activeIndex) {
        setState(() {
          _activeIndex = targetIndex;
        });
      }
    } else {
      // 自动模式：更新高亮并按需滚动
      _setActiveIndex(targetIndex, animate);
    }
  }

  // 解析时间字符串为秒数
  int _parseTimeToSeconds(String timeStr) {
    try {
      final parts = timeStr.split(':');
      int h = 0, m = 0, s = 0;
      if (parts.length == 3) {
        h = int.tryParse(parts[0]) ?? 0;
        m = int.tryParse(parts[1]) ?? 0;
        s = int.tryParse(parts[2]) ?? 0;
      } else if (parts.length == 2) {
        m = int.tryParse(parts[0]) ?? 0;
        s = int.tryParse(parts[1]) ?? 0;
      } else if (parts.length == 1) {
        s = int.tryParse(parts[0]) ?? 0;
      }
      return h * 3600 + m * 60 + s;
    } catch (_) {
      return 0;
    }
  }

  // 重置到自动滚动状态
  void _resetToAutoScroll() {
    if (_isUserScrolling) {
      _isUserScrolling = false;
      widget.onScrollStateChanged?.call(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isAutoScrolling = true;
        _itemScrollController.scrollTo(
          index: _activeIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.0,
        ).then((_) => _isAutoScrolling = false);
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    // 用滚动通知检测用户手动滚动
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_isAutoScrolling) return false;
        if (notification is ScrollUpdateNotification && notification.dragDetails != null) {
          if (!_isUserScrolling) {
            _isUserScrolling = true;
            widget.onScrollStateChanged?.call(true);
          }
        }
        return false;
      },
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        itemCount: widget.paragraphs.length,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
        itemBuilder: (context, index) {
          final p = widget.paragraphs[index];
          final timeLabel = _formatMmSs(p.startTime);
          final isTitle = p.type == SrtParagraphType.title;
          return Container(
            // 移除基于 GlobalKey 的 key
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: _activeIndex != index ? Colors.transparent : const Color(0xFFF9F9F9).withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 56, child: _TimeChip(label: timeLabel)),
                const SizedBox(width: 7),
                Expanded(child: isTitle ? _TitleText(text: p.text) : _BodyText(text: p.text)),
                const SizedBox(width: 63),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatMmSs(String hhmmss) {
    // 期望传入格式类似 "HH:MM:SS"，容错处理
    try {
      final parts = hhmmss.split(':');
      int h = 0, m = 0, s = 0;
      if (parts.length == 3) {
        h = int.tryParse(parts[0]) ?? 0;
        m = int.tryParse(parts[1]) ?? 0;
        s = int.tryParse(parts[2]) ?? 0;
      } else if (parts.length == 2) {
        m = int.tryParse(parts[0]) ?? 0;
        s = int.tryParse(parts[1]) ?? 0;
      } else if (parts.length == 1) {
        s = int.tryParse(parts[0]) ?? 0;
      }
      final total = Duration(hours: h, minutes: m, seconds: s);
      final hh = total.inHours;
      final mm = total.inMinutes % 60;
      final ss = total.inSeconds % 60;
      if (hh > 0) {
        // 小时不补零，分秒补两位
        return '$hh:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
      } else {
        // 仅显示分秒，均补两位
        return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return hhmmss; // 兜底直接返回原字符串
    }
  }
}

// 时间标签芯片
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        // margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    // 将中括号内的内容绘制为带下划线，增加层次感
    final spans = _buildUnderlinedBracketSpans(text);

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.left,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  List<InlineSpan> _buildUnderlinedBracketSpans(String input) {
    final List<InlineSpan> spans = [];
    final reg = RegExp(r"(\[[^\]]*\])");
    int start = 0;
    for (final match in reg.allMatches(input)) {
      if (match.start > start) {
        spans.add(TextSpan(text: input.substring(start, match.start)));
      }
      final bracketText = match.group(0) ?? '';
      spans.add(
        TextSpan(
          text: bracketText,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            decorationColor: Colors.white70,
            decorationThickness: 1.5,
          ),
        ),
      );
      start = match.end;
    }
    if (start < input.length) {
      spans.add(TextSpan(text: input.substring(start)));
    }
    return spans;
  }
}
