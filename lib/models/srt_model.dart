
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
    
    return SrtModel(paragraphs: paragraphs);
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