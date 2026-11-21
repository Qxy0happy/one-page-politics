import 'package:flutter/services.dart';

class InstalledApp {
  const InstalledApp({
    required this.versionCode,
    required this.versionName,
    required this.packageName,
    required this.sdkInt,
  });

  final int versionCode;
  final String versionName;
  final String packageName;
  final int sdkInt;
}

class VerifyResult {
  const VerifyResult({required this.ok, this.message = ''});

  final bool ok;
  final String message;
}

enum InstallStatus { started, permissionRequired, failed }

class InstallResult {
  const InstallResult({required this.status, this.message = ''});

  final InstallStatus status;
  final String message;
}

/// Android 侧更新能力的最小接缝；测试中使用内存实现。
abstract interface class UpdateGateway {
  Future<InstalledApp> installedApp();

  Future<VerifyResult> verifyApk({
    required String path,
    required String sha256,
    required int versionCode,
  });

  Future<InstallResult> installApk(String path);

  Future<bool> openInstallPermissionSettings();

  Future<bool> openUrl(String url);

  Future<void> keepScreenOn(bool enabled);
}

class UpdateGatewayException implements Exception {
  const UpdateGatewayException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AndroidUpdateGateway implements UpdateGateway {
  const AndroidUpdateGateway();

  static const MethodChannel _channel = MethodChannel(
    'one_page_politics/update',
  );

  @override
  Future<InstalledApp> installedApp() async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'installedApp',
      );
      if (map == null) {
        throw const UpdateGatewayException('无法读取当前版本');
      }
      final versionCode = (map['versionCode'] as num?)?.toInt();
      final sdkInt = (map['sdkInt'] as num?)?.toInt();
      final versionName = map['versionName'];
      final packageName = map['packageName'];
      if (versionCode == null ||
          sdkInt == null ||
          versionName is! String ||
          packageName is! String) {
        throw const UpdateGatewayException('当前版本信息不完整');
      }
      return InstalledApp(
        versionCode: versionCode,
        versionName: versionName,
        packageName: packageName,
        sdkInt: sdkInt,
      );
    } on PlatformException catch (error) {
      throw UpdateGatewayException(error.message ?? '无法读取当前版本');
    } on MissingPluginException {
      throw const UpdateGatewayException('当前平台不支持应用内更新');
    }
  }

  @override
  Future<VerifyResult> verifyApk({
    required String path,
    required String sha256,
    required int versionCode,
  }) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('verifyApk', {
        'path': path,
        'sha256': sha256,
        'versionCode': versionCode,
      });
      if (map == null) {
        throw const UpdateGatewayException('安装包校验没有返回结果');
      }
      final ok = map['ok'] == true;
      final message = map['message'];
      return VerifyResult(
        ok: ok,
        message: message is String ? message : (ok ? '' : '安装包校验失败'),
      );
    } on PlatformException catch (error) {
      throw UpdateGatewayException(error.message ?? '安装包校验失败');
    } on MissingPluginException {
      throw const UpdateGatewayException('当前平台不支持安装包校验');
    }
  }

  @override
  Future<InstallResult> installApk(String path) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'installApk',
        {'path': path},
      );
      final status = map?['status'];
      final message = map?['message'];
      final text = message is String ? message : '';
      return switch (status) {
        'started' => InstallResult(
          status: InstallStatus.started,
          message: text,
        ),
        'permission_required' => InstallResult(
          status: InstallStatus.permissionRequired,
          message: text,
        ),
        _ => InstallResult(
          status: InstallStatus.failed,
          message: text.isEmpty ? '无法调起系统安装器' : text,
        ),
      };
    } on PlatformException catch (error) {
      throw UpdateGatewayException(error.message ?? '无法调起系统安装器');
    } on MissingPluginException {
      throw const UpdateGatewayException('当前平台不支持应用内安装');
    }
  }

  @override
  Future<bool> openInstallPermissionSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openInstallSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> openUrl(String url) async {
    try {
      return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> keepScreenOn(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('keepScreenOn', {'enabled': enabled});
    } on PlatformException {
      // 屏幕常亮只是下载期间的辅助，失败不影响更新。
    } on MissingPluginException {
      // 同上。
    }
  }
}
