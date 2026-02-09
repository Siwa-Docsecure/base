// // storage_location_model.dart

// /// Model representing a storage location in the physical storage system
// class StorageLocationModel {
//   final int labelId;
//   final String labelCode;
//   final String locationDescription;
//   final bool isAvailable;
//   final int? boxesCount;
//   final List<StorageBoxSummary>? boxes;
//   final String? boxNumbers; // Comma-separated box numbers
//   final String? clientNames; // Comma-separated client names
//   final DateTime createdAt;
//   final DateTime? updatedAt;

//   StorageLocationModel({
//     required this.labelId,
//     required this.labelCode,
//     required this.locationDescription,
//     required this.isAvailable,
//     this.boxesCount,
//     this.boxes,
//     this.boxNumbers,
//     this.clientNames,
//     required this.createdAt,
//     this.updatedAt,
//   });

//   /// Create StorageLocationModel from JSON
//   factory StorageLocationModel.fromJson(Map<String, dynamic> json) {
//     return StorageLocationModel(
//       labelId: json['label_id'] ?? 0,
//       labelCode: json['label_code'] ?? '',
//       locationDescription: json['location_description'] ?? '',
//       isAvailable: json['is_available'] == 1 || json['is_available'] == true,
//       boxesCount: json['boxes_count'],
//       boxes: json['boxes'] != null
//           ? (json['boxes'] as List<dynamic>)
//               .map((box) => StorageBoxSummary.fromJson(box))
//               .toList()
//           : null,
//       boxNumbers: json['box_numbers'],
//       clientNames: json['client_names'],
//       createdAt: json['created_at'] != null
//           ? DateTime.parse(json['created_at'])
//           : DateTime.now(),
//       updatedAt: json['updated_at'] != null
//           ? DateTime.parse(json['updated_at'])
//           : null,
//     );
//   }

//   /// Convert StorageLocationModel to JSON
//   Map<String, dynamic> toJson() {
//     return {
//       'label_id': labelId,
//       'label_code': labelCode,
//       'location_description': locationDescription,
//       'is_available': isAvailable,
//       'boxes_count': boxesCount,
//       'boxes': boxes?.map((box) => box.toJson()).toList(),
//       'box_numbers': boxNumbers,
//       'client_names': clientNames,
//       'created_at': createdAt.toIso8601String(),
//       'updated_at': updatedAt?.toIso8601String(),
//     };
//   }

//   /// Copy with method for updating fields
//   StorageLocationModel copyWith({
//     int? labelId,
//     String? labelCode,
//     String? locationDescription,
//     bool? isAvailable,
//     int? boxesCount,
//     List<StorageBoxSummary>? boxes,
//     String? boxNumbers,
//     String? clientNames,
//     DateTime? createdAt,
//     DateTime? updatedAt,
//   }) {
//     return StorageLocationModel(
//       labelId: labelId ?? this.labelId,
//       labelCode: labelCode ?? this.labelCode,
//       locationDescription: locationDescription ?? this.locationDescription,
//       isAvailable: isAvailable ?? this.isAvailable,
//       boxesCount: boxesCount ?? this.boxesCount,
//       boxes: boxes ?? this.boxes,
//       boxNumbers: boxNumbers ?? this.boxNumbers,
//       clientNames: clientNames ?? this.clientNames,
//       createdAt: createdAt ?? this.createdAt,
//       updatedAt: updatedAt ?? this.updatedAt,
//     );
//   }

//   /// Check if location is occupied
//   bool get isOccupied => !isAvailable || (boxesCount != null && boxesCount! > 0);

//   /// Get status text
//   String get statusText {
//     if (isAvailable && (boxesCount == null || boxesCount == 0)) {
//       return 'Available';
//     } else if (boxesCount != null && boxesCount! > 0) {
//       return 'Occupied';
//     } else {
//       return 'Unavailable';
//     }
//   }

//   /// Get formatted display text
//   String get displayText => '$labelCode - $locationDescription';

//   @override
//   String toString() {
//     return 'StorageLocationModel(labelId: $labelId, labelCode: $labelCode, '
//         'locationDescription: $locationDescription, isAvailable: $isAvailable, '
//         'boxesCount: $boxesCount)';
//   }

//   @override
//   bool operator ==(Object other) {
//     if (identical(this, other)) return true;

//     return other is StorageLocationModel && other.labelId == labelId;
//   }

//   @override
//   int get hashCode => labelId.hashCode;
// }

// /// Summary of boxes stored in a location
// class StorageBoxSummary {
//   final int boxId;
//   final String boxNumber;
//   final String? boxDescription;
//   final String status;
//   final String? clientName;
//   final String? clientCode;

//   StorageBoxSummary({
//     required this.boxId,
//     required this.boxNumber,
//     this.boxDescription,
//     required this.status,
//     this.clientName,
//     this.clientCode,
//   });

//   factory StorageBoxSummary.fromJson(Map<String, dynamic> json) {
//     return StorageBoxSummary(
//       boxId: json['box_id'] ?? 0,
//       boxNumber: json['box_number'] ?? '',
//       boxDescription: json['box_description'],
//       status: json['status'] ?? '',
//       clientName: json['client_name'],
//       clientCode: json['client_code'],
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'box_id': boxId,
//       'box_number': boxNumber,
//       'box_description': boxDescription,
//       'status': status,
//       'client_name': clientName,
//       'client_code': clientCode,
//     };
//   }

//   @override
//   String toString() {
//     return 'StorageBoxSummary(boxId: $boxId, boxNumber: $boxNumber, '
//         'status: $status, clientName: $clientName)';
//   }
// }

// /// Request model for creating storage location
// class CreateStorageLocationRequest {
//   final String labelCode;
//   final String locationDescription;
//   final bool isAvailable;

//   CreateStorageLocationRequest({
//     required this.labelCode,
//     required this.locationDescription,
//     this.isAvailable = true,
//   });

//   Map<String, dynamic> toJson() {
//     return {
//       'label_code': labelCode,
//       'location_description': locationDescription,
//       'is_available': isAvailable,
//     };
//   }
// }

// /// Request model for updating storage location
// class UpdateStorageLocationRequest {
//   final String? labelCode;
//   final String? locationDescription;
//   final bool? isAvailable;

//   UpdateStorageLocationRequest({
//     this.labelCode,
//     this.locationDescription,
//     this.isAvailable,
//   });

//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> json = {};
    
//     if (labelCode != null) json['label_code'] = labelCode;
//     if (locationDescription != null) {
//       json['location_description'] = locationDescription;
//     }
//     if (isAvailable != null) json['is_available'] = isAvailable;
    
//     return json;
//   }

//   bool get hasData => 
//       labelCode != null || locationDescription != null || isAvailable != null;
// }