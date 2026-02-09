// widgets/search_bar.dart
import 'dart:async';

import 'package:flutter/material.dart';

class SearchBar extends StatefulWidget {
  final String hintText;
  final Function(String) onSearch;
  final Duration debounceDuration;

  const SearchBar({
    super.key,
    this.hintText = 'Search...',
    required this.onSearch,
    this.debounceDuration = const Duration(milliseconds: 500),
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
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  widget.onSearch('');
                },
              )
            : null,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onChanged: _onSearchChanged,
    );
  }
}