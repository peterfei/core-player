import 'package:flutter/material.dart';
import '../theme/design_tokens/design_tokens.dart';
import '../animations/animations.dart';

/// 现代化侧边栏组件
/// 基于openspec/changes/modernize-ui-design规格
class ModernSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed;
  final List<SidebarItem> items;

  const ModernSidebar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isCollapsed = false,
    this.items = const [
      SidebarItem(
        icon: Icons.video_library_outlined,
        selectedIcon: Icons.video_library,
        label: '媒体库',
      ),
      SidebarItem(
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
        label: '播放历史',
      ),
      SidebarItem(
        icon: Icons.favorite_outline,
        selectedIcon: Icons.favorite,
        label: '收藏',
      ),
      SidebarItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: '设置',
      ),
    ],
  }) : super(key: key);

  @override
  State<ModernSidebar> createState() => _ModernSidebarState();
}

class _ModernSidebarState extends State<ModernSidebar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isCollapsed ? 64 : 240,
      height: double.infinity,
      color: AppColors.surface, // #1C1C1E
      child: Column(
        children: [
          // Logo区域
          _buildLogoArea(),

          // 分隔线
          Divider(
            height: 1,
            color: AppColors.divider,
          ),

          // 导航列表
          Expanded(
            child: _buildNavigationList(),
          ),

          // 分隔线
          Divider(
            height: 1,
            color: AppColors.divider,
          ),

          // 底部设置区域
          _buildBottomArea(),
        ],
      ),
    );
  }

  Widget _buildLogoArea() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        widget.isCollapsed ? AppSpacing.small : AppSpacing.large,
      ),
      child: widget.isCollapsed
          ? _buildCollapsedLogo()
          : _buildExpandedLogo(),
    );
  }

  Widget _buildCollapsedLogo() {
    return Center(
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              Color(0xFF0066CC),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildExpandedLogo() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                Color(0xFF0066CC),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: const Icon(
            Icons.play_arrow,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        Text(
          'CorePlayer',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final isSelected = index == widget.selectedIndex;

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: AppSpacing.micro,
          ),
          child: _buildSidebarItem(item, index, isSelected),
        );
      },
    );
  }

  Widget _buildSidebarItem(SidebarItem item, int index, bool isSelected) {
    return TapListItem(
      onTap: () => widget.onItemSelected(index),
      highlightColor: AppColors.surfaceVariant,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.isCollapsed ? 0 : AppSpacing.medium,
          vertical: AppSpacing.small,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceVariant : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: widget.isCollapsed
            ? _buildCollapsedItem(item, isSelected)
            : _buildExpandedItem(item, isSelected),
      ),
    );
  }

  Widget _buildCollapsedItem(SidebarItem item, bool isSelected) {
    return Center(
      child: Tooltip(
        message: item.label,
        child: Icon(
          isSelected ? item.selectedIcon : item.icon,
          size: 22,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildExpandedItem(SidebarItem item, bool isSelected) {
    return Row(
      children: [
        const SizedBox(width: AppSpacing.small),
        Icon(
          isSelected ? item.selectedIcon : item.icon,
          size: 22,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Text(
            item.label,
            style: AppTextStyles.sidebarNavItem.copyWith(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        // 选中状态指示器
        if (isSelected) ...[
          const SizedBox(width: AppSpacing.small),
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomArea() {
    return Container(
      padding: EdgeInsets.all(
        widget.isCollapsed ? AppSpacing.small : AppSpacing.medium,
      ),
      child: widget.isCollapsed
          ? _buildCollapsedBottomArea()
          : _buildExpandedBottomArea(),
    );
  }

  Widget _buildCollapsedBottomArea() {
    return Column(
      children: [
        _buildCollapsedBottomItem(
          Icons.settings_outlined,
          '设置',
          widget.items.length - 1,
        ),
        const SizedBox(height: AppSpacing.small),
        _buildCollapsedBottomItem(
          Icons.info_outline,
          '关于',
          widget.items.length,
        ),
      ],
    );
  }

  Widget _buildExpandedBottomArea() {
    return Column(
      children: [
        _buildSectionTitle('系统'),
        const SizedBox(height: AppSpacing.small),
        _buildExpandedBottomItem(
          Icons.settings_outlined,
          Icons.settings,
          '设置',
          widget.items.length - 1,
        ),
        const SizedBox(height: AppSpacing.small),
        _buildExpandedBottomItem(
          Icons.info_outline,
          Icons.info,
          '关于',
          widget.items.length,
        ),
        const SizedBox(height: AppSpacing.large),
        _buildExpandedBottomItem(
          Icons.logout_outlined,
          Icons.logout,
          '退出',
          -1,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: AppTextStyles.sidebarSectionTitle,
      ),
    );
  }

  Widget _buildCollapsedBottomItem(IconData icon, String tooltip, int index) {
    return Center(
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(
            icon,
            size: 22,
            color: AppColors.textTertiary,
          ),
          onPressed: () => widget.onItemSelected(index),
          padding: EdgeInsets.zero,
          splashRadius: 16,
        ),
      ),
    );
  }

  Widget _buildExpandedBottomItem(
    IconData icon,
    IconData selectedIcon,
    String label,
    int index,
  ) {
    final isSelected = index == widget.selectedIndex;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.micro),
      child: Material(
        color: isSelected ? AppColors.surfaceVariant : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          onTap: () => widget.onItemSelected(index),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.small,
            ),
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.small),
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.sidebarNavItem.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 侧边栏导航项数据模型
class SidebarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? badgeText;
  final Color? badgeColor;

  const SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeText,
    this.badgeColor,
  });
}

/// 响应式侧边栏包装器
class ResponsiveSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isMobile;
  final bool isTablet;
  final Drawer? drawer;

  const ResponsiveSidebar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isMobile = false,
    this.isTablet = false,
    this.drawer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isMobile && drawer != null) {
      return drawer!;
    }

    return ModernSidebar(
      selectedIndex: selectedIndex,
      onItemSelected: onItemSelected,
      isCollapsed: isTablet,
    );
  }
}

/// 侧边栏控制器
class SidebarController extends ChangeNotifier {
  bool _isCollapsed = false;
  int _selectedIndex = 0;

  bool get isCollapsed => _isCollapsed;
  int get selectedIndex => _selectedIndex;

  void toggleCollapsed() {
    _isCollapsed = !_isCollapsed;
    notifyListeners();
  }

  void setCollapsed(bool collapsed) {
    if (_isCollapsed != collapsed) {
      _isCollapsed = collapsed;
      notifyListeners();
    }
  }

  void setSelectedIndex(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }
}