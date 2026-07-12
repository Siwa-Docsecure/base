// audit_models.dart

// ─────────────────────────────────────────────────────────────────────────────
// SAFE PARSING HELPERS — MySQL2 driver returns mixed types
// ─────────────────────────────────────────────────────────────────────────────

int _toInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String _toStr(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

// ============================================
// SHARED
// ============================================

class AuditActor {
  final int userId;
  final String username;
  final String role;

  AuditActor({required this.userId, required this.username, required this.role});

  factory AuditActor.fromJson(Map<String, dynamic> json) => AuditActor(
        userId:   _toInt(json['userId']),
        username: _toStr(json['username']),
        role:     _toStr(json['role']),
      );
}

// ============================================
// AUDIT LOG ENTRY
// ============================================

class AuditLogEntry {
  final int auditId;
  final String action;
  final String entityType;
  final int? entityId;
  final dynamic oldValue;
  final dynamic newValue;
  final String? ipAddress;
  final String? userAgent;
  final String timestamp;
  final AuditActor? actor;

  AuditLogEntry({
    required this.auditId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.oldValue,
    this.newValue,
    this.ipAddress,
    this.userAgent,
    required this.timestamp,
    this.actor,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        auditId:    _toInt(json['auditId']),
        action:     _toStr(json['action']),
        entityType: _toStr(json['entityType']),
        entityId:   json['entityId'] != null ? _toInt(json['entityId']) : null,
        oldValue:   json['oldValue'],
        newValue:   json['newValue'],
        ipAddress:  json['ipAddress']?.toString(),
        userAgent:  json['userAgent']?.toString(),
        timestamp:  _toStr(json['timestamp']),
        actor: json['actor'] != null
            ? AuditActor.fromJson(json['actor'] as Map<String, dynamic>)
            : null,
      );

  bool get isAuthEvent    => entityType == 'auth';
  bool get isDestructive  => action.contains('DELETE') || action.contains('DESTROY');
}

// ============================================
// PAGINATION
// ============================================

class AuditPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  AuditPagination({required this.page, required this.limit, required this.total, required this.totalPages});

  factory AuditPagination.fromJson(Map<String, dynamic> json) =>
      AuditPagination(
        page:       _toInt(json['page']),
        limit:      _toInt(json['limit']),
        total:      _toInt(json['total']),
        totalPages: _toInt(json['totalPages']),
      );
}

class AuditLogPage {
  final List<AuditLogEntry> logs;
  final AuditPagination pagination;

  AuditLogPage({required this.logs, required this.pagination});

  factory AuditLogPage.fromJson(Map<String, dynamic> json) => AuditLogPage(
        logs: (json['logs'] as List<dynamic>)
            .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: AuditPagination.fromJson(json['pagination'] as Map<String, dynamic>),
      );
}

// ============================================
// SINGLE EVENT DETAIL (with diff)
// ============================================

class AuditFieldDiff {
  final dynamic before;
  final dynamic after;

  AuditFieldDiff({required this.before, required this.after});

  factory AuditFieldDiff.fromJson(Map<String, dynamic> json) =>
      AuditFieldDiff(before: json['before'], after: json['after']);
}

class AuditLogDetail extends AuditLogEntry {
  final Map<String, AuditFieldDiff>? diff;

  AuditLogDetail({
    required super.auditId,
    required super.action,
    required super.entityType,
    super.entityId,
    super.oldValue,
    super.newValue,
    super.ipAddress,
    super.userAgent,
    required super.timestamp,
    super.actor,
    this.diff,
  });

  factory AuditLogDetail.fromJson(Map<String, dynamic> json) {
    final base = AuditLogEntry.fromJson(json);
    Map<String, AuditFieldDiff>? diff;

    if (json['diff'] != null) {
      final rawDiff = json['diff'] as Map<String, dynamic>;
      diff = rawDiff.map(
        (key, value) => MapEntry(key, AuditFieldDiff.fromJson(value as Map<String, dynamic>)),
      );
    }

    return AuditLogDetail(
      auditId:    base.auditId,
      action:     base.action,
      entityType: base.entityType,
      entityId:   base.entityId,
      oldValue:   base.oldValue,
      newValue:   base.newValue,
      ipAddress:  base.ipAddress,
      userAgent:  base.userAgent,
      timestamp:  base.timestamp,
      actor:      base.actor,
      diff:       diff,
    );
  }
}

// ============================================
// ENTITY HISTORY
// ============================================

class EntityAuditHistory {
  final String entityType;
  final int entityId;
  final int totalEvents;
  final List<AuditLogEntry> history;

  EntityAuditHistory({
    required this.entityType,
    required this.entityId,
    required this.totalEvents,
    required this.history,
  });

  factory EntityAuditHistory.fromJson(Map<String, dynamic> json) =>
      EntityAuditHistory(
        entityType:  _toStr(json['entityType']),
        entityId:    _toInt(json['entityId']),
        totalEvents: _toInt(json['totalEvents']),
        history: (json['history'] as List<dynamic>)
            .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================
// USER ACTIVITY SUMMARY
// ============================================

class UserAuditActivity {
  final int userId;
  final Map<String, int> actionBreakdown;
  final List<AuditLogEntry> recentEvents;

  UserAuditActivity({required this.userId, required this.actionBreakdown, required this.recentEvents});

  factory UserAuditActivity.fromJson(Map<String, dynamic> json) =>
      UserAuditActivity(
        userId: _toInt(json['userId']),
        actionBreakdown: (json['actionBreakdown'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, _toInt(v))),
        recentEvents: (json['recentEvents'] as List<dynamic>)
            .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================
// AUDIT SUMMARY / AGGREGATE STATS
// ============================================

class AuditTopActor {
  final String username;
  final String role;
  final int eventCount;

  AuditTopActor({required this.username, required this.role, required this.eventCount});

  factory AuditTopActor.fromJson(Map<String, dynamic> json) => AuditTopActor(
        username:   _toStr(json['username']),
        role:       _toStr(json['role']),
        eventCount: _toInt(json['eventCount']),
      );
}

class AuditDailyVolume {
  final String day;
  final int eventCount;

  AuditDailyVolume({required this.day, required this.eventCount});

  factory AuditDailyVolume.fromJson(Map<String, dynamic> json) =>
      AuditDailyVolume(
        day:        _toStr(json['day']),
        eventCount: _toInt(json['eventCount']),
      );
}

class AuditSummary {
  final Map<String, int> actionBreakdown;
  final Map<String, int> entityBreakdown;
  final List<AuditTopActor> topActors;
  final List<AuditDailyVolume> dailyVolume;

  AuditSummary({
    required this.actionBreakdown,
    required this.entityBreakdown,
    required this.topActors,
    required this.dailyVolume,
  });

  factory AuditSummary.fromJson(Map<String, dynamic> json) => AuditSummary(
        actionBreakdown: (json['actionBreakdown'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, _toInt(v))),
        entityBreakdown: (json['entityBreakdown'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, _toInt(v))),
        topActors: (json['topActors'] as List<dynamic>? ?? [])
            .map((e) => AuditTopActor.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyVolume: (json['dailyVolume'] as List<dynamic>? ?? [])
            .map((e) => AuditDailyVolume.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================
// EXPORT REQUEST
// ============================================

class AuditExportRequest {
  final String? userId;
  final String? action;
  final String? entityType;
  final String? entityId;
  final String? ipAddress;
  final String? dateFrom;
  final String? dateTo;
  final String? search;
  final int limit;

  AuditExportRequest({
    this.userId,
    this.action,
    this.entityType,
    this.entityId,
    this.ipAddress,
    this.dateFrom,
    this.dateTo,
    this.search,
    this.limit = 5000,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (userId     != null && userId!.isNotEmpty)     params['userId']     = userId!;
    if (action     != null && action!.isNotEmpty)     params['action']     = action!;
    if (entityType != null && entityType!.isNotEmpty) params['entityType'] = entityType!;
    if (entityId   != null && entityId!.isNotEmpty)   params['entityId']   = entityId!;
    if (ipAddress  != null && ipAddress!.isNotEmpty)  params['ipAddress']  = ipAddress!;
    if (dateFrom   != null && dateFrom!.isNotEmpty)   params['dateFrom']   = dateFrom!;
    if (dateTo     != null && dateTo!.isNotEmpty)     params['dateTo']     = dateTo!;
    if (search     != null && search!.isNotEmpty)     params['search']     = search!;
    params['limit'] = limit.toString();
    return params;
  }
}