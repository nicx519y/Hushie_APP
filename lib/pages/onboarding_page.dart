import 'package:flutter/material.dart';
import '../models/onboarding_model.dart';
import '../services/api/onboarding_service.dart';
import '../services/onboarding_manager.dart';
import '../utils/toast_helper.dart';
import '../pages/subscribe_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/custom_icons.dart';

/// 新手引导页面
/// 包含3个步骤：场景选择 -> 性别选择 -> 语调选择
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const Color activeColor = Color(0xFFFF5082);

  int _currentStep = 0;
  bool _isLoading = false; // 初始不请求，不显示loading
  bool _isSubmitting = false; // 添加提交状态
  OnboardingGuideData? _guideData;

  // 首次点击后再发起请求
  bool _hasRequested = false;

  // 用户选择的偏好 - 改为多选
  final List<String> _selectedScenes = [];
  final List<String> _selectedGenders = [];
  final List<String> _selectedTones = [];

  @override
  void initState() {
    super.initState();
    // 初始化时不请求数据，等待用户首次点击
  }

  void _triggerFirstLoad() {
    if (_hasRequested || _isLoading) return;
    setState(() {
      _hasRequested = true;
      _isLoading = true;
    });
    _loadGuideData();
  }

  /// 加载引导数据
  Future<void> _loadGuideData() async {
    try {
      final data = await OnboardingService.getGuideData();
      if (!mounted) return;
      setState(() {
        _guideData = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载引导数据失败: $e');
      ToastHelper.showError('加载数据失败，请重试');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 进入下一步
  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      _submitPreferences();
    }
  }

  /// 提交用户偏好
  Future<void> _submitPreferences() async {
    if (_selectedScenes.isEmpty ||
        _selectedGenders.isEmpty ||
        _selectedTones.isEmpty) {
      ToastHelper.showError('请完成所有选择');
      return;
    }

    // 防止重复提交
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final request = UserPreferencesRequest(
        tagGender: List<String>.from(_selectedGenders),
        tagTone: List<String>.from(_selectedTones),
        tagScene: List<String>.from(_selectedScenes),
      );

      await OnboardingService.setPreferences(request);

      // 标记新手引导为已完成
      await OnboardingManager().markOnboardingCompleted();

      // 跳转到订阅页面
      String pref = _computeBannerPreference();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SubscribePage(bannerPreference: pref),
            settings: const RouteSettings(name: '/subscribe'),
          ),
        );
      }
    } catch (e) {
      debugPrint('提交偏好失败: $e');
      // 即使失败也跳转到订阅页面
      String pref = _computeBannerPreference();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SubscribePage(bannerPreference: pref),
            settings: const RouteSettings(name: '/subscribe'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// 获取当前步骤的标题
  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Pick your scenario preference';
      case 1:
        return 'Pick your interests';
      case 2:
        return 'Pick your voice preference';
      default:
        return '';
    }
  }

  /// 获取当前选中的值列表
  List<String> _getCurrentSelections() {
    switch (_currentStep) {
      case 0:
        return _selectedScenes;
      case 1:
        return _selectedGenders;
      case 2:
        return _selectedTones;
      default:
        return [];
    }
  }

  /// 切换选中状态（多选）
  void _toggleSelection(String value) {
    setState(() {
      switch (_currentStep) {
        case 0:
          if (_selectedScenes.contains(value)) {
            _selectedScenes.remove(value);
          } else {
            _selectedScenes.add(value);
          }
          break;
        case 1:
          if (_selectedGenders.contains(value)) {
            _selectedGenders.remove(value);
          } else {
            _selectedGenders.add(value);
          }
          break;
        case 2:
          if (_selectedTones.contains(value)) {
            _selectedTones.remove(value);
          } else {
            _selectedTones.add(value);
          }
          break;
      }
    });
  }

  /// 检查是否可以进入下一步
  bool _canProceed() {
    // 如果正在提交，禁用按钮
    if (_isSubmitting) return false;
    return _getCurrentSelections().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: !_hasRequested ? _triggerFirstLoad : null,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      // 顶部进度指示器
                      Row(
                        children: [
                          Transform.translate(
                            offset: const Offset(0, 0),
                            child: SvgPicture.asset(
                              'assets/icons/logo.svg',
                              height: 30,
                              width: 120,
                            ),
                          ),
                          Expanded(child: _buildProgressIndicator()),
                        ],
                      ),

                      SizedBox(height: 43),

                      // 标题
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          _getStepTitle(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),

                      SizedBox(height: 24),

                      // 选项列表
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: _buildOptionsList(),
                        ),
                      ),

                      SizedBox(height: 24),

                      // 底部导航按钮
                      SizedBox(
                        width: double.infinity,
                        child: _buildBottomNavigation(),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// 构建进度指示器
  Widget _buildProgressIndicator() {
    return Row(
      children: [
        for (int index = 0; index < 3; index++) ...[
          // 原点
          Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 3,
                color: index <= _currentStep
                    ? activeColor
                    : const Color(0xFFD8D8D8),
              ),
            ),
          ),
          // 横线（除最后一个步骤外）
          if (index < 2)
            Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: index < _currentStep
                      ? activeColor
                      : const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// 构建单个标签组件（支持多选）
  Widget _buildTagItem(TagOption option, bool isSelected) {
    final bgColor = const Color(0xFFF1F3F6); // 浅灰底色
    final textColor = isSelected ? activeColor : const Color(0xFF333333);
    final textWeight = isSelected ? FontWeight.w700 : FontWeight.w400;

    final labelText = option.label;

    return GestureDetector(
      onTap: () => _toggleSelection(option.value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999), // 圆角Tag
          border: Border.all(
            width: 2,
            color: isSelected ? activeColor : Colors.transparent,
          ),
        ),
        child: Text(
          labelText,
          style: TextStyle(
            fontSize: 16,
            fontWeight: textWeight,
            color: textColor,
          ),
        ),
      ),
    );
  }

  /// 构建 checkbox 样式的选项组件（用于第二个步骤）
  Widget _buildCheckboxItem(TagOption option, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSelection(option.value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFFE9EAEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            width: 2,
            color: isSelected ? activeColor : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // 左侧文本
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? activeColor : const Color(0xFF333333),
                ),
              ),
            ),
            // 右侧 checkbox
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(6),
                color: isSelected ? activeColor : Colors.white,
                border: Border.all(
                  width: 2,
                  color: activeColor,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建场景选择选项列表
  Widget _buildSceneOptions() {
    if (_guideData == null) return const SizedBox.shrink();

    final options = _guideData!.tagScene;
    final selectedValues = _selectedScenes;

    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: options.map((option) {
          final isSelected = selectedValues.contains(option.value);
          return _buildTagItem(option, isSelected);
        }).toList(),
      ),
    );
  }

  /// 构建性别选择选项列表
  Widget _buildGenderOptions() {
    if (_guideData == null) return const SizedBox.shrink();

    final options = _guideData!.tagGender;
    final selectedValues = _selectedGenders;

    return SingleChildScrollView(
      child: Column(
        children: options.map((option) {
          final isSelected = selectedValues.contains(option.value);
          return _buildCheckboxItem(option, isSelected);
        }).toList(),
      ),
    );
  }

  /// 构建语调选择选项列表
  Widget _buildToneOptions() {
    if (_guideData == null) return const SizedBox.shrink();

    final options = _guideData!.tagTone;
    final selectedValues = _selectedTones;

    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: options.map((option) {
          final isSelected = selectedValues.contains(option.value);
          return _buildTagItem(option, isSelected);
        }).toList(),
      ),
    );
  }

  /// 计算订阅页横幅偏好：
  /// - 选择了 M4F 或 M4M => 偏好 M
  /// - 选择了 F4M 或 F4F => 偏好 F
  /// - 两者都包含 => 偏好 F&M
  /// - 都未选 => 默认 F
  String _computeBannerPreference() {
    final hasM = _selectedGenders.contains('M4F') || _selectedGenders.contains('M4M');
    final hasF = _selectedGenders.contains('F4F') || _selectedGenders.contains('F4M');

    if (hasM && hasF) return 'F&M';
    if (hasM) return 'M';
    if (hasF) return 'F';
    return 'F';
  }

  /// 构建选项列表（根据当前步骤选择对应的渲染函数）
  Widget _buildOptionsList() {
    switch (_currentStep) {
      case 0:
        return _buildSceneOptions();
      case 1:
        return _buildGenderOptions();
      case 2:
        return _buildToneOptions();
      default:
        return const SizedBox.shrink();
    }
  }

  /// 构建底部导航
  Widget _buildBottomNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () async {
              // 跳过时也标记为已完成并跳转到订阅页面
              await OnboardingManager().markOnboardingCompleted();
              String pref = _computeBannerPreference();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => SubscribePage(bannerPreference: pref),
                    settings: const RouteSettings(name: '/subscribe'),
                  ),
                );
              }
            },
            child: const Text(
              'I\'m a Returning User',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
                decoration: TextDecoration.underline,
              ),
            ),
          ),

          // 下一步按钮
          GestureDetector(
            onTap: _canProceed() ? _nextStep : null,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _canProceed() ? activeColor : const Color(0xFFBBBBBB),
                shape: BoxShape.circle,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Transform.rotate(
                      angle: -3.1415926 / 2,
                      child: Transform.translate(
                        offset: const Offset(0, 2),
                        child: Icon(
                          CustomIcons.arrow_down,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
