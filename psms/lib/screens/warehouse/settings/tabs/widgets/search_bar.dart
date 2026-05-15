// widgets/search_bar.dart
import 'dart:async';
import 'package:flutter/material.dart';

class SearchBar extends StatefulWidget {
  final String hintText;
  final Function(String) onSearch;
  final Duration debounceDuration;
  final Color? iconColor;
  final Color? fillColor;
  final bool filled;

  const SearchBar({
    super.key,
    this.hintText = 'Search...',
    required this.onSearch,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.iconColor,
    this.fillColor,
    this.filled = false,
  });

  @override
  _SearchBarState createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      widget.onSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Icon(Icons.search, color: widget.iconColor ?? Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(Icons.clear, color: widget.iconColor ?? Colors.grey),
          onPressed: () {
            _controller.clear();
            widget.onSearch('');
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: widget.filled,
        fillColor: widget.fillColor ?? Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onChanged: _onSearchChanged,
    );
  }
}