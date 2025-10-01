import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../components/search_box.dart';
import '../components/audio_list.dart';
import '../models/audio_item.dart';
import '../services/api/audio_search_service.dart';
import '../services/audio_manager.dart';
import '../router/navigation_utils.dart';
import '../components/subscribe_dialog.dart';
import '../services/subscribe_privilege_manager.dart';
import '../services/analytics_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // 配置常量
  static const int _debounceDelay = 800; // 防抖延迟时间（毫秒），可配置
  static const int _historyLimit = 10; // 搜索历史记录限制数量

  final TextEditingController _searchController = TextEditingController();
  late FocusNode _searchFocusNode;
  List<String> _searchHistory = [];
  List<AudioItem> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _canTapSearchItem = false;

  // 新增的分页相关状态
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _lastCid;

  // 新增的实时搜索相关状态
  Timer? _debounceTimer;
  String? _currentSearchQuery; // 当前正在搜索的查询
  String? _lastRenderedQuery; // 最后渲染结果的查询
  StreamSubscription? _privilegeSubscription;

  @override
  void initState() {
    super.initState();

    SubscribePrivilegeManager.instance.hasValidPremium().then((value) {
      setState(() {
        _canTapSearchItem = value;
      });
    });

    // 监听订阅状态变化
    _privilegeSubscription = SubscribePrivilegeManager.instance.privilegeChanges
        .listen((event) {
          setState(() {
            _canTapSearchItem = event.hasPremium;
          });
        });

    _searchFocusNode = FocusNode();

    _loadSearchHistory();
    // 监听搜索框文本变化，实现实时搜索
    _searchController.addListener(_onSearchTextChanged);
    // 延迟一帧后自动获得焦点，确保页面完全构建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();

    // 取消订阅状态变化监听
    _privilegeSubscription?.cancel();

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
      // 限制历史记录数量为10条
      if (history.length > _historyLimit) {
        history = history.take(_historyLimit).toList();
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

    // 如果不是加载更多，检查查询是否已过期
    if (!isLoadMore && keyword != _currentSearchQuery) {
      debugPrint('搜索查询已过期，跳过: $keyword');
      return;
    }

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
      final searchResults = await AudioSearchService.searchAudio(
        query: keyword,
        cid: isLoadMore ? _lastCid : null,
        count: 30,
      );

      // 再次检查查询是否已过期（防止异步请求返回时查询已改变）
      if (!isLoadMore && keyword != _currentSearchQuery) {
        debugPrint('搜索结果查询已过期，不渲染: $keyword');
        setState(() {
          _isSearching = false;
        });
        return;
      }

      if (searchResults.isNotEmpty) {
        final newItems = searchResults;

        // 记录搜索事件（仅在首次搜索时记录）
        if (!isLoadMore) {
          AnalyticsService().logSearch(
            searchTerm: keyword,
            resultCount: newItems.length,
          );
        }

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
      // 检查查询是否已过期
      if (!isLoadMore && keyword != _currentSearchQuery) {
        debugPrint('搜索异常时查询已过期，不处理: $keyword');
        return;
      }

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
  // Future<void> _onRefresh() async {
  //   final currentText = _searchController.text;
  //   if (currentText.isNotEmpty) {
  //     _currentSearchQuery = currentText;
  //     _lastRenderedQuery = currentText;
  //     await _performSearch(currentText);
  //   }
  // }

  // 加载更多
  Future<void> _onLoadMore() async {
    final currentText = _searchController.text;
    if (currentText.isNotEmpty && _hasMoreData && !_isLoadingMore) {
      await _performSearch(currentText, isLoadMore: true);
    }
  }

  // 播放音频
  Future<void> _playAudio(AudioItem audio) async {
    try {
      await AudioManager.instance.playAudio(audio);
    } catch (e) {
      debugPrint('播放音频失败: $e');
    }
  }

  // 清空搜索框
  void _cleanQuery() {
    _searchController.clear();
    _debounceTimer?.cancel();
    _currentSearchQuery = null;
    _lastRenderedQuery = null;
    setState(() {
      _hasSearched = false;
      _searchResults = [];
      _isSearching = false;
      _isLoadingMore = false;
      _hasMoreData = true;
      _lastCid = null;
    });
  }

  // 关闭搜索页
  void _closeSearch() {
    _cleanQuery();
    Navigator.pop(context);
  }

  // 点击搜索结果项
  void _onSearchItemTap(AudioItem audio) {
    if (_canTapSearchItem) {
      // 保存当前搜索查询到历史
      _saveSearchHistory(_searchController.text);
      
      // 记录音频播放事件
      AnalyticsService().logAudioPlay(
        audioId: audio.id,
        audioTitle: audio.title,
        category: 'search_results',
      );
      
      // 播放音频
      _playAudio(audio);
      // 进入播放页面
      NavigationUtils.navigateToAudioPlayer(context, initialAudio: audio);
    } else {
      // 没有权限，提示用户订阅
      showSubscribeDialog(context);
    }
  }

  // 点击搜索历史项
  void _onHistoryItemTap(String keyword) {
    _searchController.text = keyword;
    // 手动触发搜索，设置查询状态
    _currentSearchQuery = keyword;
    _lastRenderedQuery = keyword;
    _debounceTimer?.cancel();
    _performSearch(keyword);
  }

  // 实时搜索文本变化监听
  void _onSearchTextChanged() {
    // 如果当前不在搜索状态，则立即设置为搜索状态
    setState(() {
      _isSearching = true;
    });
    _searchResults = [];

    final currentText = _searchController.text;
    if (currentText.isNotEmpty && currentText != _lastRenderedQuery) {
      _lastRenderedQuery = currentText;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(Duration(milliseconds: _debounceDelay), () {
        _currentSearchQuery = currentText;
        _performSearch(_currentSearchQuery!);
      });
    } else if (currentText.isEmpty) {
      _lastRenderedQuery = null;
      _currentSearchQuery = null;
      _debounceTimer?.cancel();
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        top: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // 搜索框
                  Expanded(
                    child: // 搜索栏
                    SearchBox(
                      hintText: 'Search Creation',
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      canFocus: true,
                      showClearButton: true,
                      onClear: _cleanQuery,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 清除搜索按钮
                  InkWell(
                    onTap: _closeSearch,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF2A4EFF),
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            // 内容区域
            Expanded(
              child: Stack(
                children: [
                  _hasSearched ? _buildSearchResults() : _buildSearchHistory(),
                  // 没有权限时的提示按钮
                  if (!_canTapSearchItem && _hasSearched && _searchResults.isNotEmpty)
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        onPressed: () => showSubscribeDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFDE69),
                          foregroundColor: const Color(0xFF502D19),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Color(0xFF502D19),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.asset(
                                  'assets/images/crown_mini.png', //皇冠
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Unlock Search Result',
                                style: TextStyle(
                                  fontSize: 20,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
    );
    // return Container();
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
      // onRefresh: _onRefresh,
      onLoadMore: _onLoadMore,
      hasMoreData: _hasMoreData,
      isLoadingMore: _isLoadingMore,
      enableRefresh: false,
      onItemTap: _onSearchItemTap,
    );
  }
}
