import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/update_manifest.dart';
import '../services/update_gateway.dart';
import '../services/update_service.dart';

enum UpdatePhase {
  idle,
  checking,
  available,
  downloading,
  verifying,
  installing,
  upToDate,
  error,
}

class UpdateProvider extends ChangeNotifier {
  UpdateProvider({
    required this.service,
    required this.prefs,
    DateTime Function()? now,
    Future<Directory> Function()? temporaryDirectory,
  }) : _now = now ?? DateTime.now,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const _lastCheckKey = 'update.lastCheckAt';
  static const _checkOnLaunchKey = 'update.checkOnLaunch';
  static const _skippedKey = 'update.skippedVersionCode';
  static const _availableKey = 'update.availableManifest';
  static const _checkInterval = Duration(hours: 24);

  final UpdateService service;
  final SharedPreferences prefs;
  final DateTime Function() _now;
  final Future<Directory> Function() _temporaryDirectory;

  InstalledApp? _installed;
  UpdateManifest? _available;
  UpdatePhase _phase = UpdatePhase.idle;
  String? _message;
  int _received = 0;
  int _total = 0;
  bool _cancelled = false;
  bool _checkOnLaunch = true;
  int? _skippedVersionCode;
  DateTime? _lastCheck;
  bool _needsInstallPermission = false;
  bool _disposed = false;
  int _lastProgressNotifyMs = 0;

  InstalledApp? get installed => _installed;
  UpdateManifest? get available => _available;
  UpdatePhase get phase => _phase;
  String? get message => _message;
  int get receivedBytes => _received;
  int get totalBytes => _total;
  double get progress => _total <= 0 ? 0 : (_received / _total).clamp(0.0, 1.0);
  bool get checkOnLaunch => _checkOnLaunch;
  bool get needsInstallPermission => _needsInstallPermission;
  bool get canInstall =>
      _available != null &&
      _installed != null &&
      _available!.versionCode > _installed!.versionCode &&
      _available!.minSdk <= _installed!.sdkInt;

  String get currentVersionLabel {
    final app = _installed;
    if (app == null) return '未知';
    return '${app.versionName}（${app.versionCode}）';
  }

  String get githubReleasesUrl =>
      'https://github.com/Qxy0happy/one-page-politics/releases/latest';

  Future<void> load() async {
    _checkOnLaunch = prefs.getBool(_checkOnLaunchKey) ?? true;
    _skippedVersionCode = prefs.getInt(_skippedKey);
    final raw = prefs.getString(_lastCheckKey);
    _lastCheck = raw == null ? null : DateTime.tryParse(raw);
    try {
      _installed = await service.gateway.installedApp();
    } catch (_) {
      _installed = null;
    }
    _restoreAvailable();
    _notify();
  }

  void _restoreAvailable() {
    final raw = prefs.getString(_availableKey);
    if (raw == null) return;
    final installed = _installed;
    if (installed == null) return;
    try {
      final manifest = UpdateManifest.parse(
        raw,
        allowInsecure: service.allowInsecure,
      );
      if (manifest.versionCode > installed.versionCode &&
          manifest.versionCode != _skippedVersionCode) {
        _available = manifest;
        _phase = UpdatePhase.available;
      } else {
        unawaited(prefs.remove(_availableKey));
      }
    } catch (_) {
      unawaited(prefs.remove(_availableKey));
    }
  }

  /// 手动检查始终联网；静默检查遵守开关与 24 小时缓存。
  Future<void> check({bool silent = false}) async {
    if (_phase == UpdatePhase.checking || _phase == UpdatePhase.downloading) {
      return;
    }
    if (silent) {
      if (!_checkOnLaunch) return;
      final last = _lastCheck;
      if (last != null && _now().difference(last) < _checkInterval) return;
    }

    if (_installed == null) {
      try {
        _installed = await service.gateway.installedApp();
      } catch (_) {
        _installed = null;
      }
    }
    if (_installed == null) {
      if (!silent) {
        _phase = UpdatePhase.error;
        _message = '无法读取当前版本';
        _notify();
      }
      return;
    }

    _phase = UpdatePhase.checking;
    _message = null;
    _needsInstallPermission = false;
    _notify();

    try {
      final manifest = await service.fetchManifest();
      final now = _now();
      _lastCheck = now;
      await prefs.setString(_lastCheckKey, now.toIso8601String());
      if (manifest.versionCode > _installed!.versionCode) {
        if (silent && _skippedVersionCode == manifest.versionCode) {
          _available = null;
          _phase = UpdatePhase.idle;
          await prefs.remove(_availableKey);
        } else {
          _available = manifest;
          _phase = UpdatePhase.available;
          await prefs.setString(_availableKey, jsonEncode(manifest.toJson()));
        }
      } else {
        _available = null;
        _phase = silent ? UpdatePhase.idle : UpdatePhase.upToDate;
        await prefs.remove(_availableKey);
      }
    } catch (error) {
      if (silent) {
        _phase = _available == null ? UpdatePhase.idle : UpdatePhase.available;
      } else {
        _phase = UpdatePhase.error;
        _message = _humanize(error);
      }
    }
    _notify();
  }

