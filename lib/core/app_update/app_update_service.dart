import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api_config.dart';
import 'app_update_info.dart';

/// APK update: server par naya build hai ya nahi + install permission.
abstract final class AppUpdateService {
  static const _channel = MethodChannel('mt5/app_update');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Naya build ho (server code > is app ka build number) to info, warna
  /// null. Server na mile to bhi null - app chalta rahe.
  static Future<AppUpdateInfo?> check() async {
    if (!supported) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final uri = Uri.parse(
        '${ApiConfig.httpBase}/v1/app-update/info',
      ).replace(queryParameters: const {'platform': 'android'});
      final req = await client.getUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      if (resp.statusCode != 200 ||
          body is! Map<String, dynamic> ||
          body['success'] != true ||
          body['data'] is! Map<String, dynamic>) {
        return null;
      }
      final info = AppUpdateInfo.fromJson(body['data']);
      if (info.apkUrl.isEmpty) return null;
      final current = await currentVersionCode();
      return info.versionCode > current ? info : null;
    } catch (e) {
      debugPrint('[app-update] check failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<int> currentVersionCode() async {
    final pkg = await PackageInfo.fromPlatform();
    return int.tryParse(pkg.buildNumber) ?? 0;
  }

  /// Android 8+ me "Install unknown apps" is app ke liye on hai?
  static Future<bool> canInstallPackages() async {
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod('openInstallSettings');
    } on PlatformException catch (e) {
      debugPrint('[app-update] open settings failed: ${e.message}');
    }
  }
}
