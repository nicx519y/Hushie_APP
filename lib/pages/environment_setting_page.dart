import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../utils/toast_helper.dart';
import '../services/device_info_service.dart';

class EnvironmentSettingPage extends StatefulWidget {
  const EnvironmentSettingPage({super.key});

  @override
  State<EnvironmentSettingPage> createState() => _EnvironmentSettingPageState();
}

class _EnvironmentSettingPageState extends State<EnvironmentSettingPage> {
  bool _useTestEnv = ApiConfig.isTestEnv;
  bool _isSaving = false;
  String? _deviceId;
  // App Version settings
  late TextEditingController _versionController;
  bool _isVersionSaving = false;
  bool _isVersionRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    _versionController = TextEditingController(text: ApiConfig.getAppVersion());
  }

  @override
  void dispose() {
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    try {
      final id = await DeviceInfoService.getDeviceId();
      if (mounted) {
        setState(() {
          _deviceId = id;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _deviceId = 'unknown_device';
        });
      }
    }
  }

  Future<void> _applyEnv(bool useTest) async {
    if (_isSaving) return;
    setState(() {
      _useTestEnv = useTest;
      _isSaving = true;
    });
    try {
      await ApiConfig.setEnvironment(useTestEnv: useTest);
      final envName = useTest ? 'Test' : 'Production';
      ToastHelper.showSuccess('Switched to $envName environment');
    } catch (e) {
      ToastHelper.showError('Switch environment failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ===== App Version Settings Methods =====
  Future<void> _saveVersion() async {
    final newVersion = _versionController.text.trim();
    if (newVersion.isEmpty) {
      ToastHelper.showError('版本号不能为空');
      return;
    }

    final versionRegex = RegExp(r'^\d+\.\d+\.\d+$');
    if (!versionRegex.hasMatch(newVersion)) {
      ToastHelper.showError('版本号格式不正确，请使用 x.y.z 格式');
      return;
    }

    setState(() {
      _isVersionSaving = true;
    });

    try {
      await ApiConfig.setAppVersion(newVersion);
      ToastHelper.showSuccess('版本号已更新为 $newVersion');
      setState(() {});
    } catch (e) {
      ToastHelper.showError('保存失败: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isVersionSaving = false;
        });
      }
    }
  }

  void _resetToDefaultVersion() {
    _versionController.text = '1.0.0';
  }

  Future<void> _refreshFromPackageInfo() async {
    setState(() {
      _isVersionRefreshing = true;
    });
    try {
      await ApiConfig.resetAppVersionToPackageInfo();
      final v = ApiConfig.getAppVersion();
      _versionController.text = v;
      ToastHelper.showSuccess('已刷新为包信息版本：$v');
      setState(() {});
    } catch (e) {
      ToastHelper.showError('刷新失败: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isVersionRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentHost = ApiConfig.currentHost;
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
          'Environment Setting',
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
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current environment card
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
                    'Current Environment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _useTestEnv ? 'Test' : 'Production',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Host: $currentHost',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Device ID: ${_deviceId ?? 'Loading...'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Options
            Container(
              width: double.infinity,
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
                children: [
                  RadioListTile<bool>(
                    value: false,
                    groupValue: _useTestEnv,
                    onChanged: _isSaving ? null : (value) => _applyEnv(false),
                    title: const Text(
                      'Production',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                    ),
                    subtitle: Text(ApiConfig.baseHost),
                  ),
                  const Divider(height: 1),
                  RadioListTile<bool>(
                    value: true,
                    groupValue: _useTestEnv,
                    onChanged: _isSaving ? null : (value) => _applyEnv(true),
                    title: const Text(
                      'Test',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                    ),
                    subtitle: Text(ApiConfig.testHost),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              'Switching takes effect immediately for new requests. Some in-flight operations may still use previous host.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
              ),
            ),

            const SizedBox(height: 24),

            // ===== Current Version Card =====
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

            // ===== App Version Settings UI =====
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
                enabled: !_isVersionSaving,
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

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isVersionSaving ? null : _resetToDefaultVersion,
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
                    onPressed: _isVersionSaving ? null : _saveVersion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1890FF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: _isVersionSaving
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

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isVersionRefreshing ? null : _refreshFromPackageInfo,
                icon: _isVersionRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.system_update_alt, size: 18, color: Color(0xFF666666)),
                label: const Text(
                  '从包信息刷新版本',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}