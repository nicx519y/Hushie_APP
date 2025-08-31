import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/number_formatter.dart';

class AudioStats extends StatelessWidget {
  final int playTimes;
  final int likesCount;
  final String author;
  final double iconSize;
  final double fontSize;
  final Color? textColor;
  final double spacing;

  const AudioStats({
    super.key,
    required this.playTimes,
    required this.likesCount,
    required this.author,
    this.iconSize = 12,
    this.fontSize = 10,
    this.textColor = const Color(0xFF333333),
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 播放次数
        SvgPicture.asset(
          'assets/icons/play.svg',
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(textColor!, BlendMode.srcIn),
        ),
        const SizedBox(width: 4),
        Text(
          NumberFormatter.countNumFilter(playTimes),
          style: TextStyle(
            fontSize: fontSize,
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: spacing),

        // 点赞数
        SvgPicture.asset(
          'assets/icons/likes.svg',
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(textColor!, BlendMode.srcIn),
        ),
        const SizedBox(width: 4),
        Text(
          NumberFormatter.countNumFilter(likesCount),
          style: TextStyle(
            fontSize: fontSize,
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: spacing),

        // 作者
        SvgPicture.asset(
          'assets/icons/author.svg',
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(textColor!, BlendMode.srcIn),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            author,
            style: TextStyle(
              fontSize: fontSize,
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
