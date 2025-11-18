import 'package:flutter/material.dart';
import 'package:yinghe_player/services/codec_info_service.dart';
import 'package:yinghe_player/models/codec_info.dart';

class FormatSupportScreen extends StatefulWidget {
  const FormatSupportScreen({super.key});

  @override
  State<FormatSupportScreen> createState() => _FormatSupportScreenState();
}

class _FormatSupportScreenState extends State<FormatSupportScreen> {
  final CodecInfoService _codecInfoService = CodecInfoService();
  List<CodecInfo> _codecInfoList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCodecInfo();
  }

  Future<void> _loadCodecInfo() async {
    final cachedInfo = await _codecInfoService.getCachedCodecInfo();
    setState(() {
      _codecInfoList = cachedInfo;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('格式支持'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _codecInfoList.isEmpty
              ? const Center(child: Text('无可用编解码器信息'))
              : ListView.builder(
                  itemCount: _codecInfoList.length,
                  itemBuilder: (context, index) {
                    final codecInfo = _codecInfoList[index];
                    return ListTile(
                      title: Text(codecInfo.displayName),
                      subtitle: Text(codecInfo.fullDescription),
                    );
                  },
                ),
    );
  }
}
