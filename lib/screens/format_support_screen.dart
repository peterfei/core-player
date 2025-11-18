import 'package:flutter/material.dart';
import 'package:yinghe_player/services/codec_info_service.dart';
import 'package:yinghe_player/models/codec_info.dart';

class FormatSupportScreen extends StatefulWidget {
  const FormatSupportScreen({super.key});

  @override
  State<FormatSupportScreen> createState() => _FormatSupportScreenState();
}

class _FormatSupportScreenState extends State<FormatSupportScreen> {
  List<CodecInfo> _codecInfoList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCodecInfo();
  }

  void _loadCodecInfo() {
    // Data is already loaded at startup, just retrieve it from the singleton.
    final cachedInfo = CodecInfoService.instance.getCachedCodecInfo();
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
                      leading: Icon(codecInfo.isHardwareAccelerated
                          ? Icons.memory
                          : Icons.developer_board),
                      title: Text(codecInfo.displayName),
                      subtitle: Text(codecInfo.fullDescription),
                      trailing: Text(
                        codecInfo.isHardwareAccelerated
                            ? codecInfo.hardwareAccelerationType ?? '硬件'
                            : '软件',
                        style: TextStyle(
                          color: codecInfo.isHardwareAccelerated
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
