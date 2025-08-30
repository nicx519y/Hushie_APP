import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/audio_history.dart';

/// 音频播放历史本地数据库服务
class AudioHistoryDatabase {
  static final AudioHistoryDatabase _instance =
      AudioHistoryDatabase._internal();
  static AudioHistoryDatabase get instance => _instance;

  static Database? _database;
  static const String _tableName = 'audio_history';
  static const String _dbName = 'audio_history.db';
  static const int _dbVersion = 2;

  // 配置项
  static int maxHistoryCount = 50; // 最大存储条数
  static int progressUpdateInterval = 30; // 进度更新间隔（秒）

  AudioHistoryDatabase._internal();

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建表结构
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        artist_avatar TEXT,
        description TEXT,
        audio_url TEXT NOT NULL,
        cover_url TEXT,
        duration_ms INTEGER NOT NULL,
        likes_count INTEGER DEFAULT 0,
        playback_position_ms INTEGER DEFAULT 0,
        last_played_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // 创建索引以提高查询性能
    await db.execute('''
      CREATE INDEX idx_last_played_at ON $_tableName (last_played_at DESC)
    ''');

    print('音频历史数据库表创建成功');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('数据库从版本 $oldVersion 升级到 $newVersion');

    if (oldVersion < 2) {
      // 添加 artist_avatar 字段
      await db.execute('ALTER TABLE $_tableName ADD COLUMN artist_avatar TEXT');
      print('已添加 artist_avatar 字段');
    }
  }

  /// 添加或更新播放历史
  Future<void> addOrUpdateHistory(AudioHistory history) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // 检查是否已存在该音频记录
        final existing = await txn.query(
          _tableName,
          where: 'id = ?',
          whereArgs: [history.id],
        );

        if (existing.isNotEmpty) {
          // 更新现有记录
          await txn.update(
            _tableName,
            history.toMap(),
            where: 'id = ?',
            whereArgs: [history.id],
          );
          print('更新播放历史: ${history.title}');
        } else {
          // 插入新记录前，检查是否超过存储上限
          await _enforceStorageLimit(txn);

          // 插入新记录
          await txn.insert(_tableName, history.toMap());
          print('添加新播放历史: ${history.title}');
        }
      });
    } catch (e) {
      print('添加播放历史失败: $e');
      throw e;
    }
  }

  /// 强制执行存储上限（先进先出）
  Future<void> _enforceStorageLimit(Transaction txn) async {
    final count =
        Sqflite.firstIntValue(
          await txn.rawQuery('SELECT COUNT(*) FROM $_tableName'),
        ) ??
        0;

    if (count >= maxHistoryCount) {
      // 获取最旧的记录数量，需要删除的数量
      final deleteCount = count - maxHistoryCount + 1;

      // 删除最旧的记录
      await txn.rawDelete(
        '''
        DELETE FROM $_tableName 
        WHERE id IN (
          SELECT id FROM $_tableName 
          ORDER BY last_played_at ASC 
          LIMIT ?
        )
      ''',
        [deleteCount],
      );

      print('删除了 $deleteCount 条最旧的播放历史记录');
    }
  }

  /// 更新播放进度
  Future<bool> updatePlaybackProgress(String audioId, Duration position) async {
    final db = await database;

    try {
      final result = await db.update(
        _tableName,
        {
          'playback_position_ms': position.inMilliseconds,
          'last_played_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [audioId],
      );

      return result > 0;
    } catch (e) {
      print('更新播放进度失败: $e');
      return false;
    }
  }

  /// 获取指定音频的播放历史
  Future<AudioHistory?> getHistoryById(String audioId) async {
    final db = await database;

    try {
      final result = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [audioId],
      );

      if (result.isNotEmpty) {
        return AudioHistory.fromMap(result.first);
      }
      return null;
    } catch (e) {
      print('获取播放历史失败: $e');
      return null;
    }
  }

  /// 获取所有播放历史（按最后播放时间倒序）
  Future<List<AudioHistory>> getAllHistory({int? limit}) async {
    final db = await database;

    try {
      final result = await db.query(
        _tableName,
        orderBy: 'last_played_at DESC',
        limit: limit,
      );

      return result.map((map) => AudioHistory.fromMap(map)).toList();
    } catch (e) {
      print('获取播放历史列表失败: $e');
      return [];
    }
  }

  /// 获取最近播放的音频历史
  Future<List<AudioHistory>> getRecentHistory({int limit = 10}) async {
    return getAllHistory(limit: limit);
  }

  /// 删除指定音频的历史记录
  Future<bool> deleteHistory(String audioId) async {
    final db = await database;

    try {
      final result = await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [audioId],
      );

      print('删除播放历史: $audioId');
      return result > 0;
    } catch (e) {
      print('删除播放历史失败: $e');
      return false;
    }
  }

  /// 清空所有播放历史
  Future<bool> clearAllHistory() async {
    final db = await database;

    try {
      await db.delete(_tableName);
      print('已清空所有播放历史');
      return true;
    } catch (e) {
      print('清空播放历史失败: $e');
      return false;
    }
  }

  /// 重建数据库表（用于修复表结构问题）
  Future<void> rebuildDatabase() async {
    try {
      // 关闭当前数据库连接
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // 删除数据库文件
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _dbName);
      await deleteDatabase(path);

      print('已删除旧数据库，将重新创建');

      // 重新初始化数据库
      _database = await _initDatabase();
      print('数据库重建完成');
    } catch (e) {
      print('重建数据库失败: $e');
    }
  }

  /// 获取播放历史统计信息
  Future<Map<String, dynamic>> getHistoryStats() async {
    final db = await database;

    try {
      // 总数量
      final totalCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
          ) ??
          0;

      // 今天播放的数量
      final todayStart = DateTime.now()
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .millisecondsSinceEpoch;

      final todayCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM $_tableName WHERE last_played_at >= ?',
              [todayStart],
            ),
          ) ??
          0;

      // 最近播放时间
      final recentResult = await db.query(
        _tableName,
        columns: ['last_played_at'],
        orderBy: 'last_played_at DESC',
        limit: 1,
      );

      DateTime? lastPlayedAt;
      if (recentResult.isNotEmpty) {
        lastPlayedAt = DateTime.fromMillisecondsSinceEpoch(
          recentResult.first['last_played_at'] as int,
        );
      }

      return {
        'total_count': totalCount,
        'today_count': todayCount,
        'last_played_at': lastPlayedAt,
        'max_capacity': maxHistoryCount,
        'usage_percentage': totalCount / maxHistoryCount,
      };
    } catch (e) {
      print('获取历史统计失败: $e');
      return {
        'total_count': 0,
        'today_count': 0,
        'last_played_at': null,
        'max_capacity': maxHistoryCount,
        'usage_percentage': 0.0,
      };
    }
  }

  /// 搜索播放历史
  Future<List<AudioHistory>> searchHistory(String keyword) async {
    final db = await database;

    try {
      final result = await db.query(
        _tableName,
        where: 'title LIKE ? OR artist LIKE ?',
        whereArgs: ['%$keyword%', '%$keyword%'],
        orderBy: 'last_played_at DESC',
      );

      return result.map((map) => AudioHistory.fromMap(map)).toList();
    } catch (e) {
      print('搜索播放历史失败: $e');
      return [];
    }
  }

  /// 设置最大历史记录数量
  static void setMaxHistoryCount(int count) {
    if (count > 0) {
      maxHistoryCount = count;
      print('设置最大历史记录数量: $count');
    }
  }

  /// 设置进度更新间隔
  static void setProgressUpdateInterval(int seconds) {
    if (seconds > 0) {
      progressUpdateInterval = seconds;
      print('设置进度更新间隔: ${seconds}秒');
    }
  }

  /// 关闭数据库连接
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('音频历史数据库连接已关闭');
    }
  }

  /// 获取数据库文件大小（调试用）
  Future<int> getDatabaseSize() async {
    try {
      // 这里可以通过 File API 获取文件大小
      // 简化实现，返回估算值
      final stats = await getHistoryStats();
      return (stats['total_count'] as int) * 1000; // 估算每条记录1KB
    } catch (e) {
      return 0;
    }
  }

  /// 打印调试信息
  Future<void> printDebugInfo() async {
    try {
      final stats = await getHistoryStats();
      final recentHistory = await getRecentHistory(limit: 5);

      print('=== 音频历史数据库调试信息 ===');
      print('总记录数: ${stats['total_count']}');
      print('今日播放: ${stats['today_count']}');
      print('最大容量: ${stats['max_capacity']}');
      print('使用率: ${(stats['usage_percentage'] * 100).toStringAsFixed(1)}%');

      if (stats['last_played_at'] != null) {
        print('最近播放: ${stats['last_played_at']}');
      }

      print('最近5条记录:');
      for (final history in recentHistory) {
        print('  - ${history.title} (${history.formattedProgress})');
      }
      print('============================');
    } catch (e) {
      print('打印调试信息失败: $e');
    }
  }
}
