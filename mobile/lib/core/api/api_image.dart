import '../constants/app_constants.dart';
import '../storage/local_store.dart';

/// Product photos are stored as base64 blobs in the database. The API returns
/// them as paths (for example `/api/products/<id>/image/0`) so product lists
/// stay small, and the bytes are pulled on demand through this helper.
class ApiImage {
  /// True when [value] points at an image served by our own API.
  static bool isApiPath(String value) => value.startsWith('/api/');

  /// Turns a relative API path into an absolute URL. Absolute URLs and inline
  /// data URLs are returned untouched.
  static String absolute(String value) {
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('data:')) return value;
    var base = AppConstants.baseUrl;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base${value.startsWith('/') ? value : '/$value'}';
  }

  /// The bearer token the image endpoint expects.
  static Future<Map<String, String>> headers() async {
    final token = await LocalStore.getToken();
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }
}
