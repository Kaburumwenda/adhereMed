/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'AdhereMed';
  // static const String baseUrl = 'https://adheremed.tiktek-ex.com/api';
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String tenantSchemaKey = 'tenant_schema';
}
