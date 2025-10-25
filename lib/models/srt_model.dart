
enum SrtParagraphType {
  title,
  text,
}

class SrtParagraphModel {
  int index;
  String startTime;
  String text;
  SrtParagraphType type;

  SrtParagraphModel({
    required this.index,
    required this.startTime,
    required this.text,
    required this.type,
  });
}

class SrtModel {
  List<SrtParagraphModel> paragraphs;

  SrtModel({
    required this.paragraphs,
  });

  /// 从字符串解析 SRT 模型
  /// 格式：
  /// 20:00:00
  /// `<title>` xxxxxxxxxxxxxxxxxxxxxxxxxx
  /// 20:10:00
  /// `<text>` xxxxxxxxxxxxxxxxxxxxxxxxxxxx
  static SrtModel fromString(String content) {
     final paragraphs = <SrtParagraphModel>[];
     // 统一换行并合并多个连续换行为一个
     final normalized = content
        .replaceAll(RegExp(r'\<title\d+\>'), '<title>')
         .replaceAll(RegExp(r'\r\n?'), '\n')
         .replaceAll(RegExp(r'\n+'), '\n')
         .trim();
     final lines = normalized.split('\n');
     
     int index = 0;
     String? currentTime;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // 跳过空行
      if (line.isEmpty) continue;
      
      // 检查是否为时间格式 (HH:MM:SS)
      if (RegExp(r'^\d{1,2}:\d{2}:\d{2}$').hasMatch(line)) {
        currentTime = line;
      } else if (currentTime != null) {
        // 解析内容行
        SrtParagraphType type;
        String text;
        
        if (line.startsWith('<title>')) {
          type = SrtParagraphType.title;
          text = line.substring(7).trim(); // 移除 "<title> "
        } else if (line.startsWith('<text>')) {
          type = SrtParagraphType.text;
          text = line.substring(6).trim(); // 移除 "<text> "
        } else {
          // 默认为文本类型
          type = SrtParagraphType.text;
          text = line;
        }
        
        paragraphs.add(SrtParagraphModel(
          index: index++,
          startTime: currentTime,
          text: text,
          type: type,
        ));
        
        currentTime = null; // 重置时间，等待下一个时间标记
      }
    }
    
    // 根据时间对段落进行排序
    paragraphs.sort((a, b) {
      final timeA = _parseTimeToSeconds(a.startTime);
      final timeB = _parseTimeToSeconds(b.startTime);
      return timeA.compareTo(timeB);
    });
    
    // 重新分配索引，确保索引与排序后的顺序一致
    for (int i = 0; i < paragraphs.length; i++) {
      paragraphs[i].index = i;
    }
    
    return SrtModel(paragraphs: paragraphs);
  }
  
  /// 将时间字符串转换为秒数，用于排序比较
  static int _parseTimeToSeconds(String timeStr) {
    try {
      final parts = timeStr.split(':');
      int h = 0, m = 0, s = 0;
      if (parts.length == 3) {
        h = int.tryParse(parts[0]) ?? 0;
        m = int.tryParse(parts[1]) ?? 0;
        s = int.tryParse(parts[2]) ?? 0;
      } else if (parts.length == 2) {
        m = int.tryParse(parts[0]) ?? 0;
        s = int.tryParse(parts[1]) ?? 0;
      } else if (parts.length == 1) {
        s = int.tryParse(parts[0]) ?? 0;
      }
      return h * 3600 + m * 60 + s;
    } catch (_) {
      return 0;
    }
  }

  /// 转换为字符串格式
  @override
  String toString() {
    final buffer = StringBuffer();
    
    for (final paragraph in paragraphs) {
      // 添加时间
      buffer.writeln(paragraph.startTime);
      
      // 添加类型标记和文本
      switch (paragraph.type) {
        case SrtParagraphType.title:
          buffer.writeln('<title> ${paragraph.text}');
          break;
        case SrtParagraphType.text:
          buffer.writeln('<text> ${paragraph.text}');
          break;
      }
    }
    
    return buffer.toString().trim();
  }
}