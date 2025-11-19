import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/design_tokens/design_tokens.dart';
import '../services/file_source/file_source.dart';
import '../services/file_source/smb_file_source.dart';
import '../services/media_scanner_service.dart';
import '../services/media_library_service.dart';

class AddSharePage extends StatefulWidget {
  const AddSharePage({super.key});

  @override
  State<AddSharePage> createState() => _AddSharePageState();
}

class _AddSharePageState extends State<AddSharePage> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _shareController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _hostController.dispose();
    _shareController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveShare() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create SMB Source
      final source = SMBFileSource(
        id: const Uuid().v4(),
        name: _shareController.text.isEmpty ? _hostController.text : _shareController.text,
        host: _hostController.text,
        username: _usernameController.text.isEmpty ? null : _usernameController.text,
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
      );

      // Test connection
      await source.connect();
      
      // Trigger Scan
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接成功，正在扫描媒体库...')),
        );
      }
      
      final files = await MediaScannerService.instance.scanSource(source, '/');
      
      // Save to Library
      final scannedVideos = files.map((f) => ScannedVideo(
        path: f.path,
        name: f.name,
        sourceId: source.id,
        size: f.size,
        addedAt: DateTime.now(),
      )).toList();
      
      await MediaLibraryService.addVideos(scannedVideos);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描完成，添加了 ${files.length} 个视频')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          '添加 SMB 共享',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: _hostController,
                label: '主机地址 / IP',
                hint: '192.168.1.100',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入主机地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.medium),
              _buildTextField(
                controller: _shareController,
                label: '共享名称',
                hint: 'Movies',
              ),
              const SizedBox(height: AppSpacing.medium),
              _buildTextField(
                controller: _usernameController,
                label: '用户名',
              ),
              const SizedBox(height: AppSpacing.medium),
              _buildTextField(
                controller: _passwordController,
                label: '密码',
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.xLarge),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveShare,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        '添加',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.medium,
            ),
          ),
        ),
      ],
    );
  }
}