  Future<void> downloadAndInstall() async {
    final manifest = _available;
    final installed = _installed;
    if (manifest == null || installed == null) return;
    if (_phase == UpdatePhase.downloading ||
        _phase == UpdatePhase.verifying ||
        _phase == UpdatePhase.installing) {
      return;
    }
    if (manifest.minSdk > installed.sdkInt) {
      _phase = UpdatePhase.error;
      _message = '新版本要求 Android ${manifest.minSdk} 或更高';
      _notify();
      return;
    }

    _phase = UpdatePhase.downloading;
    _message = null;
    _needsInstallPermission = false;
    _received = 0;
    _total = manifest.apkSize;
    _cancelled = false;
    _lastProgressNotifyMs = 0;
    _notify();

    await service.gateway.keepScreenOn(true);
    try {
      final temp = await _temporaryDirectory();
      final file = await service.downloadApk(
        manifest: manifest,
        directory: Directory('${temp.path}${Platform.pathSeparator}updates'),
        onProgress: (received, total) {
          _received = received;
          _total = total;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastProgressNotifyMs >= 100 || received == total) {
            _lastProgressNotifyMs = now;
            _notify();
          }
        },
        isCancelled: () => _cancelled,
      );
      if (_disposed) return;

      _phase = UpdatePhase.verifying;
      _notify();
      final verified = await service.gateway.verifyApk(
        path: file.path,
        sha256: manifest.apkSha256,
        versionCode: manifest.versionCode,
      );
      if (!verified.ok) {
        throw UpdateServiceException(verified.message);
      }

      _phase = UpdatePhase.installing;
      _notify();
      final result = await service.gateway.installApk(file.path);
      if (result.status == InstallStatus.started) {
        _message = '已调起系统安装，请在系统界面确认';
        _phase = UpdatePhase.installing;
      } else if (result.status == InstallStatus.permissionRequired) {
        _message = result.message.isEmpty ? '需要允许安装未知应用' : result.message;
        _needsInstallPermission = true;
        _phase = UpdatePhase.available;
      } else {
        _phase = UpdatePhase.error;
        _message = result.message;
      }
    } on UpdateCancelled {
      _phase = UpdatePhase.available;
      _message = '下载已取消，可继续下载';
    } catch (error) {
      _phase = UpdatePhase.error;
      _message = _humanize(error);
    } finally {
      await service.gateway.keepScreenOn(false);
      _notify();
    }
  }

  void cancelDownload() {
    if (_phase == UpdatePhase.downloading) {
      _cancelled = true;
      _notify();
    }
  }

  Future<void> openInstallPermissionSettings() async {
    final opened = await service.gateway.openInstallPermissionSettings();
    if (!opened) {
      _message = '无法打开安装权限设置，请在系统设置中允许本应用安装应用';
      _notify();
    }
  }

  Future<void> openReleasesPage() async {
    final opened = await service.gateway.openUrl(githubReleasesUrl);
    if (!opened) {
      _message = '无法打开浏览器';
      _notify();
    }
  }

  Future<void> setCheckOnLaunch(bool value) async {
    if (_checkOnLaunch == value) return;
    _checkOnLaunch = value;
    _notify();
    await prefs.setBool(_checkOnLaunchKey, value);
  }

  Future<void> skipVersion() async {
    final manifest = _available;
    if (manifest == null) return;
    _skippedVersionCode = manifest.versionCode;
    await prefs.setInt(_skippedKey, manifest.versionCode);
    _available = null;
    _phase = UpdatePhase.idle;
    _message = null;
    _needsInstallPermission = false;
    await prefs.remove(_availableKey);
    _notify();
  }

  Future<void> refreshInstalled() async {
    try {
      final next = await service.gateway.installedApp();
      _installed = next;
      if (_available != null && next.versionCode >= _available!.versionCode) {
        _available = null;
        _phase = UpdatePhase.upToDate;
        _message = null;
        await prefs.remove(_availableKey);
      }
      _notify();
    } catch (_) {
      // 回到前台时的版本刷新失败不打扰用户；下次检查会重试。
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _humanize(Object error) {
    if (error is UpdateServiceException) return error.message;
    if (error is UpdateManifestException) return error.message;
    if (error is UpdateGatewayException) return error.message;
    if (error is SocketException) return '网络连接失败，请检查网络';
    return '更新失败：$error';
  }
}
