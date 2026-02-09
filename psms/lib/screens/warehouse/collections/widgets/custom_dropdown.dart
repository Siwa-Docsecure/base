// custom_dropdown.dart
import 'package:flutter/material.dart';

class CustomDropdown extends StatelessWidget {
  final String label;
  final String? hint;
  final List<DropdownMenuItem<dynamic>> items;
  final dynamic value;
  final ValueChanged<dynamic>? onChanged;
  final String? Function(dynamic)? validator;
  final bool isExpanded;
  final bool isDense;
  final EdgeInsetsGeometry? contentPadding;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final String? errorText;

  const CustomDropdown({
    Key? key,
    required this.label,
    this.hint,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.isExpanded = true,
    this.isDense = false,
    this.contentPadding,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.errorText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
        ],
        DropdownButtonFormField<dynamic>(
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: !enabled,
            fillColor: !enabled ? Colors.grey.shade100 : null,
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: errorText,
          ),
          isExpanded: isExpanded,
          isDense: isDense,
          icon: const Icon(Icons.arrow_drop_down),
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
          validator: validator,
          dropdownColor: Colors.white,
          menuMaxHeight: 300,
          hint: hint != null
              ? Text(
                  hint!,
                  style: const TextStyle(color: Colors.grey),
                )
              : null,
        ),
      ],
    );
  }
}