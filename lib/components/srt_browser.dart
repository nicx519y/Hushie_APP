import 'package:flutter/material.dart';
import '../models/srt_model.dart';

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
  void setActiveByProgress(double progress, [bool animate = true]) {
    _state?._setActiveByProgress(progress, animate);
  }
  int? get activeIndex => _state?._activeIndex;
}

/// 字幕浏览组件：根据 SrtParagraphModel 渲染标题与正文段落
class SrtBrowser extends StatefulWidget {
  const SrtBrowser({super.key, required this.paragraphs, this.controller, this.initPorgress});

  final List<SrtParagraphModel> paragraphs;
  final SrtBrowserController? controller;
  final double? initPorgress; // 0.0 ~ 1.0 的初始进度

  @override
  State<SrtBrowser> createState() => _SrtBrowserState();
}

class _SrtBrowserState extends State<SrtBrowser> {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _itemKeys;
  int _activeIndex = 0; // 当前激活的段落索引

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(widget.paragraphs.length, (_) => GlobalKey());
    widget.controller?._attach(this);

    // 根据入参 initPorgress 设置初始 activeIndex
    if (widget.initPorgress != null && widget.paragraphs.isNotEmpty) {
      final p = widget.initPorgress!.clamp(0.0, 1.0);
      final idx = (p * (widget.paragraphs.length - 1)).round();
      _activeIndex = idx;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _itemKeys[idx].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant SrtBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    // paragraphs 长度变化时，同步 itemKeys
    if (widget.paragraphs.length != _itemKeys.length) {
      if (widget.paragraphs.length > _itemKeys.length) {
        _itemKeys.addAll(List.generate(
            widget.paragraphs.length - _itemKeys.length, (_) => GlobalKey()));
      } else {
        _itemKeys = _itemKeys.sublist(0, widget.paragraphs.length);
      }
    }
    // 控制器变更处理
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _scrollController.dispose();
    super.dispose();
  }

  // 外部调用的设置激活索引方法：设置后可选择是否滚动动画（true=1s，false=无动画）
  void _setActiveIndex(int index, [bool animate = true]) {
    if (index < 0 || index >= widget.paragraphs.length) return;
    if (index == _activeIndex) return; // 避免重复 setState
    setState(() {
      _activeIndex = index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[index];
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: animate ? const Duration(seconds: 1) : Duration.zero,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // 通过进度定位激活索引：progress 0.0~1.0，自动计算索引并设置
  void _setActiveByProgress(double progress, [bool animate = true]) {
    if (widget.paragraphs.isEmpty) return;
    final p = progress.clamp(0.0, 1.0);
    final idx = (p * (widget.paragraphs.length - 1)).round();
    _setActiveIndex(idx, animate);
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.paragraphs.isEmpty) {
      return SizedBox.shrink();
    }

    // 段落列表
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
      itemCount: widget.paragraphs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        final p = widget.paragraphs[index];
        final timeLabel = _formatMmSs(p.startTime);
        final isTitle = p.type == SrtParagraphType.title;

        return Container(
          key: _itemKeys[index],
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
              SizedBox(
                width: 56,
                child:
                    isTitle ? _TimeChip(label: timeLabel) : const SizedBox.shrink(),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Container(
                  // padding: const EdgeInsets.symmetric(vertical: 4),
                  child:
                      isTitle ? _TitleText(text: p.text) : _BodyText(text: p.text),
                ),
              ),
              const SizedBox(width: 63),
            ],
          ),
        );
      },
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
      final mm = total.inMinutes % 60; // 以分钟显示
      final ss = total.inSeconds % 60;
      return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
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
