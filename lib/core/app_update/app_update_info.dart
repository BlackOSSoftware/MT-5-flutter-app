import '../api_config.dart';

/// Backend `GET /v1/app-update/info` ka data.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.force,
    required this.releaseNotes,
  });

  final String versionName;

  /// pubspec `version: x.y.z+CODE` ka CODE.
  final int versionCode;
  final String apkUrl;
  final bool force;
  final String releaseNotes;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) => AppUpdateInfo(
    versionName: '${json['latestVersionName'] ?? ''}',
    versionCode: (json['latestVersionCode'] as num?)?.toInt() ?? 0,
    apkUrl: '${json['apkUrl'] ?? ''}'.trim(),
    force: json['force'] == true,
    releaseNotes: '${json['releaseNotes'] ?? ''}'.trim(),
  );

  /// `/downloads/app.apk` jaisa path ho to isi backend ka host jodo.
  String get downloadUrl =>
      apkUrl.startsWith('/') ? 'http://${ApiConfig.host}$apkUrl' : apkUrl;
}
