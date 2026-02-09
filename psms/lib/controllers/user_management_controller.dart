import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/models/user_model.dart';
import 'package:psms/controllers/auth_controller.dart';

class UserManagementController extends GetxController {
  static UserManagementController get instance => Get.find();

  // Reactive variables
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isProcessing = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalUsers = 0.obs;
  final Rx<UserModel?> selectedUser = Rx<UserModel?>(null);
  final RxMap<String, dynamic> userStats = <String, dynamic>{}.obs;

  // Filter variables
  final RxString searchQuery = ''.obs;
  final RxString selectedRole = ''.obs;
  final RxString selectedStatus = ''.obs;
  final RxString selectedClientId = ''.obs;
  final RxInt itemsPerPage = 20.obs;

  // Form controllers
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController currentPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();



  // Permission controllers - FIXED: Using RxMap for better state management
  final RxMap<String, bool> permissions = <String, bool>{
    'canCreateBoxes': false,
    'canEditBoxes': false,
    'canDeleteBoxes': false,
    'canCreateCollections': false,
    'canCreateRetrievals': false,
    'canCreateDeliveries': false,
    'canViewReports': false,
    'canManageUsers': false,
  }.obs;

  // Helper getters for permissions
  bool get canCreateBoxes => permissions['canCreateBoxes'] ?? false;
  bool get canEditBoxes => permissions['canEditBoxes'] ?? false;
  bool get canDeleteBoxes => permissions['canDeleteBoxes'] ?? false;
  bool get canCreateCollections => permissions['canCreateCollections'] ?? false;
  bool get canCreateRetrievals => permissions['canCreateRetrievals'] ?? false;
  bool get canCreateDeliveries => permissions['canCreateDeliveries'] ?? false;
  bool get canViewReports => permissions['canViewReports'] ?? false;
  bool get canManageUsers => permissions['canManageUsers'] ?? false;

  // Setter methods for permissions
  void setPermission(String key, bool value) {
    permissions[key] = value;
    permissions.refresh(); // Force UI update
  }

  void togglePermission(String key) {
    permissions[key] = !(permissions[key] ?? false);
    permissions.refresh(); // Force UI update
  }

  // Selected role for new user
  final RxString newUserRole = 'staff'.obs;
  final RxString newUserClientId = ''.obs;

  // Bulk operations
  final RxList<int> selectedUserIds = <int>[].obs;
  final RxBool isBulkSelectMode = false.obs;

  @override
  void onClose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  bool get hasManageUsersPermission {
    final authController = Get.find<AuthController>();
    return authController.hasPermission('canManageUsers');
  }

  bool get isAdmin {
    final authController = Get.find<AuthController>();
    return authController.currentUser.value?.role == 'admin';
  }

  void resetForm() {
    usernameController.clear();
    emailController.clear();
    passwordController.clear();
    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
    
    // Reset permissions
    permissions.updateAll((key, value) => false);
    permissions.refresh();
    
    newUserRole.value = 'staff';
    newUserClientId.value = '';
    errorMessage.value = '';
    selectedUser.value = null;
  }

  void selectUser(UserModel user) {
    selectedUser.value = user;
    usernameController.text = user.username;
    emailController.text = user.email;
    
    // Set permissions from user
    permissions['canCreateBoxes'] = user.permissions.canCreateBoxes;
    permissions['canEditBoxes'] = user.permissions.canEditBoxes;
    permissions['canDeleteBoxes'] = user.permissions.canDeleteBoxes;
    permissions['canCreateCollections'] = user.permissions.canCreateCollections;
    permissions['canCreateRetrievals'] = user.permissions.canCreateRetrievals;
    permissions['canCreateDeliveries'] = user.permissions.canCreateDeliveries;
    permissions['canViewReports'] = user.permissions.canViewReports;
    permissions['canManageUsers'] = user.permissions.canManageUsers;
    permissions.refresh();
    
    newUserRole.value = user.role;
    newUserClientId.value = user.clientId?.toString() ?? '';
  }

  void toggleUserSelection(int userId) {
    if (selectedUserIds.contains(userId)) {
      selectedUserIds.remove(userId);
    } else {
      selectedUserIds.add(userId);
    }
  }

  void toggleBulkSelectMode() {
    isBulkSelectMode.value = !isBulkSelectMode.value;
    if (!isBulkSelectMode.value) {
      selectedUserIds.clear();
    }
  }

  void selectAllUsers() {
    if (selectedUserIds.length == users.length) {
      selectedUserIds.clear();
    } else {
      selectedUserIds.value = users.map((user) => user.userId).toList();
    }
  }

  // ============================================
  // API METHODS - USER CRUD
  // ============================================

