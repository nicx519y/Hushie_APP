import 'dart:convert';
import '../../config/api_config.dart';
import '../http_client_service.dart';
import '../../models/api_response.dart';
import '../../models/pending_migration_model.dart';

class SubscriptionMigrationService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  static Future<ApiResponse<PendingMigrationInfo>> checkPendingMigration() async {
    try {
      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.subscriptionsPendingMigration),
      );

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      final Map<String, dynamic> jsonData = json.decode(response.body);
      final apiResponse = ApiResponse.fromJson<PendingMigrationInfo>(
        jsonData,
        (dataJson) => PendingMigrationInfo.fromMap(dataJson),
      );

      return apiResponse;
    } catch (e) {
      return ApiResponse.error(errNo: -1);
    }
  }
}