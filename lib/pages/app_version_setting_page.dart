import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../utils/toast_helper.dart';

class AppVersionSettingPage extends StatefulWidget {
  const AppVersionSettingPage({super.key});

  @override
  State<AppVersionSettingPage> createState() => _AppVersionSettingPageState();
}

class _AppVersionSettingPageState extends State<AppVersionSettingPage> {
  late TextEditingController _versionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _versionController = TextEditingController(text: ApiConfig.getAppVersion());
  }

  @override
  void dispose() {
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _saveVersion() async {
    final newVersion = _versionController.text.trim();
    
    if (newVersion.isEmpty) {
      ToastHelper.showError('版本号不能为空');
      return;
    }

    // 简单的版本号格式验证
    final versionRegex = RegExp(r'^\d+\.\d+\.\d+$');
    if (!versionRegex.hasMatch(newVersion)) {
      ToastHelper.showError('版本号格式不正确，请使用 x.y.z 格式');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 保存新版本号
      await ApiConfig.setAppVersion(newVersion);
      
      // 显示成功提示
      ToastHelper.showSuccess('版本号已更新为 $newVersion');
      
      // 延迟返回上一页
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      ToastHelper.showError('保存失败: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetToDefault() {
    _versionController.text = '1.0.0';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'App Version Setting',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Color(0xFFF8F7F7)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前版本显示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前版本',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ApiConfig.getAppVersion(),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 版本号输入
            const Text(
              '设置新版本号',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _versionController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  hintText: '请输入版本号 (例如: 1.0.0)',
                  hintStyle: TextStyle(color: Color(0xFF999999)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 格式说明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE6F3FF)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Color(0xFF1890FF),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '版本号格式：主版本号.次版本号.修订号 (例如: 1.2.3)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1890FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _resetToDefault,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      '重置默认',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveVersion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1890FF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '保存',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}