  Future<Map<String, dynamic>> getAllUsers({bool loadMore = false}) async {
    try {
      if (!loadMore) {
        isLoading.value = true;
        currentPage.value = 1;
      } else {
        isProcessing.value = true;
      }

      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      // Build query parameters
      final queryParams = <String, String>{
        'page': currentPage.value.toString(),
        'limit': itemsPerPage.value.toString(),
      };

      if (searchQuery.value.isNotEmpty) {
        queryParams['search'] = searchQuery.value;
      }
      if (selectedRole.value.isNotEmpty) {
        queryParams['role'] = selectedRole.value;
      }
      if (selectedStatus.value.isNotEmpty) {
        queryParams['isActive'] = selectedStatus.value;
      }
      if (selectedClientId.value.isNotEmpty) {
        queryParams['clientId'] = selectedClientId.value;
      }

      final queryString = Uri(queryParameters: queryParams).query;
      final url = '${ApiConstants.baseUrl}${ApiConstants.users}?$queryString';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          final data = responseData['data'];
          final pagination = data['pagination'];

          final List<UserModel> userList = (data['users'] as List)
              .map((userJson) => UserModel.fromJson(userJson))
              .toList();

          if (loadMore) {
            users.addAll(userList);
          } else {
            users.value = userList;
          }

          currentPage.value = pagination['page'];
          totalPages.value = pagination['totalPages'];
          totalUsers.value = pagination['total'];

          return {'success': true, 'message': 'Users loaded successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await getAllUsers(loadMore: loadMore);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired. Please login again.'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to load users';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to load users'};
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      return {'success': false, 'message': 'Connection error: $e'};
    } finally {
      isLoading.value = false;
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> getUserStats() async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userStats}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          userStats.value = responseData['data'];
          return {'success': true, 'data': responseData['data']};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await getUserStats();
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to get stats';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to get stats'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> getUsersByRole(String role) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userByRole(role)}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          final data = responseData['data'];
          final List<UserModel> userList = (data['users'] as List)
              .map((userJson) => UserModel.fromJson(userJson))
              .toList();

          users.value = userList;
          return {'success': true, 'count': data['count'], 'users': userList};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await getUsersByRole(role);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to get users';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to get users'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> getUsersByClient(int clientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.usersByClient(clientId.toString())}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          final data = responseData['data'];
          final List<UserModel> userList = (data['users'] as List)
              .map((userJson) => UserModel.fromJson(userJson))
              .toList();

