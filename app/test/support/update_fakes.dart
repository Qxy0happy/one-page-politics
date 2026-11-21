import 'dart:io';

import 'package:one_page_politics/models/update_manifest.dart';
import 'package:one_page_politics/services/update_gateway.dart';
import 'package:one_page_politics/services/update_service.dart';

UpdateManifest sampleManifest({
  int versionCode = 3,
  String versionName = '1.2.0',
  int minSdk = 24,
  int apkSize = 1024,
  String notes = '内容更新与稳定性改进',
  Uri? apkUrl,
}) {
  return UpdateManifest(
    schemaVersion: 1,
    versionCode: versionCode,
    versionName: versionName,
    minSdk: minSdk,
    publishedAt: DateTime.utc(2026, 11, 21, 12),
    notes: notes,
    apkUrl: apkUrl ?? Uri.parse('https://example.com/app.apk'),
    apkSize: apkSize,
    apkSha256: List.filled(64, 'a').join(),
  );
}

class FakeUpdateGateway implements UpdateGateway {
  InstalledApp app = const InstalledApp(
    versionCode: 2,
    versionName: '1.1.0',
    packageName: 'com.qxyhappy.one_page_politics',
    sdkInt: 36,
  );
  VerifyResult verifyResult = const VerifyResult(ok: true);
  InstallResult installResult = const InstallResult(
    status: InstallStatus.started,
  );
  bool openInstallSettingsResult = true;
  bool openUrlResult = true;
  bool? keepScreenOnValue;
  int verifyCalls = 0;
  int installCalls = 0;
  final List<String> openedUrls = [];

  @override
  Future<InstalledApp> installedApp() async => app;

  @override
  Future<VerifyResult> verifyApk({
    required String path,
    required String sha256,
    required int versionCode,
  }) async {
    verifyCalls++;
    return verifyResult;
  }

  @override
  Future<InstallResult> installApk(String path) async {
    installCalls++;
    return installResult;
  }

  @override
  Future<bool> openInstallPermissionSettings() async {
    return openInstallSettingsResult;
  }

  @override
  Future<bool> openUrl(String url) async {
    openedUrls.add(url);
    return openUrlResult;
  }

  @override
  Future<void> keepScreenOn(bool enabled) async {
    keepScreenOnValue = enabled;
  }
}

class FakeUpdateService extends UpdateService {
  FakeUpdateService({required super.gateway});

  UpdateManifest? manifest;
  Object? fetchError;
  File? downloadFile;
  Object? downloadError;
  int fetchCalls = 0;
  int downloadCalls = 0;
  void Function(int received, int total)? lastOnProgress;
  bool Function()? lastIsCancelled;

  @override
  Future<UpdateManifest> fetchManifest() async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return manifest!;
  }

  @override
  Future<File> downloadApk({
    required UpdateManifest manifest,
    required Directory directory,
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    downloadCalls++;
    lastOnProgress = onProgress;
    lastIsCancelled = isCancelled;
    if (downloadError != null) throw downloadError!;
    onProgress?.call(manifest.apkSize, manifest.apkSize);
    return downloadFile!;
  }
}
