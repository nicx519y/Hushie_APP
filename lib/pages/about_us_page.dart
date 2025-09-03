import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            // Hushie Logo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF359AA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Hushie',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF359AA),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 版本号
            Text(
              'V1.0.0',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 40),

            // 描述文本
            const Text(
              'Hushie is a platform for immersive role-play audio experiences. Users can share their own creations, generate original works with the help of AI, or interact with and remix others\' content through AI-powered collaboration. Our app offers a wide variety of rich and personalized audio products, designed to meet all your needs for creative, entertaining, and engaging sound experiences.',
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // 联系方式
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'If you have any questions, please contact us at hushiesupport@gmail.com.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 40),

            // 底部链接
            Column(
              children: [
                _buildLink('Privacy Policy', () {
                  // TODO: 跳转到隐私政策页面
                  print('Privacy Policy');
                }),
                const SizedBox(height: 16),
                _buildLink('Terms of Use', () {
                  // TODO: 跳转到使用条款页面
                  print('Terms of Use');
                }),
                const SizedBox(height: 16),
                _buildLink('End User License Agreement', () {
                  // TODO: 跳转到用户许可协议页面
                  print('End User License Agreement');
                }),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.blue,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
