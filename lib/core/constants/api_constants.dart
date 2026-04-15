// lib/core/constants/api_constants.dart

class ApiConstants {
  ApiConstants._();

  static const String baseUrl =
      'https://pam-2026-p5-ifs23021-be.marshalll.fun:8080';

  static Uri uri(String path, {Map<String, dynamic>? queryParameters}) {
    final base = Uri.parse(baseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return base.replace(
      path: normalizedPath,
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  // ── Auth ──────────────────────────────────
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authLogout = '/auth/logout';
  static const String authRefresh = '/auth/refresh-token';

  // ── Users ─────────────────────────────────
  static const String usersMe = '/users/me';
  static const String usersMePassword = '/users/me/password';
  static const String usersMePhoto = '/users/me/photo';

  // ── Todos ─────────────────────────────────
  static const String todos = '/todos';
  static String todoById(String id) => '/todos/$id';
  static String todoCover(String id) => '/todos/$id/cover';
}
