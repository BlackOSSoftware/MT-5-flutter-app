import 'package:app_installer_plus/app_installer_plus.dart';
import 'package:app_installer_plus/core/enums/download_error_type.dart';
import 'package:app_installer_plus/core/exceptions/file_download_exception.dart';
import 'package:flutter/material.dart';

import '../mt_colors.dart';
import '../widgets/mt_dialogs.dart';
import 'app_update_info.dart';
import 'app_update_service.dart';

const _blue = Color(0xFF168BE1);

/// MT5 style update dialog. Force update me band nahi hota (na back, na
/// bahar tap, na "Later"); optional me "Later" se app chalta rehta hai.
Future<void> showAppUpdateDialog(BuildContext context, AppUpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AppUpdateDialog(info: info),
  );
}

enum _Step { ready, permission, downloading, installing, failed }

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.info});

  final AppUpdateInfo info;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  _Step _step = _Step.ready;
  double _progress = 0;
  String _size = '';
  String _error = '';

  AppUpdateInfo get info => widget.info;

  Future<void> _update() async {
    if (!await AppUpdateService.canInstallPackages()) {
      if (mounted) setState(() => _step = _Step.permission);
      return;
    }
    setState(() {
      _step = _Step.downloading;
      _progress = 0;
      _size = '';
    });
    try {
      await AppInstallerPlus().downloadAndInstallApk(
        downloadFileUrl: info.downloadUrl,
        downloadFileName: 'mt5_update_${info.versionCode}',
        deleteOnError: true,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p.clamp(0, 1).toDouble());
        },
        onTotalSize: (s) {
          if (mounted) setState(() => _size = s);
        },
      );
      if (!mounted) return;
      // Android installer khul gaya. Optional update me dialog band; force
      // me khula rehta hai taaki install cancel karke app na chale.
      if (info.force) {
        setState(() => _step = _Step.installing);
      } else {
        Navigator.of(context).pop();
      }
    } on FileDownloadException catch (e) {
      if (!mounted || e.type == DownloadErrorType.cancelled) return;
      setState(() {
        _step = _Step.failed;
        _error = switch (e.type) {
          DownloadErrorType.noInternetConnection ||
          DownloadErrorType.networkTimeout => 'No connection to the server',
          DownloadErrorType.storageAccessDenied => 'No storage access',
          DownloadErrorType.badResponse => 'Update file not found',
          _ => 'Download failed',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _step = _Step.failed;
        _error = 'Download failed';
      });
    }
  }

  Future<void> _cancelDownload() async {
    await AppInstallerPlus().cancelDownload(deletePartialDownload: true);
    if (mounted) setState(() => _step = _Step.ready);
  }

  Future<void> _openSettings() async {
    await AppUpdateService.openInstallSettings();
    // Settings se wapas aakar UPDATE dobara dabana - tab permission check.
    if (mounted) setState(() => _step = _Step.ready);
  }

  @override
  Widget build(BuildContext context) {
    final force = info.force;
    return PopScope(
      canPop: !force && _step != _Step.downloading,
      child: Dialog(
        backgroundColor: MtColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title(force),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: MtColors.text,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _body(force),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final (label, onTap) in _actions(force)) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onTap,
                      style: TextButton.styleFrom(
                        foregroundColor: _blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _title(bool force) => switch (_step) {
    _Step.permission => 'Permission required',
    _Step.downloading => 'Downloading update',
    _Step.installing => 'Install update',
    _Step.failed => 'Update failed',
    _Step.ready => force ? 'Update required' : 'Update available',
  };

  Widget _body(bool force) {
    final style = mtDialogMessageStyle();
    switch (_step) {
      case _Step.permission:
        return Text(
          "To update, allow 'Install unknown apps' for MT5 in settings, "
          'then tap UPDATE again.',
          style: style,
        );
      case _Step.downloading:
        final pct = (_progress * 100).toStringAsFixed(0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 4,
                color: _blue,
                backgroundColor: const Color(0xFFE3EEF8),
              ),
            ),
            const SizedBox(height: 10),
            Text(_size.isEmpty ? '$pct%' : '$pct%  ·  $_size', style: style),
          ],
        );
      case _Step.installing:
        return Text(
          'Install version ${info.versionName} to continue using the app.',
          style: style,
        );
      case _Step.failed:
        return Text('$_error. Please try again.', style: style);
      case _Step.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              force
                  ? 'Version ${info.versionName} is required to continue '
                        'using the app.'
                  : 'Version ${info.versionName} is available.',
              style: style,
            ),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: style.copyWith(fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        );
    }
  }

  List<(String, VoidCallback)> _actions(bool force) {
    void later() => Navigator.of(context).pop();
    return switch (_step) {
      _Step.permission => [
        if (!force) ('LATER', later),
        ('OPEN SETTINGS', _openSettings),
      ],
      _Step.downloading => [('CANCEL', _cancelDownload)],
      _Step.installing => [('INSTALL', _update)],
      _Step.failed => [if (!force) ('LATER', later), ('RETRY', _update)],
      _Step.ready => [if (!force) ('LATER', later), ('UPDATE', _update)],
    };
  }
}
