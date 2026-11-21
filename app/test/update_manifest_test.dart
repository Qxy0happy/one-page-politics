import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/update_manifest.dart';

void main() {
  Map<String, Object?> validMap() => {
    'schemaVersion': 1,
    'versionCode': 3,
    'versionName': '1.2.0',
    'minSdk': 24,
    'publishedAt': '2026-11-21T12:00:00Z',
    'notes': '内容更新与稳定性改进',
    'apk': {
      'url': 'https://github.com/Qxy0happy/one-page-politics/releases/download/v1.2.0/one-page-politics-1.2.0.apk',
      'size': 20260000,
      'sha256': List.filled(64, 'a').join(),
    },
  };

  test('解析完整清单', () {
    final manifest = UpdateManifest.parse(jsonEncode(validMap()));
    expect(manifest.versionCode, 3);
    expect(manifest.versionName, '1.2.0');
    expect(manifest.minSdk, 24);
    expect(manifest.notes, '内容更新与稳定性改进');
    expect(manifest.apkUrl.scheme, 'https');
    expect(manifest.apkSize, 20260000);
    expect(manifest.apkSha256, List.filled(64, 'a').join());
    expect(manifest.isNewerThan(2), isTrue);
    expect(manifest.isNewerThan(3), isFalse);
    expect(manifest.sizeLabel, '19.3 MB');
  });

  test('toJson 可被 parse 往返读取', () {
    final manifest = UpdateManifest.parse(jsonEncode(validMap()));
    final roundTrip = UpdateManifest.parse(jsonEncode(manifest.toJson()));
    expect(roundTrip.versionCode, manifest.versionCode);
    expect(roundTrip.versionName, manifest.versionName);
    expect(roundTrip.minSdk, manifest.minSdk);
    expect(roundTrip.publishedAt, manifest.publishedAt);
    expect(roundTrip.notes, manifest.notes);
    expect(roundTrip.apkUrl, manifest.apkUrl);
    expect(roundTrip.apkSize, manifest.apkSize);
    expect(roundTrip.apkSha256, manifest.apkSha256);
  });

  test('notes 可省略', () {
    final map = validMap()..remove('notes');
    expect(UpdateManifest.parse(jsonEncode(map)).notes, isEmpty);
  });

  test('schemaVersion 不兼容时报错', () {
    final map = validMap()..['schemaVersion'] = 2;
    expect(
      () => UpdateManifest.parse(jsonEncode(map)),
      throwsA(isA<UpdateManifestException>()),
    );
  });

  test('versionCode 必须为正整数', () {
    final map = validMap()..['versionCode'] = 0;
    expect(
      () => UpdateManifest.parse(jsonEncode(map)),
      throwsA(isA<UpdateManifestException>()),
    );
  });

  test('默认拒绝明文 HTTP，测试开关可放宽', () {
    final map = validMap();
    final apk = Map<String, Object?>.from(map['apk']! as Map);
    apk['url'] = 'http://example.com/app.apk';
    map['apk'] = apk;
    expect(
      () => UpdateManifest.parse(jsonEncode(map)),
      throwsA(isA<UpdateManifestException>()),
    );
    expect(
      UpdateManifest.parse(jsonEncode(map), allowInsecure: true).apkUrl.scheme,
      'http',
    );
  });

  test('SHA-256 必须为 64 位十六进制', () {
    final map = validMap();
    final apk = Map<String, Object?>.from(map['apk']! as Map);
    apk['sha256'] = 'abc';
    map['apk'] = apk;
    expect(
      () => UpdateManifest.parse(jsonEncode(map)),
      throwsA(isA<UpdateManifestException>()),
    );
  });

  test('APK 大小必须落在允许范围', () {
    final map = validMap();
    final apk = Map<String, Object?>.from(map['apk']! as Map);
    apk['size'] = UpdateManifest.maxApkSize + 1;
    map['apk'] = apk;
    expect(
      () => UpdateManifest.parse(jsonEncode(map)),
      throwsA(isA<UpdateManifestException>()),
    );
  });

  test('publishedAt 非法时报错', () {
    final map = validMap()..['publishedAt'] = '昨天';
    expect(
      () => UpdateManifest.parse(jsonEncode(map)),
      throwsA(isA<UpdateManifestException>()),
    );
  });

  test('非 JSON 对象时报错', () {
    expect(
      () => UpdateManifest.parse('[]'),
      throwsA(isA<UpdateManifestException>()),
    );
    expect(
      () => UpdateManifest.parse('{'),
      throwsA(isA<UpdateManifestException>()),
    );
  });
}
