import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 临时脚本：清除 excluded_paths 的错误数据
/// 运行后可以删除此文件
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  // 检查当前存储的数据类型
  final stored = prefs.get('excluded_paths');
  print('当前 excluded_paths 类型: ${stored.runtimeType}');
  print('当前 excluded_paths 值: $stored');
  
  // 清除数据
  await prefs.remove('excluded_paths');
  print('✅ 已清除 excluded_paths');
  
  // 重新设置为空列表
  await prefs.setStringList('excluded_paths', []);
  print('✅ 已重新初始化为空列表');
}
