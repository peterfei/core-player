import 'package:flutter/material.dart';
import '../../models/update/update_models.dart';

/// 更新通知弹窗
class UpdateNotificationDialog extends StatelessWidget {
  final List<UpdateInfo> updates;
  final VoidCallback onUpdateNow;
  final VoidCallback onUpdateLater;

  const UpdateNotificationDialog({
    Key? key,
    required this.updates,
    required this.onUpdateNow,
    required this.onUpdateLater,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasMandatory = updates.any((u) => u.isMandatory);
    final hasSecurity = updates.any((u) => u.isSecurityUpdate);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.system_update,
            color: hasSecurity ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 12),
          const Text('发现新版本'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发现 ${updates.length} 个可用更新：',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: updates.length,
                itemBuilder: (context, index) {
                  final update = updates[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.extension),
                    title: Text('${update.pluginId} v${update.latestVersion}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(update.changelog, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (update.isSecurityUpdate)
                          const Text(
                            '安全更新',
                            style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    trailing: Text(update.formattedSize),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!hasMandatory)
          TextButton(
            onPressed: onUpdateLater,
            child: const Text('稍后'),
          ),
        ElevatedButton(
          onPressed: onUpdateNow,
          style: ElevatedButton.styleFrom(
            backgroundColor: hasSecurity ? Colors.red : Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('立即更新'),
        ),
      ],
    );
  }
}
