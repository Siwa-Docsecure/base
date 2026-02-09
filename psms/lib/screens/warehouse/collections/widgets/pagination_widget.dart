// pagination_widget.dart
import 'package:flutter/material.dart';

class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final Function(int) onPageChanged;
  final int visiblePageRange;
  final bool showFirstLastButtons;
  final bool showItemsCount;

  const PaginationWidget({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPageChanged,
    this.visiblePageRange = 5,
    this.showFirstLastButtons = true,
    this.showItemsCount = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox();

    final startPage = _calculateStartPage();
    final endPage = _calculateEndPage(startPage);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          if (showItemsCount)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Showing page $currentPage of $totalPages ($totalItems total items)',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showFirstLastButtons && currentPage > 1)
                _buildPageButton('First', 1, isActive: false),
              if (currentPage > 1)
                _buildPageButton('Previous', currentPage - 1, isActive: false),
              ...List.generate(
                endPage - startPage + 1,
                (index) {
                  final page = startPage + index;
                  return _buildPageButton(
                    page.toString(),
                    page,
                    isActive: page == currentPage,
                  );
                },
              ),
              if (currentPage < totalPages)
                _buildPageButton('Next', currentPage + 1, isActive: false),
              if (showFirstLastButtons && currentPage < totalPages)
                _buildPageButton('Last', totalPages, isActive: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton(String text, int page, {required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: () => onPageChanged(page),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? Colors.blue
              : text == 'Previous' || text == 'Next' || text == 'First' || text == 'Last'
                  ? Colors.transparent
                  : Colors.white,
          foregroundColor: isActive
              ? Colors.white
              : text == 'Previous' || text == 'Next' || text == 'First' || text == 'Last'
                  ? Colors.blue
                  : Colors.black,
          elevation: isActive ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: isActive
                ? BorderSide.none
                : const BorderSide(color: Colors.grey),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          minimumSize: const Size(40, 40),
        ),
        child: Text(text),
      ),
    );
  }

  int _calculateStartPage() {
    int startPage = currentPage - visiblePageRange ~/ 2;
    if (startPage < 1) startPage = 1;
    if (startPage + visiblePageRange > totalPages) {
      startPage = totalPages - visiblePageRange + 1;
      if (startPage < 1) startPage = 1;
    }
    return startPage;
  }

  int _calculateEndPage(int startPage) {
    int endPage = startPage + visiblePageRange - 1;
    if (endPage > totalPages) endPage = totalPages;
    return endPage;
  }
}