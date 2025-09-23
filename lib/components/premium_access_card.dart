import 'package:flutter/material.dart';
import 'package:hushie_app/components/subscribe_dialog.dart';
import 'package:hushie_app/services/subscribe_privilege_manager.dart';
import 'package:hushie_app/models/user_privilege_model.dart';
import 'dart:async';

class PremiumAccessCard extends StatefulWidget {
  const PremiumAccessCard({super.key});

  @override
  State<PremiumAccessCard> createState() => _PremiumAccessCardState();
}

class _PremiumAccessCardState extends State<PremiumAccessCard> {
  // 内部变量
  final String _title = 'Hushie Pro';
  late String _subtitle = 'Full Access to All Creations';
  final String _buttonText = 'Subscribe';
  final Color _primaryColor = const Color(0xFFFFF4D6);
  final Color _secondaryColor = const Color(0xFFFEE68B);
  
  StreamSubscription<PrivilegeChangeEvent>? _privilegeSubscription;

  @override
  void initState() {
    super.initState();

    SubscribePrivilegeManager.instance.getUserPrivilege().then((privilege) {
      if (mounted) {
        _updateSubtitleBasedOnPrivilege(privilege);
        _initializePrivilegeListener();
      }
    });
  }

  @override
  void dispose() {
    _privilegeSubscription?.cancel();
    super.dispose();
  }

  /// 初始化权益监听器
  void _initializePrivilegeListener() {
    // 监听权益变化
    _privilegeSubscription = SubscribePrivilegeManager.instance.privilegeChanges.listen(
      (event) {
        if (mounted) {
          _updateSubtitleBasedOnPrivilege(event.privilege);
        }
      },
      onError: (error) {
        debugPrint('🏆 [PREMIUM_ACCESS_CARD] 权益监听异常: $error');
      },
    );

  }

  /// 根据权益状态更新 subtitle
  void _updateSubtitleBasedOnPrivilege(UserPrivilege? privilege) {
    setState(() {
      if (privilege != null && privilege.hasPremium) {
        // 有权益的情况下显示过期时间
        if (privilege.premiumExpireTime != null) {
          final expireDate = privilege.premiumExpireTime;
          if (expireDate != null) {
            _subtitle = _formatExpireTime(expireDate);
          } else {
            _subtitle = 'Premium Active';
          }
        } else {
          _subtitle = 'Full Access to All Creations';
        }
      } else {
        // 没权益的情况下显示默认文本
        _subtitle = 'Full Access to All Creations';
      }
    });
  }

  /// 格式化过期时间显示
  String _formatExpireTime(DateTime expireTime) {
    // 2025-09-01
    return 'Expires on ${expireTime.toLocal().toString().split(' ')[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_primaryColor, _secondaryColor],
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
                    _primaryColor.withAlpha(255),
                    _secondaryColor.withAlpha(255),
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
                            _title,
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
                        _subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1,
                          color: Color(0xFF817664),
                        ),
                      ),
                      const SizedBox(height: 22),
                      InkWell(
                        onTap: () {
                          showSubscribeDialog(context);
                        },
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
                            _buttonText,
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
