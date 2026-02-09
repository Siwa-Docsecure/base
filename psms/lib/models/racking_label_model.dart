// racking_label_model.dart
import 'dart:convert';

class RackingLabelModel {
  final int labelId;
  final String labelCode;
  final String locationDescription;
  final bool isAvailable;
  final int? boxesCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? boxNumbers;
  final String? clientNames;
  final List<dynamic>? boxes;

  RackingLabelModel({
    required this.labelId,
    required this.labelCode,
    required this.locationDescription,
    required this.isAvailable,
    this.boxesCount,
    required this.createdAt,
    this.updatedAt,
    this.boxNumbers,
    this.clientNames,
    this.boxes,
  });

  factory RackingLabelModel.fromJson(Map<String, dynamic> json) {
    // Handle is_available conversion: 1 = true, 0 = false
    final isAvailable = json['is_available'] is bool 
        ? json['is_available'] as bool
        : (json['is_available'] as int?) == 1;

    // Handle nullable boxesCount
    final boxesCount = json['boxes_count'] is int
        ? json['boxes_count'] as int?
        : (json['boxes_count'] is String
            ? int.tryParse(json['boxes_count'].toString())
            : null);

    return RackingLabelModel(
      labelId: json['label_id'] as int,
      labelCode: json['label_code'] as String,
      locationDescription: json['location_description'] as String,
      isAvailable: isAvailable,
      boxesCount: boxesCount,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      boxNumbers: json['box_numbers'] as String?,
      clientNames: json['client_names'] as String?,
      boxes: json['boxes'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label_id': labelId,
      'label_code': labelCode,
      'location_description': locationDescription,
      'is_available': isAvailable ? 1 : 0, // Convert bool to int for API
      'boxes_count': boxesCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'box_numbers': boxNumbers,
      'client_names': clientNames,
      'boxes': boxes,
    };
  }

  @override
  String toString() {
    return json.encode(toJson());
  }
}