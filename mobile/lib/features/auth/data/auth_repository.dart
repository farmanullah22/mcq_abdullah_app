import '../../../core/api/api_client.dart';
import '../models/login_preview.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<({String token, User user})> login(
    String identifier,
    String password, {
    String? shopId,
    String? fcmToken,
  }) async {
    final res = await _api.request('POST', '/auth/login', data: {
      'identifier': identifier.trim(),
      'password': password,
      'shopId': ?shopId,
      'fcmToken': ?fcmToken,
    });
    final data = res['data'] as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: User.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<LoginPreview> previewLogin(String identifier) async {
    final res = await _api.request('GET', '/auth/preview', query: {'identifier': identifier.trim()});
    return LoginPreview.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> logout({String? fcmToken}) async {
    await _api.request('POST', '/auth/logout', data: {'fcmToken': ?fcmToken});
  }

  Future<User> getProfile() async {
    final res = await _api.request('GET', '/auth/profile');
    return User.fromJson((res['data'] as Map<String, dynamic>));
  }

  Future<User> updateProfile(Map<String, dynamic> data) async {
    final res = await _api.request('PUT', '/auth/profile', data: data);
    return User.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> changePassword(String current, String next) async {
    await _api.request('PUT', '/auth/change-password', data: {
      'currentPassword': current,
      'newPassword': next,
    });
  }

  Future<List<User>> listManagers() async {
    final res = await _api.request('GET', '/auth/managers');
    return (res['data'] as List).map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<User> createManager(Map<String, dynamic> data) async {
    final res = await _api.request('POST', '/auth/managers', data: data);
    return User.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> updateManager(String id, Map<String, dynamic> data) async {
    await _api.request('PUT', '/auth/managers/$id', data: data);
  }
}
