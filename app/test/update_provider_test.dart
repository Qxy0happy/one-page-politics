import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/providers/update_provider.dart';
import 'package:one_page_politics/services/update_gateway.dart';
import 'package:one_page_politics/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/update_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeUpdateGateway gateway;
  late FakeUpdateService service;
  late SharedPreferences prefs;
  late Directory tempDir;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gateway = FakeUpdateGateway();
    service = FakeUpdateService(gateway: gateway);
    tempDir = await Directory.systemTemp.createTemp('update-provider-test');
    now = DateTime.utc(2026, 11, 21, 12);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  UpdateProvider provider() => UpdateProvider(
    service: service,
    prefs: prefs,
    now: () => now,
    temporaryDirectory: () async => tempDir,
  );

  test('发现新版本并可安装', () async {
    service.manifest = sampleManifest(versionCode: 3);
    final update = provider();
    await update.load();
    await update.check();

    expect(update.available, isNotNull);
    expect(update.phase, UpdatePhase.available);
    expect(update.canInstall, isTrue);
    expect(update.currentVersionLabel, contains('1.1.0'));
  });

  test('更新提示在重启后从本地缓存恢复', () async {
    service.manifest = sampleManifest(versionCode: 3);
    final first = provider();
    await first.load();
    await first.check(silent: true);
    expect(first.available, isNotNull);

    final second = provider();
    await second.load();
    expect(second.available, isNotNull);
    expect(second.phase, UpdatePhase.available);
    expect(second.available!.versionName, '1.2.0');
  });

  test('手动检查失败时保留已发现的更新', () async {
    service.manifest = sampleManifest(versionCode: 3);
    final update = provider();
    await update.load();
    await update.check(silent: true);
    expect(update.available, isNotNull);

    service.fetchError = const UpdateServiceException('网络连接失败');
    await update.check();

    expect(update.available, isNotNull);
    expect(update.phase, UpdatePhase.error);
    expect(update.message, contains('网络'));
  });

  test('版本不高于当前版本时显示已是最新', () async {
    service.manifest = sampleManifest(versionCode: 2);
    final update = provider();
    await update.load();
    await update.check();

    expect(update.available, isNull);
    expect(update.phase, UpdatePhase.upToDate);
  });

  test('静默检查在 24 小时内只请求一次', () async {
    service.manifest = sampleManifest(versionCode: 3);
    final update = provider();
    await update.load();
    await update.check(silent: true);
    expect(service.fetchCalls, 1);

    now = now.add(const Duration(hours: 1));
    await update.check(silent: true);
    expect(service.fetchCalls, 1);

    now = now.add(const Duration(hours: 25));
    await update.check(silent: true);
    expect(service.fetchCalls, 2);
  });

  test('关闭启动检查后静默检查不联网', () async {
    service.manifest = sampleManifest(versionCode: 3);
    final update = provider();
    await update.load();
    await update.setCheckOnLaunch(false);
    await update.check(silent: true);

    expect(service.fetchCalls, 0);
    expect(prefs.getBool('update.checkOnLaunch'), isFalse);
  });

  test('静默检查跳过已忽略的版本，手动检查仍提示', () async {
    SharedPreferences.setMockInitialValues({'update.skippedVersionCode': 3});
    prefs = await SharedPreferences.getInstance();
    service.manifest = sampleManifest(versionCode: 3);
    final update = provider();
    await update.load();

    await update.check(silent: true);
    expect(update.available, isNull);

    await update.check();
    expect(update.available, isNotNull);
    expect(update.available!.versionCode, 3);
  });

  test('手动检查失败给出错误，静默检查失败不打扰', () async {
    service.fetchError = const UpdateServiceException('网络连接失败');
    final update = provider();
    await update.load();
    await update.check();
    expect(update.phase, UpdatePhase.error);
    expect(update.message, contains('网络'));

    final quiet = provider();
    await quiet.load();
    await quiet.check(silent: true);
    expect(quiet.phase, UpdatePhase.idle);
  });

  test('下载、校验并调起安装器', () async {
    service.manifest = sampleManifest(versionCode: 3);
    final apk = File('${tempDir.path}/update-3.apk');
    await apk.writeAsBytes([1, 2, 3]);
    service.downloadFile = apk;
    final update = provider();
    await update.load();
    await update.check();

    await update.downloadAndInstall();

    expect(service.downloadCalls, 1);
    expect(gateway.verifyCalls, greaterThanOrEqualTo(1));
    expect(gateway.installCalls, 1);
    expect(update.phase, UpdatePhase.installing);
    expect(update.message, contains('系统安装'));
    expect(gateway.keepScreenOnValue, isFalse);
  });

  test('缺少安装权限时保留下载文件并提示打开设置', () async {
    service.manifest = sampleManifest(versionCode: 3);
    final apk = File('${tempDir.path}/update-3.apk');
    await apk.writeAsBytes([1, 2, 3]);
    service.downloadFile = apk;
    gateway.installResult = const InstallResult(
      status: InstallStatus.permissionRequired,
      message: '需要允许安装未知应用',
    );
    final update = provider();
    await update.load();
    await update.check();

    await update.downloadAndInstall();

    expect(update.phase, UpdatePhase.available);
    expect(update.needsInstallPermission, isTrue);
    expect(update.message, contains('允许'));
  });

  test('校验失败时不调起安装器', () async {
    service.manifest = sampleManifest(versionCode: 3);
    final apk = File('${tempDir.path}/update-3.apk');
    await apk.writeAsBytes([1, 2, 3]);
    service.downloadFile = apk;
    gateway.verifyResult = const VerifyResult(
      ok: false,
      message: '安装包签名与已安装版本不一致',
    );
    final update = provider();
    await update.load();
    await update.check();

    await update.downloadAndInstall();

    expect(gateway.installCalls, 0);
    expect(update.phase, UpdatePhase.error);
    expect(update.message, contains('签名'));
  });

  test('系统版本过低时不下载', () async {
    service.manifest = sampleManifest(versionCode: 3, minSdk: 99);
    final update = provider();
    await update.load();
    await update.check();

    await update.downloadAndInstall();

    expect(service.downloadCalls, 0);
    expect(update.phase, UpdatePhase.error);
    expect(update.message, contains('Android 99'));
  });

  test('跳过版本会持久化，回到前台发现已升级会清除提示', () async {
    service.manifest = sampleManifest(versionCode: 3);
    final update = provider();
    await update.load();
    await update.check();
    await update.skipVersion();

    expect(update.available, isNull);
    expect(prefs.getInt('update.skippedVersionCode'), 3);

    final afterSkip = provider();
    await afterSkip.load();
    expect(afterSkip.available, isNull);

    await update.check();
    expect(update.available, isNotNull);
    gateway.app = const InstalledApp(
      versionCode: 3,
      versionName: '1.2.0',
      packageName: 'com.qxyhappy.one_page_politics',
      sdkInt: 36,
    );
    await update.refreshInstalled();

    expect(update.available, isNull);
    expect(update.phase, UpdatePhase.upToDate);

    final afterUpgrade = provider();
    await afterUpgrade.load();
    expect(afterUpgrade.available, isNull);
  });
}
