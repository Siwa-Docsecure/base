import 'package:get_storage/get_storage.dart';

class StorageService {
  static final GetStorage _storage = GetStorage();

  // Keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userRoleKey = 'user_role';

  // Save access token
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(_accessTokenKey, token);
  }

  // Get access token
  static String? getAccessToken() {
    return _storage.read<String>(_accessTokenKey);
  }

  // Save refresh token
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(_refreshTokenKey, token);
  }

  // Get refresh token
  static String? getRefreshToken() {
    return _storage.read<String>(_refreshTokenKey);
  }

  // Save user data
  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(_userKey, user);
  }

  // Get user data
  static Map<String, dynamic>? getUser() {
    return _storage.read<Map<String, dynamic>>(_userKey);
  }

  // Save login status
  static Future<void> setLoggedIn(bool isLoggedIn) async {
    await _storage.write(_isLoggedInKey, isLoggedIn);
  }

  // Check if user is logged in
  static bool isLoggedIn() {
    return _storage.read<bool>(_isLoggedInKey) ?? false;
  }

  // Save user role
  static Future<void> saveUserRole(String role) async {
    await _storage.write(_userRoleKey, role);
  }

  // Get user role
  static String? getUserRole() {
    return _storage.read<String>(_userRoleKey);
  }

  // Clear all storage (logout)
  static Future<void> clearAll() async {
    await _storage.erase();
  }

  // Check if user has warehouse access (admin or staff)
  static bool hasWarehouseAccess() {
    final role = getUserRole();
    return role == 'admin' || role == 'staff';
  }

  // Check if user is client
  static bool isClient() {
    final role = getUserRole();
    return role == 'client';
  }

  // Check if user is admin
  static bool isAdmin() {
    final role = getUserRole();
    return role == 'admin';
  }

  // Check if user is staff
  static bool isStaff() {
    final role = getUserRole();
    return role == 'staff';
  }
}