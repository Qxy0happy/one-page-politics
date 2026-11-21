import 'dart:convert';

/// Release 目录中的 `update.json`，用于应用内更新检查。
class UpdateManifest {
  const UpdateManifest({
    required this.schemaVersion,
    required this.versionCode,
    required this.versionName,
    required this.minSdk,
    required this.publishedAt,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    required this.apkSha256,
  });

  static const int supportedSchemaVersion = 1;
  static const int maxApkSize = 250 * 1024 * 1024;

  final int schemaVersion;
  final int versionCode;
  final String versionName;
  final int minSdk;
  final DateTime publishedAt;
  final String notes;
  final Uri apkUrl;
  final int apkSize;
  final String apkSha256;

  String get sizeLabel => '${(apkSize / (1024 * 1024)).toStringAsFixed(1)} MB';

  bool isNewerThan(int installedVersionCode) =>
      versionCode > installedVersionCode;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'versionCode': versionCode,
    'versionName': versionName,
    'minSdk': minSdk,
    'publishedAt': publishedAt.toUtc().toIso8601String(),
    'notes': notes,
    'apk': {'url': apkUrl.toString(), 'size': apkSize, 'sha256': apkSha256},
  };

  static UpdateManifest parse(String text, {bool allowInsecure = false}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const UpdateManifestException('更新清单不是有效的 JSON');
    }
    if (decoded is! Map) {
      throw const UpdateManifestException('更新清单必须是 JSON 对象');
    }
    final map = Map<String, dynamic>.from(decoded);

    final schemaVersion = _int(map['schemaVersion'], 'schemaVersion');
    if (schemaVersion != supportedSchemaVersion) {
      throw UpdateManifestException('更新清单版本不兼容：$schemaVersion');
    }

    final versionCode = _int(map['versionCode'], 'versionCode');
    if (versionCode <= 0) {
      throw const UpdateManifestException('versionCode 必须大于 0');
    }

    final versionName = _string(map['versionName'], 'versionName').trim();
    if (versionName.isEmpty || versionName.length > 32) {
      throw const UpdateManifestException('versionName 为空或过长');
    }

    final minSdk = _int(map['minSdk'], 'minSdk');
    if (minSdk < 21) {
      throw const UpdateManifestException('minSdk 不得低于 21');
    }

    final publishedAt = DateTime.tryParse(
      _string(map['publishedAt'], 'publishedAt').trim(),
    );
    if (publishedAt == null) {
      throw const UpdateManifestException('publishedAt 不是有效时间');
    }

    final notes = map['notes'] == null
        ? ''
        : _string(map['notes'], 'notes').trim();
    if (notes.length > 2000) {
      throw const UpdateManifestException('更新说明过长');
    }

    final apkRaw = map['apk'];
    if (apkRaw is! Map) {
      throw const UpdateManifestException('更新清单缺少 apk 对象');
    }
    final apk = Map<String, dynamic>.from(apkRaw);
    final url = Uri.tryParse(_string(apk['url'], 'apk.url').trim());
    if (url == null || url.host.isEmpty) {
      throw const UpdateManifestException('apk.url 不是有效地址');
    }
    final scheme = url.scheme.toLowerCase();
    if (scheme != 'https' && !(allowInsecure && scheme == 'http')) {
      throw const UpdateManifestException('更新包地址必须使用 HTTPS');
    }

    final apkSize = _int(apk['size'], 'apk.size');
    if (apkSize <= 0 || apkSize > maxApkSize) {
      throw const UpdateManifestException('apk.size 超出允许范围');
    }

    final apkSha256 = _string(apk['sha256'], 'apk.sha256').trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(apkSha256)) {
      throw const UpdateManifestException('apk.sha256 格式不合法');
    }

    return UpdateManifest(
      schemaVersion: schemaVersion,
      versionCode: versionCode,
      versionName: versionName,
      minSdk: minSdk,
      publishedAt: publishedAt,
      notes: notes,
      apkUrl: url,
      apkSize: apkSize,
      apkSha256: apkSha256,
    );
  }

  static int _int(Object? value, String field) {
    if (value is! int) {
      throw UpdateManifestException('$field 必须是整数');
    }
    return value;
  }

  static String _string(Object? value, String field) {
    if (value is! String) {
      throw UpdateManifestException('$field 必须是字符串');
    }
    return value;
  }
}

class UpdateManifestException implements Exception {
  const UpdateManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}
