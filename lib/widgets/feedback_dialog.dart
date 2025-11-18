import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 用户反馈对话框
/// 收集用户反馈和问题报告
class FeedbackDialog extends StatefulWidget {
  final String? preFilledIssue;
  final String? videoPath;

  const FeedbackDialog({
    super.key,
    this.preFilledIssue,
    this.videoPath,
  });

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _issueController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  FeedbackType _selectedType = FeedbackType.bug;
  bool _includeSystemInfo = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preFilledIssue != null) {
      _issueController.text = widget.preFilledIssue!;
    }
  }

  @override
  void dispose() {
    _issueController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.feedback,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '用户反馈',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 表单内容
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 反馈类型
                      Text(
                        '反馈类型',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: FeedbackType.values.map((type) {
                          final isSelected = _selectedType == type;
                          return FilterChip(
                            label: Text(_getFeedbackTypeLabel(type)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedType = type;
                                });
                              }
                            },
                            backgroundColor: Colors.grey.withOpacity(0.1),
                            selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            checkmarkColor: Theme.of(context).colorScheme.primary,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // 问题标题
                      TextFormField(
                        controller: _issueController,
                        decoration: const InputDecoration(
                          labelText: '问题描述',
                          hintText: '请简要描述遇到的问题',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.error_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入问题描述';
                          }
                          if (value.trim().length < 5) {
                            return '问题描述至少需要5个字符';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 详细描述
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: '详细描述',
                          hintText: '请详细描述问题的具体情况、发生频率等',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入详细描述';
                          }
                          if (value.trim().length < 10) {
                            return '详细描述至少需要10个字符';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 联系邮箱（可选）
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: '联系邮箱（可选）',
                          hintText: '用于后续跟进问题',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                            if (!emailRegex.hasMatch(value)) {
                              return '请输入有效的邮箱地址';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // 选项
                      CheckboxListTile(
                        title: const Text('包含系统信息'),
                        subtitle: const Text('包含设备信息、系统版本等技术细节'),
                        value: _includeSystemInfo,
                        onChanged: (value) {
                          setState(() {
                            _includeSystemInfo = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (widget.videoPath != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 8),
                          child: Text(
                            '相关视频: ${widget.videoPath}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('提交反馈'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 构建反馈内容
      final feedback = {
        'type': _selectedType.toString(),
        'title': _issueController.text.trim(),
        'description': _descriptionController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'videoPath': widget.videoPath,
        'includeSystemInfo': _includeSystemInfo,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 这里可以集成实际的反馈系统
      // 例如：发送到服务器、创建GitHub issue、发送邮件等
      await _sendFeedback(feedback);

      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessMessage();
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _sendFeedback(Map<String, dynamic> feedback) async {
    // 模拟发送反馈
    await Future.delayed(const Duration(seconds: 2));

    // 在实际应用中，这里应该是：
    // 1. 发送到后端API
    // 2. 创建GitHub issue
    // 3. 发送邮件
    // 4. 保存到本地数据库等

    print('用户反馈: ${feedback.toString()}');
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('反馈提交成功，感谢您的宝贵意见！'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '查看帮助',
          onPressed: () => _openHelp(),
        ),
      ),
    );
  }

  void _showErrorMessage(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('提交失败: $error'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openHelp() async {
    final url = Uri.parse('https://github.com/anthropics/claude-code/wiki');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  String _getFeedbackTypeLabel(FeedbackType type) {
    switch (type) {
      case FeedbackType.bug:
        return 'Bug报告';
      case FeedbackType.feature:
        return '功能建议';
      case FeedbackType.improvement:
        return '改进建议';
      case FeedbackType.question:
        return '使用问题';
      case FeedbackType.other:
        return '其他';
    }
  }

  /// 显示反馈对话框的静态方法
  static Future<void> show({
    required BuildContext context,
    String? preFilledIssue,
    String? videoPath,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FeedbackDialog(
          preFilledIssue: preFilledIssue,
          videoPath: videoPath,
        );
      },
    );
  }
}

/// 反馈类型枚举
enum FeedbackType {
  bug,
  feature,
  improvement,
  question,
  other,
}