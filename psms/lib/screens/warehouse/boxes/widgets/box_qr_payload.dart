// widgets/box_qr_payload.dart
//
// Single source of truth for the JSON payload encoded into every box QR
// code. Used by the QR dialog, bulk QR printing, and the "Find by QR Code"
// scanner so all three always agree on the same schema.

import 'dart:convert';
import 'package:psms/models/box_model.dart';

/// Builds the compact JSON payload that gets encoded into a box's QR code.
String buildBoxQrPayload(BoxModel box) {
  return jsonEncode({
    'id': box.boxId,
    'number': box.boxNumber,
    'client': box.client.clientCode,
    'status': box.status,
    if (box.rackingLabel != null) 'rack': box.rackingLabel!.labelCode,
    if (box.destructionYear != null) 'destYear': box.destructionYear,
  });
}

/// Attempts to parse a raw scanned QR value as a PSMS box payload.
///
/// Returns null when the scanned content isn't valid JSON or doesn't look
/// like a box payload, so callers can fall back to treating the raw string
/// as a plain search term instead (e.g. someone scans an unrelated code).
Map<String, dynamic>? parseBoxQrPayload(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic> && decoded.containsKey('number')) {
      return decoded;
    }
    return null;
  } catch (_) {
    return null;
  }
}