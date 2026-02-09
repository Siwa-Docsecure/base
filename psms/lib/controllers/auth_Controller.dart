import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:psms/constants/api_constants.dart';
import 'package:psms/models/user_model.dart';
import 'package:psms/services/storage_service.dart';

class AuthController extends GetxController {
  static AuthController get instance => Get.find();

  // Reactive variables
  final RxBool isLoading = false.obs;
  final RxBool isAuthenticated = false.obs;
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxString accessToken = ''.obs;
  final RxString refreshToken = ''.obs;

  // Error messages
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    checkAuthentication();
  }

  // Check if user is authenticated from storage
  void checkAuthentication() {
    final storedToken = StorageService.getAccessToken();
    final storedUser = StorageService.getUser();
    final isLoggedIn = StorageService.isLoggedIn();

    if (isLoggedIn && storedToken != null && storedUser != null) {
      accessToken.value = storedToken;
      currentUser.value = UserModel.fromJson(storedUser);
      isAuthenticated.value = true;
    }
  }

  // Login function
  Future<bool> login(String username, String password) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(LoginRequest(
          username: username,
          password: password,
        ).toJson()),
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(json.decode(response.body));
        
        if (authResponse.status == 'success' && authResponse.data != null) {
          // Save tokens
          if (authResponse.data!.accessToken != null) {
            accessToken.value = authResponse.data!.accessToken!;
            await StorageService.saveAccessToken(authResponse.data!.accessToken!);
          }
          
          if (authResponse.data!.refreshToken != null) {
            refreshToken.value = authResponse.data!.refreshToken!;
            await StorageService.saveRefreshToken(authResponse.data!.refreshToken!);
          }
          
          // Save user data
          if (authResponse.data!.user != null) {
            currentUser.value = authResponse.data!.user;
            await StorageService.saveUser(authResponse.data!.user!.toJson());
            await StorageService.saveUserRole(authResponse.data!.user!.role);
          }
          
          // Set login status
          await StorageService.setLoggedIn(true);
          isAuthenticated.value = true;
          
          Get.snackbar(
            'Success',
            'Login successful',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          
          isLoading.value = false;
          return true;
        } else {
          errorMessage.value = authResponse.message;
          Get.snackbar(
            'Error',
            authResponse.message,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        errorMessage.value = errorResponse['message'] ?? 'Login failed';
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Login failed',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      errorMessage.value = 'Connection error: $e';
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // Logout function
  Future<bool> logout() async {
    try {
      isLoading.value = true;
      
      final token = StorageService.getAccessToken();
      if (token != null) {
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          await clearSession();
          Get.offAllNamed('/login');
          Get.snackbar(
            'Success',
            'Logged out successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          isLoading.value = false;
          return true;
        }
      }
      
      // If API call fails, still clear local session
      await clearSession();
      Get.offAllNamed('/login');
      return true;
    } catch (e) {
      errorMessage.value = 'Logout error: $e';
      // Still clear local session even if API fails
      await clearSession();
      Get.offAllNamed('/login');
      return true;
    } finally {
      isLoading.value = false;
    }
  }

  // Clear session data
  Future<void> clearSession() async {
    await StorageService.clearAll();
    accessToken.value = '';
    refreshToken.value = '';
    currentUser.value = null;
    isAuthenticated.value = false;
  }

  // Refresh token function
  Future<bool> refreshAccessToken() async {
    try {
      final storedRefreshToken = StorageService.getRefreshToken();
      if (storedRefreshToken == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refreshToken}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': storedRefreshToken}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final newToken = responseData['data']['accessToken'];
          accessToken.value = newToken;
          await StorageService.saveAccessToken(newToken);
          return true;
        }
      }
    } catch (e) {
      print('Token refresh error: $e');
    }
    return false;
  }

  // Get user profile
  Future<UserModel?> getProfile() async {
    try {
      final token = StorageService.getAccessToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final user = UserModel.fromJson(responseData['data']);
          currentUser.value = user;
          await StorageService.saveUser(user.toJson());
          return user;
        }
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          return await getProfile();
        } else {
          await clearSession();
          Get.offAllNamed('/login');
        }
      }
    } catch (e) {
      print('Get profile error: $e');
    }
    return null;
  }

  // Change password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      isLoading.value = true;
      final token = StorageService.getAccessToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.changePassword}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(ChangePasswordRequest(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ).toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          Get.snackbar(
            'Success',
            'Password changed successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          isLoading.value = false;
          return true;
        }
      } else {
        final errorResponse = json.decode(response.body);
        Get.snackbar(
          'Error',
          errorResponse['message'] ?? 'Failed to change password',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // Verify token
  Future<bool> verifyToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.verifyToken}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['status'] == 'success';
      }
    } catch (e) {
      print('Verify token error: $e');
    }
    return false;
  }

  // Get auth headers for API calls
  Map<String, String> getAuthHeaders() {
    final token = StorageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Check if user has permission
  bool hasPermission(String permission) {
    if (currentUser.value == null) return false;
    
    // Admin has all permissions
    if (currentUser.value!.role == 'admin') return true;
    
    final perms = currentUser.value!.permissions;
    
    switch (permission) {
      case 'canCreateBoxes':
        return perms.canCreateBoxes;
      case 'canEditBoxes':
        return perms.canEditBoxes;
      case 'canDeleteBoxes':
        return perms.canDeleteBoxes;
      case 'canCreateCollections':
        return perms.canCreateCollections;
      case 'canCreateRetrievals':
        return perms.canCreateRetrievals;
      case 'canCreateDeliveries':
        return perms.canCreateDeliveries;
      case 'canViewReports':
        return perms.canViewReports;
      case 'canManageUsers':
        return perms.canManageUsers;
      default:
        return false;
    }
  }

  // Navigate to appropriate home page based on role
  void navigateToHome() {
    final role = currentUser.value?.role;
    
    if (role == 'client') {
      Get.offAllNamed('/client-home');
    } else if (role == 'admin' || role == 'staff') {
      Get.offAllNamed('/warehouse-home');
    } else {
      Get.offAllNamed('/login');
    }
  }
}