import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    );
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final platform = _detectPlatform();
        if (platform != null) {
          options.headers['x-platform'] = platform;
          options.headers['x-app-version'] = '1.0.0';
        }
        handler.next(options);
      },
      onError: (e, handler) {
        debugPrint('[API] ${e.requestOptions.method} ${e.requestOptions.path} -> ${e.response?.statusCode} ${e.message}');
        if (e.response?.statusCode == 401) {
          debugPrint('[API] 401 detected, forcing logout');
          _onUnauthorized?.call();
        }
        handler.next(e);
      },
    ));
  }

  final Dio _dio;
  void Function()? _onUnauthorized;

  void setOnUnauthorized(void Function() handler) => _onUnauthorized = handler;

  String? _detectPlatform() {
    try {
      return Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    String url, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _dio.get(url, queryParameters: query);
          break;
        case 'POST':
          response = await _dio.post(url, data: data, queryParameters: query);
          break;
        case 'PUT':
          response = await _dio.put(url, data: data, queryParameters: query);
          break;
        case 'PATCH':
          response = await _dio.patch(url, data: data, queryParameters: query);
          break;
        case 'DELETE':
          response = await _dio.delete(url, data: data, queryParameters: query);
          break;
        default:
          throw const ApiException(statusCode: 0, message: 'Unsupported method');
      }
      final body = response.data;
      if (body is Map<String, dynamic> && body['success'] == true) {
        return body;
      }
      throw ApiException(
        statusCode: response.statusCode ?? 0,
        message: (body is Map<String, dynamic> && body['message'] != null)
            ? body['message'] as String
            : 'Unexpected response',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final data = e.response?.data;
      var message = 'Network error. Please check your connection.';
      if (data is Map<String, dynamic> && data['message'] != null) {
        message = data['message'] as String;
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        message = 'Request timed out. Please try again.';
      }
      throw ApiException(statusCode: status, message: message);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(statusCode: 0, message: e.toString());
    }
  }

  /// Downloads a file (e.g. CSV export) and returns its bytes.
  Future<List<int>> download(String url, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      var message = 'Network error. Please check your connection.';
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        message = data['message'] as String;
      }
      throw ApiException(statusCode: status, message: message);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