          users.value = userList;
          return {'success': true, 'count': data['userCount'], 'users': userList};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await getUsersByClient(clientId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to get users';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to get users'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> getUserById(int userId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userById(userId.toString())}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          final user = UserModel.fromJson(responseData['data']);
          selectedUser.value = user;
          return {'success': true, 'user': user};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await getUserById(userId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to get user';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to get user'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> createUser() async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      // Validate inputs
      if (usernameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.isEmpty) {
        errorMessage.value = 'Please fill all required fields';
        return {'success': false, 'message': 'Please fill all required fields'};
      }

      if (passwordController.text.length < 6) {
        errorMessage.value = 'Password must be at least 6 characters';
        return {'success': false, 'message': 'Password must be at least 6 characters'};
      }

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final body = {
        'username': usernameController.text,
        'email': emailController.text,
        'password': passwordController.text,
        'role': newUserRole.value,
        if (newUserRole.value == 'client' && newUserClientId.value.isNotEmpty)
          'clientId': int.parse(newUserClientId.value),
        'permissions': {
          'canCreateBoxes': canCreateBoxes,
          'canEditBoxes': canEditBoxes,
          'canDeleteBoxes': canDeleteBoxes,
          'canCreateCollections': canCreateCollections,
          'canCreateRetrievals': canCreateRetrievals,
          'canCreateDeliveries': canCreateDeliveries,
          'canViewReports': canViewReports,
          'canManageUsers': canManageUsers,
        }
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.users}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          resetForm();
          await getAllUsers();
          Get.back();
          Get.snackbar(
            'Success',
            'User created successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'User created successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await createUser();
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to create user';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to create user'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> updateUser(int userId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      // Validate inputs
      if (usernameController.text.isEmpty || emailController.text.isEmpty) {
        errorMessage.value = 'Please fill all required fields';
        return {'success': false, 'message': 'Please fill all required fields'};
      }

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final body = {
        'username': usernameController.text,
        'email': emailController.text,
      };

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userById(userId.toString())}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          resetForm();
          await getAllUsers();
          Get.back();
          Get.snackbar(
            'Success',
            'User updated successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'User updated successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await updateUser(userId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to update user';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to update user'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> activateUser(int userId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.activateUser(userId.toString())}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getAllUsers();
          Get.snackbar(
            'Success',
            'User activated successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'User activated successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await activateUser(userId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to activate user';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to activate user'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> deactivateUser(int userId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deactivateUser(userId.toString())}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getAllUsers();
          Get.snackbar(
            'Success',
            'User deactivated successfully',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'User deactivated successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await deactivateUser(userId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to deactivate user';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to deactivate user'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> deleteUser(int userId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      
      // Prevent deleting self
      if (userId == authController.currentUser.value?.userId) {
        errorMessage.value = 'Cannot delete your own account';
        return {'success': false, 'message': 'Cannot delete your own account'};
      }

      final headers = authController.getAuthHeaders();

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userById(userId.toString())}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getAllUsers();
          Get.snackbar(
            'Success',
            'User deleted successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'User deleted successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await deleteUser(userId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to delete user';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to delete user'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> resetPassword(int userId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      // Validate inputs
      if (newPasswordController.text.isEmpty || confirmPasswordController.text.isEmpty) {
        errorMessage.value = 'Please fill all required fields';
        return {'success': false, 'message': 'Please fill all required fields'};
      }

      if (newPasswordController.text.length < 6) {
        errorMessage.value = 'Password must be at least 6 characters';
        return {'success': false, 'message': 'Password must be at least 6 characters'};
      }

      if (newPasswordController.text != confirmPasswordController.text) {
        errorMessage.value = 'Passwords do not match';
        return {'success': false, 'message': 'Passwords do not match'};
      }

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final body = {
        'newPassword': newPasswordController.text,
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.resetPassword(userId.toString())}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          newPasswordController.clear();
          confirmPasswordController.clear();
          Get.back();
          Get.snackbar(
            'Success',
            'Password reset successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'Password reset successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await resetPassword(userId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to reset password';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to reset password'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  // ============================================
  // CLIENT MAPPING METHODS
  // ============================================

  Future<Map<String, dynamic>> assignUserToClient(int userId, int clientId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final body = {
        'clientId': clientId,
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.assignClient(userId.toString())}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getUserById(userId);
          Get.snackbar(
            'Success',
            'User assigned to client successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'User assigned to client successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await assignUserToClient(userId, clientId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to assign client';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to assign client'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> removeUserFromClient(int userId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.removeClient(userId.toString())}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getUserById(userId);
          Get.snackbar(
            'Success',
            'User removed from client successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'User removed from client successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await removeUserFromClient(userId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to remove client';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to remove client'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> changeUserClient(int userId, int clientId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final body = {
        'clientId': clientId,
      };

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.changeClient(userId.toString())}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getUserById(userId);
          Get.snackbar(
            'Success',
            'User client changed successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'User client changed successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await changeUserClient(userId, clientId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to change client';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to change client'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  // ============================================
  // PERMISSION MANAGEMENT METHODS
  // ============================================

  Future<Map<String, dynamic>> getUserPermissions(int userId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userPermissions(userId.toString())}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          final perms = responseData['data']['permissions'];
          
          // Update permissions map
          permissions['canCreateBoxes'] = perms['canCreateBoxes'] ?? false;
          permissions['canEditBoxes'] = perms['canEditBoxes'] ?? false;
          permissions['canDeleteBoxes'] = perms['canDeleteBoxes'] ?? false;
          permissions['canCreateCollections'] = perms['canCreateCollections'] ?? false;
          permissions['canCreateRetrievals'] = perms['canCreateRetrievals'] ?? false;
          permissions['canCreateDeliveries'] = perms['canCreateDeliveries'] ?? false;
          permissions['canViewReports'] = perms['canViewReports'] ?? false;
          permissions['canManageUsers'] = perms['canManageUsers'] ?? false;
          permissions.refresh();
          
          return {'success': true, 'permissions': perms};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await getUserPermissions(userId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to get permissions';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to get permissions'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> updateUserPermissions(int userId) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final body = {
        'permissions': {
          'canCreateBoxes': canCreateBoxes,
          'canEditBoxes': canEditBoxes,
          'canDeleteBoxes': canDeleteBoxes,
          'canCreateCollections': canCreateCollections,
          'canCreateRetrievals': canCreateRetrievals,
          'canCreateDeliveries': canCreateDeliveries,
          'canViewReports': canViewReports,
          'canManageUsers': canManageUsers,
        }
      };

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userPermissions(userId.toString())}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Permissions updated successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'Permissions updated successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await updateUserPermissions(userId);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to update permissions';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to update permissions'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> grantPermission(int userId, String permission) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final body = {
        'permission': permission,
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.grantPermission(userId.toString())}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getUserPermissions(userId);
          Get.snackbar(
            'Success',
            'Permission granted successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'Permission granted successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await grantPermission(userId, permission);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to grant permission';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to grant permission'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> revokePermission(int userId, String permission) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final body = {
        'permission': permission,
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.revokePermission(userId.toString())}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getUserPermissions(userId);
          Get.snackbar(
            'Success',
            'Permission revoked successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'Permission revoked successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await revokePermission(userId, permission);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to revoke permission';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to revoke permission'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  // ============================================
  // BULK OPERATIONS METHODS
  // ============================================

  Future<Map<String, dynamic>> bulkCreateUsers(List<Map<String, dynamic>> usersList) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      final headers = authController.getAuthHeaders();

      final body = {
        'users': usersList,
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bulkCreateUsers}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getAllUsers();
          Get.snackbar(
            'Success',
            'Bulk user creation completed',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'data': responseData['data']};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await bulkCreateUsers(usersList);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to bulk create users';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to bulk create users'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> bulkActivateUsers(List<int> userIds) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      
      // Prevent deactivating self
      if (userIds.contains(authController.currentUser.value?.userId)) {
        errorMessage.value = 'Cannot deactivate your own account';
        return {'success': false, 'message': 'Cannot deactivate your own account'};
      }

      final headers = authController.getAuthHeaders();

      final body = {
        'userIds': userIds,
      };

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bulkActivateUsers}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getAllUsers();
          selectedUserIds.clear();
          Get.snackbar(
            'Success',
            'Users activated successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'Users activated successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await bulkActivateUsers(userIds);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to activate users';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to activate users'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  Future<Map<String, dynamic>> bulkDeactivateUsers(List<int> userIds) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      
      // Prevent deactivating self
      if (userIds.contains(authController.currentUser.value?.userId)) {
        errorMessage.value = 'Cannot deactivate your own account';
        return {'success': false, 'message': 'Cannot deactivate your own account'};
      }

      final headers = authController.getAuthHeaders();

      final body = {
        'userIds': userIds,
      };

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bulkDeactivateUsers}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getAllUsers();
          selectedUserIds.clear();
          Get.snackbar(
            'Success',
            'Users deactivated successfully',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'Users deactivated successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await bulkDeactivateUsers(userIds);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to deactivate users';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to deactivate users'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  // ============================================
  // ROLE MANAGEMENT METHODS
  // ============================================

  Future<Map<String, dynamic>> changeUserRole(int userId, String newRole) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final authController = Get.find<AuthController>();
      
      // Prevent changing own role
      if (userId == authController.currentUser.value?.userId) {
        errorMessage.value = 'Cannot change your own role';
        return {'success': false, 'message': 'Cannot change your own role'};
      }

      final headers = authController.getAuthHeaders();

      final body = {
        'role': newRole,
      };

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.changeUserRole(userId.toString())}'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          await getUserById(userId);
          Get.snackbar(
            'Success',
            'User role changed successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          return {'success': true, 'message': 'User role changed successfully'};
        } else {
          errorMessage.value = responseData['message'];
          return {'success': false, 'message': responseData['message']};
        }
      } else if (response.statusCode == 401) {
        final refreshed = await authController.refreshAccessToken();
        if (refreshed) {
          return await changeUserRole(userId, newRole);
        } else {
          await authController.clearSession();
          Get.offAllNamed('/login');
          return {'success': false, 'message': 'Session expired'};
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Failed to change role';
        return {'success': false, 'message': errorResponse['message'] ?? 'Failed to change role'};
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isProcessing.value = false;
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  void applyFilters() {
    currentPage.value = 1;
    getAllUsers();
  }

  void clearFilters() {
    searchQuery.value = '';
    selectedRole.value = '';
    selectedStatus.value = '';
    selectedClientId.value = '';
    currentPage.value = 1;
    getAllUsers();
  }

  void loadMore() {
    if (currentPage.value < totalPages.value) {
      currentPage.value++;
      getAllUsers(loadMore: true);
    }
  }

  String getRoleBadge(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'staff':
        return 'Staff';
      case 'client':
        return 'Client';
      default:
        return role;
    }
  }

  Color getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'staff':
        return Colors.blue;
      case 'client':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.security;
      case 'staff':
        return Icons.people;
      case 'client':
        return Icons.business;
      default:
        return Icons.person;
    }
  }

  // Set default permissions based on role
  void setDefaultPermissionsForRole(String role) {
    switch (role) {
      case 'admin':
        permissions.updateAll((key, value) => true);
        break;
      case 'staff':
        permissions['canCreateBoxes'] = true;
        permissions['canEditBoxes'] = true;
        permissions['canCreateCollections'] = true;
        permissions['canCreateRetrievals'] = true;
        permissions['canCreateDeliveries'] = true;
        permissions['canViewReports'] = true;
        permissions['canDeleteBoxes'] = false;
        permissions['canManageUsers'] = false;
        break;
      case 'client':
        permissions.updateAll((key, value) => false);
        permissions['canViewReports'] = true;
        break;
      default:
        permissions.updateAll((key, value) => false);
    }
    permissions.refresh();
  }
}