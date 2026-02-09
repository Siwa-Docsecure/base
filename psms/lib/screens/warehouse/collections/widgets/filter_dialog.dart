// filter_dialog.dart
import 'package:flutter/material.dart';

enum FilterType { text, dropdown, date, number, checkbox }

class FilterItem {
  final FilterType type;
  final String label;
  final String key;
  final List<DropdownOption>? options;
  final dynamic initialValue;
  final String? hint;
  final bool required;

  FilterItem({
    required this.type,
    required this.label,
    required this.key,
    this.options,
    this.initialValue,
    this.hint,
    this.required = false,
  });
}

class DropdownOption {
  final dynamic value;
  final String label;

  DropdownOption({
    required this.value,
    required this.label,
  });
}

class FilterDialog extends StatefulWidget {
  final String title;
  final List<FilterItem> filters;
  final Function(Map<String, dynamic>) onApply;
  final Function()? onClear;

  const FilterDialog({
    Key? key,
    required this.title,
    required this.filters,
    required this.onApply,
    this.onClear,
  }) : super(key: key);

  @override
  _FilterDialogState createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late Map<String, dynamic> _filterValues;

  @override
  void initState() {
    super.initState();
    _filterValues = {};
    for (var filter in widget.filters) {
      if (filter.initialValue != null) {
        _filterValues[filter.key] = filter.initialValue;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.filters.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildFilterWidget(filter),
                );
              }).toList(),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.onClear != null)
          TextButton(
            onPressed: () {
              widget.onClear!();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_filterValues);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildFilterWidget(FilterItem filter) {
    switch (filter.type) {
      case FilterType.text:
        return TextField(
          decoration: InputDecoration(
            labelText: filter.label,
            hintText: filter.hint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            _filterValues[filter.key] = value;
          },
        );
      case FilterType.dropdown:
        return DropdownButtonFormField<dynamic>(
          value: _filterValues[filter.key] ?? filter.initialValue,
          decoration: InputDecoration(
            labelText: filter.label,
            border: const OutlineInputBorder(),
          ),
          items: filter.options!.map((option) {
            return DropdownMenuItem<dynamic>(
              value: option.value,
              child: Text(option.label),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _filterValues[filter.key] = value;
            });
          },
        );
      case FilterType.date:
        return InkWell(
          onTap: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (selectedDate != null) {
              setState(() {
                _filterValues[filter.key] = selectedDate.toIso8601String();
              });
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: filter.label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              _filterValues[filter.key] != null
                  ? _formatDate(_filterValues[filter.key])
                  : filter.hint ?? 'Select date',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
      case FilterType.number:
        return TextField(
          decoration: InputDecoration(
            labelText: filter.label,
            hintText: filter.hint,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            if (value.isNotEmpty) {
              _filterValues[filter.key] = int.tryParse(value);
            }
          },
        );
      case FilterType.checkbox:
        return Row(
          children: [
            Checkbox(
              value: _filterValues[filter.key] ?? false,
              onChanged: (value) {
                setState(() {
                  _filterValues[filter.key] = value;
                });
              },
            ),
            Text(filter.label),
          ],
        );
      default:
        return Container();
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}