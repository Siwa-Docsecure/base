// Client Model
class ClientModel {
  final int clientId;
  final String clientName;
  final String clientCode;
  final String contactPerson;
  final String? email;
  final String? phone;
  final String? address;
  final bool isActive;
  final int? userCount;
  final int? boxCount;
  final int? storedBoxes;
  final int? retrievedBoxes;
  final int? destroyedBoxes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClientModel({
    required this.clientId,
    required this.clientName,
    required this.clientCode,
    required this.contactPerson,
    this.email,
    this.phone,
    this.address,
    required this.isActive,
    this.userCount,
    this.boxCount,
    this.storedBoxes,
    this.retrievedBoxes,
    this.destroyedBoxes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      clientId: json['clientId'],
      clientName: json['clientName'],
      clientCode: json['clientCode'],
      contactPerson: json['contactPerson'],
      email: json['email'],
      phone: json['phone'],
      address: json['address'],
      isActive: json['isActive'] ?? true,
      userCount: json['userCount'],
      boxCount: json['boxCount'],
      storedBoxes: json['storedBoxes'],
      retrievedBoxes: json['retrievedBoxes'],
      destroyedBoxes: json['destroyedBoxes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientName': clientName,
      'contactPerson': contactPerson,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
    };
  }
}