import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/playback_history.dart';
import '../services/history_service.dart';

class SearchHistoryWidget extends StatefulWidget {
  final Function(List<PlaybackHistory>) onResultsChanged;
  final VoidCallback? onClearSearch;

  const SearchHistoryWidget({
    super.key,
    required this.onResultsChanged,
    this.onClearSearch,
  });

  @override
  State<SearchHistoryWidget> createState() => _SearchHistoryWidgetState();
}

class _SearchHistoryWidgetState extends State<SearchHistoryWidget> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await HistoryService.searchHistories(query);
      if (mounted) {
        widget.onResultsChanged(results);
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onClearSearch?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索框
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索视频名称...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            inputFormatters: [
              LengthLimitingTextInputFormatter(100),
            ],
          ),

          if (_isSearching) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],

          // 搜索提示
          if (_searchController.text.isNotEmpty && !_isSearching) ...[
            const SizedBox(height: 16),
            const Text(
              '搜索提示',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildSuggestionChip('mp4'),
                _buildSuggestionChip('avi'),
                _buildSuggestionChip('mkv'),
                _buildSuggestionChip('电影'),
                _buildSuggestionChip('视频'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return ActionChip(
      label: Text(suggestion),
      onPressed: () {
        _searchController.text = suggestion;
        _performSearch(suggestion);
      },
      backgroundColor: Colors.blue[50],
      labelStyle: TextStyle(
        color: Colors.blue[700],
        fontSize: 12,
      ),
    );
  }
}

class FilterOptionsWidget extends StatefulWidget {
  final Function(List<PlaybackHistory>) onFilterChanged;

  const FilterOptionsWidget({
    super.key,
    required this.onFilterChanged,
  });

  @override
  State<FilterOptionsWidget> createState() => _FilterOptionsWidgetState();
}

class _FilterOptionsWidgetState extends State<FilterOptionsWidget> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '筛选条件',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip('all', '全部'),
              _buildFilterChip('incomplete', '未看完'),
              _buildFilterChip('completed', '已完成'),
              _buildFilterChip('recent', '最近观看'),
              _buildFilterChip('today', '今天'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
          _applyFilter(value);
        }
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[700] : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Future<void> _applyFilter(String filter) async {
    final results = await HistoryService.filterByStatus(filter);
    widget.onFilterChanged(results);
  }
}
