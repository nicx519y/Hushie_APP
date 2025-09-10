import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'circular_play_button.dart';
import '../services/audio_manager.dart';
import '../models/audio_item.dart';
import '../router/navigation_utils.dart';

class CustomBottomNavigationBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onPlayButtonTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onPlayButtonTap,
  });

  @override
  State<CustomBottomNavigationBar> createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  late AudioManager _audioManager;
  bool _isPlaying = false;
  AudioItem? _currentAudio;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioManager = AudioManager.instance;
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    // 监听播放状态
    _audioManager.isPlayingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });

    // 监听当前音频
    _audioManager.currentAudioStream.listen((audio) {
      if (mounted) {
        setState(() {
          _currentAudio = audio;
        });
      }
    });

    // 监听播放位置
    _audioManager.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // 监听总时长
    _audioManager.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration.totalDuration;
        });
      }
    });
  }

  static const Color activeColor = Color(0xFF333333);
  static const Color inactiveColor = Color(0xFF999999);

  void _onPlayButtonTap() async {
    if (widget.onPlayButtonTap != null) {
      widget.onPlayButtonTap!();
    } else {
      if (_isPlaying) {
        NavigationUtils.navigateToAudioPlayer(context);
        // await _audioManager.pause();
      } else {
        NavigationUtils.navigateToAudioPlayer(context);
        await _audioManager.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.only(left: 18, right: 18, bottom: 15),
        child: Row(
          children: [
            // Home Tab
            Expanded(
              child: _buildTab(
                index: 0,
                icon: SvgPicture.asset(
                  widget.currentIndex == 0
                      ? 'assets/icons/home_selected.svg'
                      : 'assets/icons/home_default.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    widget.currentIndex == 0 ? activeColor : inactiveColor,
                    BlendMode.srcIn,
                  ),
                ),
                label: 'Home',
                isSelected: widget.currentIndex == 0,
              ),
            ),

            // 中间播放按钮
            RepaintBoundary( child: _buildPlayButton() ),

            // Profile Tab
            Expanded(
              child: _buildTab(
                index: 1,
                icon: SvgPicture.asset(
                  widget.currentIndex == 1
                      ? 'assets/icons/me_selected.svg'
                      : 'assets/icons/me_default.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    widget.currentIndex == 1 ? activeColor : inactiveColor,
                    BlendMode.srcIn,
                  ),
                ),
                label: 'Me',
                isSelected: widget.currentIndex == 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required Widget icon, // 改为 Widget 类型，支持 SVG
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => widget.onTap(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon, // 直接使用传入的 Widget
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                height: 1.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    // 计算播放进度
    double progress = 0.0;
    if (_totalDuration.inMilliseconds > 0) {
      progress =
          _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
    }

    // 安全地获取封面图片URL
    String? coverImageUrl;
    try {
      if (_currentAudio?.cover != null) {
        final bestResolution = _currentAudio!.cover.getBestResolution(70.0);
        coverImageUrl = bestResolution.url;
      }
    } catch (e) {
      debugPrint('获取封面图片失败: $e');
      coverImageUrl = null;
    }

    return Transform.translate(
      offset: const Offset(0, -11), // 向上偏移10像素
      child: CircularPlayButton(
        size: 70,
        coverImageUrl: coverImageUrl,
        isPlaying: _isPlaying,
        progress: progress,
        onTap: _onPlayButtonTap,
        progressColor: const Color(0xFFFF2D93),
        backgroundColor: const Color(0xFF666666),
        strokeWidth: 3.0,
      ),
    );
  }
}
