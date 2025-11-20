import 'package:flutter/material.dart';

/// 锁屏按钮
class LockButton extends StatelessWidget {
  final bool isLocked;
  final VoidCallback onToggle;

  const LockButton({
    super.key,
    required this.isLocked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLocked ? Colors.orange : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(
        isLocked ? Icons.lock : Icons.lock_open,
        color: isLocked ? Colors.orange : Colors.white,
        size: 24,
      ),
    );
  }
}
