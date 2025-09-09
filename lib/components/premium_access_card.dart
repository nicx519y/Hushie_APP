import 'package:flutter/material.dart';

class PremiumAccessCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback? onSubscribe;
  final Color? primaryColor;
  final Color? secondaryColor;
  final IconData? decorationIcon;

  const PremiumAccessCard({
    super.key,
    this.title = 'Hushie Pro',
    this.subtitle = 'Full Access to All Creations',
    this.buttonText = 'Subscribe',
    this.onSubscribe,
    this.primaryColor = const Color(0xFFFFF4D6),
    this.secondaryColor = const Color(0xFFFEE68B),
    this.decorationIcon = Icons.music_note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [primaryColor!, secondaryColor!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // 渐变遮罩层，确保文字可读性
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryColor!.withAlpha(255),
                    secondaryColor!.withAlpha(255),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // 背景图片层 - 固定在右侧
          Positioned(
            right: -60,
            top: 0,
            bottom: -10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/crown.png',
                fit: BoxFit.contain,
                width: 200,
                height: 200,
              ),
            ),
          ),
          // 内容层
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/crown_mini.png',
                            width: 29,
                            height: 21.5,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF502D19),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1,
                          color: Color(0xFF817664),
                        ),
                      ),
                      const SizedBox(height: 22),
                      InkWell(
                        onTap: onSubscribe,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF502D19),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            buttonText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
