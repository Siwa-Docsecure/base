class ApiConstants {
  static const String baseUrl = 'http://localhost:3000/api';

  // ============================================
  // AUTH ENDPOINTS
  // ============================================

  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String profile = '/auth/profile';
  static const String changePassword = '/auth/change-password';
  static const String verifyToken = '/auth/verify-token';

  // ============================================
  // USER ENDPOINTS
  // ============================================

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
  static String grantPermission(String userId) =>
      '/users/$userId/permissions/grant';
  static String revokePermission(String userId) =>
      '/users/$userId/permissions/revoke';
  static const String bulkCreateUsers = '/users/bulk/create';
  static const String bulkDeactivateUsers = '/users/bulk/deactivate';
  static const String bulkActivateUsers = '/users/bulk/activate';
  static String changeUserRole(String userId) => '/users/$userId/role';

  // ============================================
  // BOX ENDPOINTS
  // ============================================

  static const String boxes = '/boxes';
  static const String boxStats = '/boxes/stats';
  static const String pendingDestruction = '/boxes/pending-destruction';
  static String boxById(String boxId) => '/boxes/$boxId';
  static String boxStatus(String boxId) => '/boxes/$boxId/status';
  static String boxesByClient(String clientId) => '/boxes/client/$clientId';
  static const String bulkCreateBoxes = '/boxes/bulk/create';
  static const String bulkUpdateStatus = '/boxes/bulk/status';
  static const String boxReportSingle = '/boxes/report/single';
  static const String boxReportBulk = '/boxes/report/bulk';


  // ============================================
  // RACKING LABEL ENDPOINTS
  // ============================================

  static const String rackingLabels = '/racking-labels';
  static const String availableRackingLabels = '/racking-labels/available';

  // ============================================
  // CLIENT ENDPOINTS
  // ============================================

  static const String clients = '/clients';
  static const String clientsActive = '/clients/active';
  static String clientById(String clientId) => '/clients/$clientId';
  static String clientUsers(String clientId) => '/clients/$clientId/users';
  static String clientBoxes(String clientId) => '/clients/$clientId/boxes';
  static String clientStatistics(String clientId) =>
      '/clients/$clientId/statistics';
  static String clientActivate(String clientId) =>
      '/clients/$clientId/activate';
  static String clientAssignUser(String clientId) =>
      '/clients/$clientId/assign-user';
  static String clientRemoveUser(String clientId, String userId) =>
      '/clients/$clientId/users/$userId';
  static String clientAuditLogs(String clientId) =>
      '/clients/$clientId/audit-logs';

  // ============================================
  // AUDIT LOG ENDPOINTS
  // ============================================

  static const String boxAuditLogs = '/audit-logs/box';
  static String boxAuditLogsById(String boxId) => '/audit-logs/box/$boxId';

  // ============================================
  // STORAGE MANAGEMENT ENDPOINTS
  // ============================================

  static const String storageLocations = '/api/storage/locations';
  static const String storageAvailableLocations =
      '/api/storage/locations/available';
  static const String storageStats = '/api/storage/stats';
  static const String storageStatus = '/api/storage/status';
  static String storageLocationById(String labelId) =>
      '/api/storage/locations/$labelId';

  // ============================================
  // RETRIEVAL ENDPOINTS
  // ============================================

  // Base retrieval endpoints
  static const String retrievals = '/retrievals';
  static const String retrievalStats = '/retrievals/stats';
  static const String recentRetrievals = '/retrievals/recent';
  static const String pendingRetrievals = '/retrievals/pending';
  static const String myPendingRetrievals = '/retrievals/pending/my';

  // Retrieval by ID
  static String retrievalById(String retrievalId) => '/retrievals/$retrievalId';

  // Retrieval by client/box
  static String retrievalsByClient(String clientId) =>
      '/retrievals/client/$clientId';
  static String retrievalsByBox(String boxId) => '/retrievals/box/$boxId';

  // Retrieval signatures and PDF
  static String retrievalSignatures(String retrievalId) =>
      '/retrievals/$retrievalId/signatures';
  static String retrievalPdf(String retrievalId) =>
      '/retrievals/$retrievalId/pdf';

  // Box status management
  static String markBoxRetrieved(String boxId) =>
      '/retrievals/box/$boxId/mark-retrieved';

  // Retrieval reports
  static const String retrievalSummaryReport = '/retrievals/reports/summary';
  static const String retrievalByClientReport = '/retrievals/reports/by-client';

  // ============================================
  // COLLECTION ENDPOINTS
  // ============================================

  // Base collection endpoints
  static const String collections = '/collections';
  static const String collectionStats = '/collections/stats';
  static const String recentCollections = '/collections/recent';
  static const String pendingCollections = '/collections/pending';
  static const String myPendingCollections = '/collections/pending/my';

  // Collection by ID
  static String collectionById(String collectionId) =>
      '/collections/$collectionId';

  // Collection by client
  static String collectionsByClient(String clientId) =>
      '/collections/client/$clientId';

  // Collection signatures and PDF
  static String collectionSignatures(String collectionId) =>
      '/collections/$collectionId/signatures';
  static String collectionPdf(String collectionId) =>
      '/collections/$collectionId/pdf';

  // Box status management for collections
  static String markBoxStored(String boxId) =>
      '/collections/box/$boxId/mark-stored';

  // Collection reports
  static const String collectionSummaryReport = '/collections/reports/summary';
  static const String collectionByClientReport =
      '/collections/reports/by-client';
}
