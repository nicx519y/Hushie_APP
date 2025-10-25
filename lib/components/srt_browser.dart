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
        _scrollWhenReady(idx, const Duration(milliseconds: 300), Curves.easeInOut, 0.0)
            .whenComplete(() => _isAutoScrolling = false);
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
    // 列表数据可能变化，钳制当前 activeIndex 到合法范围
    if (widget.paragraphs.isNotEmpty) {
      final lastIndex = widget.paragraphs.length - 1;
      if (_activeIndex < 0 || _activeIndex > lastIndex) {
         final int clamped = _activeIndex < 0 ? 0 : (_activeIndex > lastIndex ? lastIndex : _activeIndex);
         _activeIndex = clamped;
       }
    } else {
      if (_activeIndex != 0) {
        _activeIndex = 0;
      }
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
      _scrollWhenReady(index, animate ? const Duration(seconds: 1) : Duration.zero, Curves.easeInOut, 0.0)
          .whenComplete(() => _isAutoScrolling = false);
    });
  }

  // 根据进度设置激活索引：progress 为 0.0 ~ 1.0
  void _setActiveByProgress(Duration position, [bool animate = true]) {
    if (widget.paragraphs.isEmpty) return;
    debugPrint('[srt_browser: _setActiveByProgress]  position: $position');

    final int positionSeconds = position.inSeconds;

    // 预先计算所有段落的开始时间（秒）
    final List<int> paragraphTimes = widget.paragraphs
        .map((p) => _parseTimeToSeconds(p.startTime))
        .toList();

    // 边界：若传入时间在最小值之前或最大值之后，直接选择边界并处理相同时间簇
    final int lastIndex = paragraphTimes.length - 1;
    int targetIndex;
    if (positionSeconds <= paragraphTimes.first) {
      // 选择第一个元素的相同时间簇中的最后一个
      int i = 0;
      while (i + 1 <= lastIndex && paragraphTimes[i + 1] == paragraphTimes[i]) {
        i++;
      }
      targetIndex = i;
    } else if (positionSeconds >= paragraphTimes[lastIndex]) {
      // 选择最后一个元素（已自然是相同时间簇的最后）
      targetIndex = lastIndex;
    } else {
      // 以旧的 activeIndex 为起点，根据时间大小决定前向或后向查找
      int currentIndex = _activeIndex;
      if (currentIndex < 0) currentIndex = 0;
      if (currentIndex > lastIndex) currentIndex = lastIndex;

      final int currentActiveTime = paragraphTimes[currentIndex];
      targetIndex = currentIndex;

      if (positionSeconds >= currentActiveTime) {
        // 传入时间大于等于旧 active 的时间：从旧索引向后查找
        // 选择时间 <= 传入时间 的最后一个元素（若相邻时间相同，取最后一个）
        int i = currentIndex;
        while (i + 1 <= lastIndex && paragraphTimes[i + 1] <= positionSeconds) {
          i++;
        }
        targetIndex = i;
      } else {
        // 传入时间小于旧 active 的时间：从旧索引向前查找
        // 先向前移动到第一个 time <= positionSeconds 的位置
        int i = currentIndex;
        while (i > 0 && paragraphTimes[i] > positionSeconds) {
          i--;
        }
        // 若存在多个相邻且时间相同的元素，取最后一个符合条件的元素
        while (
          i + 1 <= lastIndex &&
          paragraphTimes[i + 1] <= positionSeconds &&
          paragraphTimes[i + 1] == paragraphTimes[i]
        ) {
          i++;
        }
        targetIndex = i;
      }
    }

    // 保险：索引钳制
    if (targetIndex < 0) targetIndex = 0;
    if (targetIndex > lastIndex) targetIndex = lastIndex;

    debugPrint('[srt_browser: _setActiveByProgress]  positionSeconds: $positionSeconds; oldIndex: ${_activeIndex}; targetIndex: $targetIndex; len: ${widget.paragraphs.length}');

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
        // 钳制索引到合法范围
        final lastIndex = (widget.paragraphs.isNotEmpty) ? widget.paragraphs.length - 1 : 0;
        int idx = _activeIndex;
        if (idx < 0) idx = 0; else if (idx > lastIndex) idx = lastIndex;
        _scrollWhenReady(idx, const Duration(milliseconds: 500), Curves.easeInOut, 0.0)
            .whenComplete(() => _isAutoScrolling = false);
      });
    }
  }

  Future<void> _scrollWhenReady(int index, Duration duration, Curve curve, double alignment) async {
    if (widget.paragraphs.isEmpty) return;
    final int lastIndex = widget.paragraphs.length - 1;
    final int clamped = index < 0 ? 0 : (index > lastIndex ? lastIndex : index);
    // 等待列表布局完成（ItemPositions 可用）
    while (_itemPositionsListener.itemPositions.value.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 16));
    }
    await _itemScrollController.scrollTo(
      index: clamped,
      duration: duration,
      curve: curve,
      alignment: alignment,
    );
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
                isTitle ? SizedBox(width: 56, child: _TimeChip(label: timeLabel)) : const SizedBox(width: 56),
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
