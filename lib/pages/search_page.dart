import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/search_box.dart';
import '../components/audio_list.dart';
import '../models/audio_item.dart';
import '../models/image_model.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _searchHistory = [];
  List<AudioItem> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    // 监听搜索框文本变化
    _searchController.addListener(() {
      setState(() {
        // 触发重建以更新清除按钮的显示状态
      });
    });
    // 延迟一帧后自动获得焦点，确保页面完全构建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // 加载搜索历史
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('search_history') ?? [];
      setState(() {
        _searchHistory = history;
      });
    } catch (e) {
      debugPrint('Load search history failed: $e');
    }
  }

  // 保存搜索历史
  Future<void> _saveSearchHistory(String keyword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('search_history') ?? [];

      // 移除重复项
      history.remove(keyword);
      // 添加到开头
      history.insert(0, keyword);
      // 限制历史记录数量为20条
      if (history.length > 20) {
        history = history.take(20).toList();
      }

      await prefs.setStringList('search_history', history);
      setState(() {
        _searchHistory = history;
      });
    } catch (e) {
      debugPrint('Save search history failed: $e');
    }
  }

  // 清除搜索历史
  Future<void> _clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('search_history');
      setState(() {
        _searchHistory = [];
      });
    } catch (e) {
      debugPrint('Clear search history failed: $e');
    }
  }

  // 执行搜索
  void _performSearch(String keyword) {
    if (keyword.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    // 保存搜索历史
    _saveSearchHistory(keyword.trim());

    // 模拟搜索API调用
    Future.delayed(const Duration(milliseconds: 500), () {
      // 这里应该是实际的API调用
      // 现在使用模拟数据
      final mockResults = _generateMockSearchResults(keyword);

      setState(() {
        _searchResults = mockResults;
        _isSearching = false;
      });
    });
  }

  // 生成模拟搜索结果
  List<AudioItem> _generateMockSearchResults(String keyword) {
    // 模拟搜索结果数据
    return [
      AudioItem(
        id: '1',
        cover: ImageModel(
          id: 'search_1',
          urls: ImageResolutions(
            x1: ImageResolution(
              url: 'https://picsum.photos/400/600?random=401',
              width: 400,
              height: 600,
            ),
            x2: ImageResolution(
              url: 'https://picsum.photos/800/1200?random=401',
              width: 800,
              height: 1200,
            ),
          ),
        ),
        title: '搜索结果: $keyword - 音乐作品1',
        desc: '这是一个关于 $keyword 的音乐作品，包含了丰富的音乐元素',
        author: '艺术家A',
        avatar: '',
        playTimes: 13000,
        likesCount: 2293,
        previewStart: Duration(milliseconds: 30000), // 从30秒开始预览
        previewDuration: Duration(milliseconds: 15000), // 预览15秒
      ),
      AudioItem(
        id: '2',
        cover: ImageModel(
          id: 'search_2',
          urls: ImageResolutions(
            x1: ImageResolution(
              url: 'https://picsum.photos/400/500?random=402',
              width: 400,
              height: 500,
            ),
            x2: ImageResolution(
              url: 'https://picsum.photos/800/1000?random=402',
              width: 800,
              height: 1000,
            ),
          ),
        ),
        title: '$keyword 相关的音乐创作',
        desc: '基于 $keyword 主题创作的电子音乐，融合了多种风格',
        author: '艺术家B',
        avatar: '',
        playTimes: 8900,
        likesCount: 1567,
        previewStart: Duration(milliseconds: 25000), // 从25秒开始预览
        previewDuration: Duration(milliseconds: 18000), // 预览18秒
      ),
      AudioItem(
        id: '3',
        cover: ImageModel(
          id: 'search_3',
          urls: ImageResolutions(
            x1: ImageResolution(
              url: 'https://picsum.photos/400/700?random=403',
              width: 400,
              height: 700,
            ),
            x2: ImageResolution(
              url: 'https://picsum.photos/800/1400?random=403',
              width: 800,
              height: 1400,
            ),
          ),
        ),
        title: '$keyword 音乐合集',
        desc: '精选的 $keyword 相关音乐作品，涵盖多种流派',
        author: '艺术家C',
        avatar: '',
        playTimes: 21000,
        likesCount: 3421,
        previewStart: Duration(milliseconds: 20000), // 从20秒开始预览
        previewDuration: Duration(milliseconds: 12000), // 预览12秒
      ),
    ];
  }

  // 点击搜索历史项
  void _onHistoryItemTap(String keyword) {
    _searchController.text = keyword;
    _performSearch(keyword);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 搜索框
                  Expanded(
                    child: // 搜索栏
                    SearchBox(
                      hintText: '',
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onSearchChanged: (value) {
                        // 可以在这里实现实时搜索建议
                      },
                      onSearchSubmitted: () {
                        // 获取搜索框的当前文本
                        final currentText = _searchController.text;
                        if (currentText.isNotEmpty) {
                          _performSearch(currentText);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 清除搜索按钮
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _hasSearched = false;
                        _searchResults = [];
                      });
                      // 重新获得焦点
                      _searchFocusNode.requestFocus();
                    },
                    icon: const Icon(Icons.close, color: Colors.grey),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFE9EAEB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(21),
                      ),
                      minimumSize: const Size(42, 42),
                    ),
                  ),
                ],
              ),
            ),
            // 内容区域
            Expanded(
              child: _hasSearched
                  ? _buildSearchResults()
                  : _buildSearchHistory(),
            ),
          ],
        ),
      ),
    );
  }

  // 构建搜索历史界面
  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索历史标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Search History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                  height: 1.3,
                ),
              ),
              IconButton(
                onPressed: _clearSearchHistory,
                icon: const Icon(Icons.delete, color: Color(0xFF666666)),
              ),
            ],
          ),
        ),

        // 搜索历史标签
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _searchHistory.map((keyword) {
                return GestureDetector(
                  onTap: () => _onHistoryItemTap(keyword),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      keyword,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // 构建搜索结果界面
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return AudioList(
      audios: _searchResults,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    );
  }
}
