import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  static dynamic getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static dynamic saveAuthData(String token, Map user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_data', jsonEncode(user));
  }

  static dynamic getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('user_data');
    if (str == null) return null;
    return jsonDecode(str);
  }

  static dynamic clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_data');
  }

  static dynamic _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static dynamic get(String endpoint, {bool auth = true}) async {
    return http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(auth: auth),
    );
  }

  static dynamic post(String endpoint, Map body, {bool auth = true}) async {
    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
  }

  static dynamic put(String endpoint, Map body, {bool auth = true}) async {
    return http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
  }

  static dynamic delete(String endpoint, {bool auth = true}) async {
    return http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(auth: auth),
    );
  }
}