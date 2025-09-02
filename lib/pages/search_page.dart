import 'package:flutter/material.dart';
import 'package:hushie_app/models/api_response.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/search_box.dart';
import '../components/audio_list.dart';
import '../models/audio_item.dart';
import '../models/image_model.dart';
import '../services/api/audio_search_service.dart';

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

  // 新增的分页相关状态
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _lastCid;

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
  Future<void> _performSearch(String keyword, {bool isLoadMore = false}) async {
    if (keyword.trim().isEmpty) return;

    if (!isLoadMore) {
      setState(() {
        _isSearching = true;
        _hasSearched = true;
        _searchResults = [];
        _lastCid = null;
        _hasMoreData = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      ApiResponse<SimpleResponse<AudioItem>> searchResults =
          await AudioSearchService.getAudioSearchList(
            searchQuery: keyword,
            cid: isLoadMore ? _lastCid : null,
            count: 30,
          );

      if (searchResults.errNo == 0 && searchResults.data != null) {
        final newItems = searchResults.data!.items;

        setState(() {
          if (isLoadMore) {
            _searchResults.addAll(newItems);
            _isLoadingMore = false;
          } else {
            _searchResults = newItems;
            _isSearching = false;
          }

          // 更新分页状态
          if (newItems.isNotEmpty) {
            _lastCid = newItems.last.id;
            _hasMoreData = newItems.length >= 30; // 如果返回的数据少于请求数量，说明没有更多数据
          } else {
            _hasMoreData = false;
          }
        });
      } else {
        setState(() {
          if (isLoadMore) {
            _isLoadingMore = false;
          } else {
            _isSearching = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Search failed: $e');
      setState(() {
        if (isLoadMore) {
          _isLoadingMore = false;
        } else {
          _isSearching = false;
        }
      });
    }
  }

  // 下拉刷新
  Future<void> _onRefresh() async {
    if (_searchController.text.isNotEmpty) {
      await _performSearch(_searchController.text);
    }
  }

  // 加载更多
  Future<void> _onLoadMore() async {
    if (_searchController.text.isNotEmpty && _hasMoreData && !_isLoadingMore) {
      await _performSearch(_searchController.text, isLoadMore: true);
    }
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
    if (_isSearching && _searchResults.isEmpty) {
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
      onRefresh: _onRefresh,
      onLoadMore: _onLoadMore,
      hasMoreData: _hasMoreData,
      isLoadingMore: _isLoadingMore,
    );
  }
}
