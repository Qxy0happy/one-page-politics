import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/update_manifest.dart';
import 'update_gateway.dart';

const String kDefaultUpdateManifestUrl = String.fromEnvironment(
  'UPDATE_MANIFEST_URL',
  defaultValue: 'https://github.com/Qxy0happy/one-page-politics/releases/latest/download/update.json',
);

const bool kAllowInsecureUpdate = bool.fromEnvironment('ALLOW_INSECURE_UPDATE');

class UpdateServiceException implements Exception {
  const UpdateServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

class UpdateService {
  UpdateService({
    required this.gateway,
    Uri? manifestUrl,
    HttpClient Function()? httpClientFactory,
    this.allowInsecure = false,
  }) : manifestUrl = manifestUrl ?? Uri.parse(kDefaultUpdateManifestUrl),
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final UpdateGateway gateway;
  final Uri manifestUrl;
  final bool allowInsecure;
  final HttpClient Function() _httpClientFactory;

  Future<UpdateManifest> fetchManifest() async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .getUrl(manifestUrl)
          .timeout(const Duration(seconds: 15));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'one-page-politics-updater/1.0',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw UpdateServiceException('更新服务器返回 HTTP ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > 256 * 1024) {
          throw const UpdateServiceException('更新清单过大');
        }
      }
      return UpdateManifest.parse(
        utf8.decode(bytes, allowMalformed: true),
        allowInsecure: allowInsecure,
      );
    } on UpdateManifestException catch (error) {
      throw UpdateServiceException(error.message);
    } on SocketException {
      throw const UpdateServiceException('无法连接更新服务器，请检查网络');
    } on TimeoutException {
      throw const UpdateServiceException('连接更新服务器超时');
    } on HttpException catch (error) {
      throw UpdateServiceException('读取更新清单失败：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  /// 下载 APK；`update-<versionCode>.apk.part` 已存在时用 Range 续传。
  ///
  /// 返回的文件尚未做最终 SHA-256/签名校验，调用方应在安装前再校验一次。
  Future<File> downloadApk({
    required UpdateManifest manifest,
    required Directory directory,
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await directory.create(recursive: true);
    final baseName = 'update-${manifest.versionCode}';
    final target = File(
      '${directory.path}${Platform.pathSeparator}$baseName.apk',
    );
    final part = File('${target.path}.part');

    await _removeStaleDownloads(directory, baseName);

    if (await target.exists()) {
      final result = await gateway.verifyApk(
        path: target.path,
        sha256: manifest.apkSha256,
        versionCode: manifest.versionCode,
      );
      if (result.ok) return target;
      await _deleteQuietly(target);
    }

    var offset = 0;
    if (await part.exists()) {
      offset = await part.length();
      if (offset > manifest.apkSize) {
        await _deleteQuietly(part);
        offset = 0;
      } else if (offset == manifest.apkSize) {
        final result = await gateway.verifyApk(
          path: part.path,
          sha256: manifest.apkSha256,
          versionCode: manifest.versionCode,
        );
        if (result.ok) {
          await _promote(part, target);
          return target;
        }
        await _deleteQuietly(part);
        offset = 0;
      }
    }

    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 15)
      ..autoUncompress = false;
    try {
      final request = await client
          .getUrl(manifest.apkUrl)
          .timeout(const Duration(seconds: 20));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'one-page-politics-updater/1.0',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final status = response.statusCode;
      if (status == HttpStatus.requestedRangeNotSatisfiable) {
        await response.drain<void>();
        await _deleteQuietly(part);
        throw const UpdateServiceException('断点位置已失效，请重试');
      }
      final append = offset > 0 && status == HttpStatus.partialContent;
      if (!append && status != HttpStatus.ok) {
        await response.drain<void>();
        throw UpdateServiceException('下载失败（HTTP $status）');
      }
      if (!append) offset = 0;

      final contentLength = response.contentLength;
      if (contentLength > 0 && offset + contentLength != manifest.apkSize) {
        await response.drain<void>();
        throw const UpdateServiceException('更新包大小与清单不一致');
      }

      final raf = await part.open(
        mode: append ? FileMode.append : FileMode.write,
      );
      var received = offset;
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 60),
        )) {
          if (isCancelled?.call() ?? false) {
            throw const UpdateCancelled();
          }
          await raf.writeFrom(chunk);
          received += chunk.length;
          if (received > manifest.apkSize) {
            throw const UpdateServiceException('更新包超出清单大小');
          }
          onProgress?.call(received, manifest.apkSize);
        }
        await raf.flush();
      } finally {
        await raf.close();
      }
      if (received != manifest.apkSize) {
        throw UpdateServiceException('下载未完成（$received/${manifest.apkSize} 字节）');
      }
    } on UpdateCancelled {
      rethrow;
    } on UpdateServiceException {
      rethrow;
    } on SocketException {
      throw const UpdateServiceException('网络连接中断，可重试继续下载');
    } on TimeoutException {
      throw const UpdateServiceException('下载超时，可重试继续下载');
    } on HttpException catch (error) {
      throw UpdateServiceException('下载失败：${error.message}');
    } finally {
      client.close(force: true);
    }

    final verified = await gateway.verifyApk(
      path: part.path,
      sha256: manifest.apkSha256,
      versionCode: manifest.versionCode,
    );
    if (!verified.ok) {
      await _deleteQuietly(part);
      throw UpdateServiceException(verified.message);
    }
    await _promote(part, target);
    return target;
  }

  Future<void> _removeStaleDownloads(
    Directory directory,
    String baseName,
  ) async {
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!name.startsWith('update-')) continue;
      if (name.startsWith('$baseName.')) continue;
      await _deleteQuietly(entity);
    }
  }

  Future<void> _promote(File part, File target) async {
    if (await target.exists()) {
      await target.delete();
    }
    await part.rename(target.path);
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // 清理失败不影响下一次下载；下次启动会再次尝试。
    }
  }
}
