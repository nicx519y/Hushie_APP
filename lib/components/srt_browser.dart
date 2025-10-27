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
    this.initProgress,
    this.onScrollStateChanged,
    this.onParagraphTap,
    this.canViewAllText = false,
  });

  final List<SrtParagraphModel> paragraphs;
  final SrtBrowserController? controller;
  final Duration? initProgress; // 初始播放进度
  final Function(bool isUserScrolling)? onScrollStateChanged; // 滚动状态变化回调
  final Function(SrtParagraphModel paragraph)? onParagraphTap; // 段落点击回调
  final bool canViewAllText; // 是否可查看完整文本

  @override
  State<SrtBrowser> createState() => _SrtBrowserState();
}

class _SrtBrowserState extends State<SrtBrowser> with AutomaticKeepAliveClientMixin {
  // 替换为按索引滚动的控制器
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  // 移除 GlobalKey 列表与传统 ScrollController
  int _activeIndex = 0; // 当前激活的段落索引（基于可见列表）
  bool _isUserScrolling = false; // 用户是否在手动滚动
  bool _isAutoScrolling = false; // 是否正在自动滚动

  // 预先过滤后的可见段落列表
  List<SrtParagraphModel> _visibleParagraphs = [];

  @override
  void initState() {
    super.initState();
    debugPrint('[SrtBrowser] initState called - 组件初始化');
    widget.controller?._attach(this);
    _rebuildVisibleParagraphs();
    
    // 根据入参 initProgress 设置初始 activeIndex（基于可见列表）
    if (widget.initProgress != null && _visibleParagraphs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setActiveByProgress(widget.initProgress!, false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant SrtBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    // debugPrint('[SrtBrowser] didUpdateWidget called - 检查是否需要重建');
    
    // 只有在控制器真正改变时才重新绑定
    if (oldWidget.controller != widget.controller) {
      debugPrint('[SrtBrowser] Controller changed - 重新绑定控制器');
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }

    // 只有在段落数据真正改变时才重新计算
    if (oldWidget.paragraphs != widget.paragraphs || 
        oldWidget.canViewAllText != widget.canViewAllText) {
      debugPrint('[SrtBrowser] Data changed - 重新计算可见段落');
      _rebuildVisibleParagraphs();

      // 钳制当前 activeIndex 到可见列表合法范围
      if (_visibleParagraphs.isNotEmpty) {
        final lastIndex = _visibleParagraphs.length - 1;
        if (_activeIndex < 0 || _activeIndex > lastIndex) {
          _activeIndex = _activeIndex < 0 ? 0 : lastIndex;
        }
      } else {
        _activeIndex = 0;
      }
    } else {
      // debugPrint('[SrtBrowser] No data change - 跳过重建');
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  // 构建可见段落列表：不可查看全部文本时，每个标题只保留其后的第一个正文
  void _rebuildVisibleParagraphs() {
    if (widget.canViewAllText) {
      _visibleParagraphs = List<SrtParagraphModel>.from(widget.paragraphs);
      return;
    }
    final result = <SrtParagraphModel>[];
    bool expectFirstTextAfterTitle = false;
    for (final p in widget.paragraphs) {
      if (p.type == SrtParagraphType.title) {
        result.add(p);
        expectFirstTextAfterTitle = true;
      } else {
        if (expectFirstTextAfterTitle) {
          result.add(p);
          expectFirstTextAfterTitle = false; // 仅保留标题后的第一个正文
        }
      }
    }
    _visibleParagraphs = result;
  }

  // 外部调用的设置激活索引方法：设置后可选择是否滚动动画（true=1s，false=无动画）
  void _setActiveIndex(int index, [bool animate = true]) {
    if (index < 0 || index >= _visibleParagraphs.length) return;
    if (index == _activeIndex) return;
    setState(() => _activeIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isAutoScrolling = true;
      _scrollWhenReady(
        index,
        animate ? const Duration(seconds: 1) : const Duration(milliseconds: 1),
        Curves.easeInOut,
        0.10,
      ).whenComplete(() => _isAutoScrolling = false);
    });
  }

  // 根据播放位置设置激活索引：基于可见列表
  void _setActiveByProgress(Duration position, [bool animate = true]) {
    if (_visibleParagraphs.isEmpty) return;

    final int positionSeconds = position.inSeconds;

    // 预先计算所有可见段落的开始时间（秒）
    final List<int> paragraphTimes = _visibleParagraphs
        .map((p) => _parseTimeToSeconds(p.startTime))
        .toList();

    // 边界处理
    final int lastIndex = paragraphTimes.length - 1;
    int targetIndex;
    if (positionSeconds <= paragraphTimes.first) {
      targetIndex = 0; // 优先选择同一时间的第一个段（通常为标题）
    } else if (positionSeconds >= paragraphTimes[lastIndex]) {
      targetIndex = lastIndex;
    } else {
      int currentIndex = _activeIndex;
      if (currentIndex < 0) currentIndex = 0;
      if (currentIndex > lastIndex) currentIndex = lastIndex;

      final int currentActiveTime = paragraphTimes[currentIndex];
      targetIndex = currentIndex;

      if (positionSeconds >= currentActiveTime) {
        int i = currentIndex;
        while (i + 1 <= lastIndex && paragraphTimes[i + 1] <= positionSeconds) {
          i++;
        }
        targetIndex = i;
      } else {
        int i = currentIndex;
        while (i > 0 && paragraphTimes[i] > positionSeconds) {
          i--;
        }
        targetIndex = i;
      }
    }

    // 调整重复时间：当多个段落共享同一开始时间时，选择该时间的最后一个段（优先正文）
    final int targetTime = paragraphTimes[targetIndex];
    while (targetIndex < lastIndex && paragraphTimes[targetIndex + 1] == targetTime) {
      targetIndex++;
    }

    // 索引钳制
    if (targetIndex < 0) targetIndex = 0;
    if (targetIndex > lastIndex) targetIndex = lastIndex;

    // 用户手动滚动时仅更新高亮
    if (_isUserScrolling) {
      if (targetIndex != _activeIndex) {
        setState(() {
          _activeIndex = targetIndex;
        });
      }
    } else {
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
        final lastIndex = (_visibleParagraphs.isNotEmpty)
            ? _visibleParagraphs.length - 1
            : 0;
        int idx = _activeIndex;
        if (idx < 0) {
          idx = 0;
        } else if (idx > lastIndex) {
          idx = lastIndex;
        }
        _scrollWhenReady(
          idx,
          const Duration(milliseconds: 500),
          Curves.easeInOut,
          0.1,
        ).whenComplete(() => _isAutoScrolling = false);
      });
    }
  }

  Future<void> _scrollWhenReady(
    int index,
    Duration duration,
    Curve curve,
    double alignment,
  ) async {
    if (_visibleParagraphs.isEmpty) return;
    final int lastIndex = _visibleParagraphs.length - 1;
    final int clamped = index < 0 ? 0 : (index > lastIndex ? lastIndex : index);
    while (_itemPositionsListener.itemPositions.value.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 16));
    }
    
