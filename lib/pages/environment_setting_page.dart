import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
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
          ],
        ),
      ),
    );
  }
}