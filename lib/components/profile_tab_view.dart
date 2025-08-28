import 'package:flutter/material.dart';
import '../models/video_item.dart';
import 'video_list.dart';

class ProfileTabView extends StatefulWidget {
  final List<VideoItem> historyVideos;
  final List<VideoItem> likedVideos;

  const ProfileTabView({
    super.key,
    required this.historyVideos,
    required this.likedVideos,
  });

  @override
  State<ProfileTabView> createState() => _ProfileTabViewState();
}

class _ProfileTabViewState extends State<ProfileTabView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 标签栏
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.blue,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'History'),
              Tab(text: 'Like'),
            ],
          ),
        ),
        // 内容区域
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              VideoList(
                videos: widget.historyVideos,
                emptyWidget: const Center(
                  child: Text(
                    '暂无观看历史',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
              VideoList(
                videos: widget.likedVideos,
                emptyWidget: const Center(
                  child: Text(
                    '暂无喜欢内容',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
