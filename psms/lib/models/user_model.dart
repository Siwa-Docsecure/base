  import 'dart:convert';

class UserModel {
  final int userId;
  final String username;
  final String email;
  final String role;
  final int? clientId;
  final String? clientName;
  final String? clientCode;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserPermissions permissions;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    this.clientId,
    this.clientName,
    this.clientCode,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.permissions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? json['user_id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      clientId: json['clientId'] ?? json['client_id'],
      clientName: json['clientName'] ?? json['client_name'],
      clientCode: json['clientCode'] ?? json['client_code'],
      isActive: (json['isActive'] ?? json['is_active'] ?? false) as bool,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
      permissions: json['permissions'] != null
          ? UserPermissions.fromJson(json['permissions'])
          : UserPermissions.defaultPermissions(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      'role': role,
      'clientId': clientId,
      'clientName': clientName,
      'clientCode': clientCode,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'permissions': permissions.toJson(),
    };
  }

  String toJsonString() => json.encode(toJson());
  
  factory UserModel.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return UserModel.fromJson(json);
  }
}

class UserPermissions {
  final bool canCreateBoxes;
  final bool canEditBoxes;
  final bool canDeleteBoxes;
  final bool canCreateCollections;
  final bool canCreateRetrievals;
  final bool canCreateDeliveries;
  final bool canViewReports;
  final bool canManageUsers;

  UserPermissions({
    required this.canCreateBoxes,
    required this.canEditBoxes,
    required this.canDeleteBoxes,
    required this.canCreateCollections,
    required this.canCreateRetrievals,
    required this.canCreateDeliveries,
    required this.canViewReports,
    required this.canManageUsers,
  });

  factory UserPermissions.fromJson(Map<String, dynamic> json) {
    return UserPermissions(
      canCreateBoxes: json['canCreateBoxes'] ?? json['can_create_boxes'] ?? false,
      canEditBoxes: json['canEditBoxes'] ?? json['can_edit_boxes'] ?? false,
      canDeleteBoxes: json['canDeleteBoxes'] ?? json['can_delete_boxes'] ?? false,
      canCreateCollections: json['canCreateCollections'] ?? json['can_create_collections'] ?? false,
      canCreateRetrievals: json['canCreateRetrievals'] ?? json['can_create_retrievals'] ?? false,
      canCreateDeliveries: json['canCreateDeliveries'] ?? json['can_create_deliveries'] ?? false,
      canViewReports: json['canViewReports'] ?? json['can_view_reports'] ?? false,
      canManageUsers: json['canManageUsers'] ?? json['can_manage_users'] ?? false,
    );
  }

  static UserPermissions defaultPermissions() {
    return UserPermissions(
      canCreateBoxes: false,
      canEditBoxes: false,
      canDeleteBoxes: false,
      canCreateCollections: false,
      canCreateRetrievals: false,
      canCreateDeliveries: false,
      canViewReports: false,
      canManageUsers: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'canCreateBoxes': canCreateBoxes,
      'canEditBoxes': canEditBoxes,
      'canDeleteBoxes': canDeleteBoxes,
      'canCreateCollections': canCreateCollections,
      'canCreateRetrievals': canCreateRetrievals,
      'canCreateDeliveries': canCreateDeliveries,
      'canViewReports': canViewReports,
      'canManageUsers': canManageUsers,
    };
  }
}

class AuthResponse {
  final String status;
  final String message;
  final AuthData? data;

  AuthResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      status: json['status'] ?? 'error',
      message: json['message'] ?? '',
      data: json['data'] != null ? AuthData.fromJson(json['data']) : null,
    );
  }
}

class AuthData {
  final UserModel? user;
  final String? accessToken;
  final String? refreshToken;

  AuthData({
    this.user,
    this.accessToken,
    this.refreshToken,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
    );
  }
}

class LoginRequest {
  final String username;
  final String password;

  LoginRequest({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

class ChangePasswordRequest {
  final String currentPassword;
  final String newPassword;

  ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
  }
}