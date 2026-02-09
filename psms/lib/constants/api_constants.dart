class ApiConstants {
  static const String baseUrl = 'http://localhost:3000/api';
  
  // Auth endpoints
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String profile = '/auth/profile';
  static const String changePassword = '/auth/change-password';
  static const String verifyToken = '/auth/verify-token';
  
  // User endpoints
  static const String users = '/users';
  static const String userStats = '/users/stats';
  static String userById(String userId) => '/users/$userId';
  static String userByRole(String role) => '/users/role/$role';
  static String usersByClient(String clientId) => '/users/client/$clientId';
  static String activateUser(String userId) => '/users/$userId/activate';
  static String deactivateUser(String userId) => '/users/$userId/deactivate';
  static String resetPassword(String userId) => '/users/$userId/reset-password';
  static String assignClient(String userId) => '/users/$userId/assign-client';
  static String removeClient(String userId) => '/users/$userId/remove-client';
  static String changeClient(String userId) => '/users/$userId/change-client';
  static String userPermissions(String userId) => '/users/$userId/permissions';
  static String grantPermission(String userId) => '/users/$userId/permissions/grant';
  static String revokePermission(String userId) => '/users/$userId/permissions/revoke';
  static const String bulkCreateUsers = '/users/bulk/create';
  static const String bulkDeactivateUsers = '/users/bulk/deactivate';
  static const String bulkActivateUsers = '/users/bulk/activate';
  static String changeUserRole(String userId) => '/users/$userId/role';

  // Box endpoints
  static const String boxes = '/boxes';
  static const String boxStats = '/boxes/stats';
  static const String pendingDestruction = '/boxes/pending-destruction';
  static String boxById(String boxId) => '/boxes/$boxId';
  static String boxStatus(String boxId) => '/boxes/$boxId/status';
  static String boxesByClient(String clientId) => '/boxes/client/$clientId';
  static const String bulkCreateBoxes = '/boxes/bulk/create';
  static const String bulkUpdateStatus = '/boxes/bulk/status';
  
  // Racking label endpoints (for creating boxes)
  static const String rackingLabels = '/racking-labels';
  static const String availableRackingLabels = '/racking-labels/available';

  
  // Client endpoints
  static const String clients = '/clients';
  static const String clientsActive = '/clients/active';
  static String clientById(String clientId) => '/clients/$clientId';
  static String clientUsers(String clientId) => '/clients/$clientId/users';
  static String clientBoxes(String clientId) => '/clients/$clientId/boxes';
  static String clientStatistics(String clientId) => '/clients/$clientId/statistics';
  static String clientActivate(String clientId) => '/clients/$clientId/activate';
  static String clientAssignUser(String clientId) => '/clients/$clientId/assign-user';
  static String clientRemoveUser(String clientId, String userId) => '/clients/$clientId/users/$userId';
  static String clientAuditLogs(String clientId) => '/clients/$clientId/audit-logs';
  
  // Audit log endpoints
  static const String boxAuditLogs = '/audit-logs/box';
  static String boxAuditLogsById(String boxId) => '/audit-logs/box/$boxId';

  // Storage Management Endpoints
  static const String storageLocations = '/api/storage/locations';
  static const String storageAvailableLocations = '/api/storage/locations/available';
  static const String storageStats = '/api/storage/stats';
  static const String storageStatus = '/api/storage/status';
  
  // Helper method to get storage location by ID
  static String storageLocationById(String labelId) => '/api/storage/locations/$labelId';
}