    // 添加null检查，防止_itemScrollController为null时崩溃
    if (_itemScrollController.isAttached) {
      await _itemScrollController.scrollTo(
        index: clamped,
        duration: duration,
        curve: curve,
        alignment: alignment,
      );
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以启用AutomaticKeepAliveClientMixin
    // debugPrint('[SrtBrowser] build called - 重新构建UI');
    // 用滚动通知检测用户手动滚动
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_isAutoScrolling) return false;
        if (notification is ScrollUpdateNotification &&
            notification.dragDetails != null) {
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
        itemCount: _visibleParagraphs.length,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
        itemBuilder: (context, index) {
          final p = _visibleParagraphs[index];
          final timeLabel = _formatMmSs(p.startTime);
          final isTitle = p.type == SrtParagraphType.title;
          return GestureDetector(
            onTap: () {
              if (widget.onParagraphTap != null) {
                widget.onParagraphTap!(p);
              }
            },
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _activeIndex != index
                        ? Colors.transparent
                        : const Color(0xFFF9F9F9).withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isTitle
                          ? SizedBox(
                              width: 56,
                              child: _TimeChip(label: timeLabel),
                            )
                          : const SizedBox(width: 56),
                      const SizedBox(width: 7),
                      Expanded(
                        child: isTitle
                            ? _TitleText(
                                text: p.text,
                                canViewAllText: widget.canViewAllText,
                              )
                            : _BodyText(
                                text: p.text,
                                canViewAllText: widget.canViewAllText,
                              ),
                      ),
                      const SizedBox(width: 63),
                    ],
                  ),
                ),
                // 仅当canViewAllText为false且不是标题时显示省略号
                (!widget.canViewAllText && !isTitle)
                    ? Row(
                        children: [
                          const SizedBox(width: 63),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                              '......',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.left,
                            ),
                            ),
                          ),
                          const SizedBox(width: 63),
                        ],
                      )
                    : SizedBox.shrink(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatMmSs(String hhmmss) {
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
        return '$hh:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
      } else {
        return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return hhmmss;
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
  const _TitleText({required this.text, required this.canViewAllText});
  final String text;
  final bool canViewAllText;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: canViewAllText ? null : 3,
      overflow: canViewAllText ? TextOverflow.visible : TextOverflow.ellipsis,
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
  const _BodyText({required this.text, required this.canViewAllText});
  final String text;
  final bool canViewAllText;

  @override
  Widget build(BuildContext context) {
    final spans = [TextSpan(text: text)];

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.left,
      maxLines: canViewAllText ? null : 3,
      overflow: canViewAllText ? TextOverflow.visible : TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
