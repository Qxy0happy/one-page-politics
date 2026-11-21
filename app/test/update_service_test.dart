import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/update_manifest.dart';
import 'package:one_page_politics/services/update_service.dart';

import 'support/update_fakes.dart';

void main() {
  final bytes = List<int>.generate(4096, (index) => index % 251);
  final hash = List.filled(64, 'a').join();
  final requests = <String>[];

  late HttpServer server;
  late Directory tempDir;
  late FakeUpdateGateway gateway;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    tempDir = await Directory.systemTemp.createTemp('update-service-test');
    gateway = FakeUpdateGateway();
    requests.clear();
  });

  tearDown(() async {
    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  Uri apkUrl() => Uri.parse('http://127.0.0.1:${server.port}/app.apk');
  Uri manifestUrl() => Uri.parse('http://127.0.0.1:${server.port}/update.json');

  UpdateManifest manifest() => UpdateManifest(
    schemaVersion: 1,
    versionCode: 3,
    versionName: '1.2.0',
    minSdk: 24,
    publishedAt: DateTime.utc(2026, 11, 21),
    notes: '',
    apkUrl: apkUrl(),
    apkSize: bytes.length,
    apkSha256: hash,
  );

  Map<String, Object?> manifestJson() => {
    'schemaVersion': 1,
    'versionCode': 3,
    'versionName': '1.2.0',
    'minSdk': 24,
    'publishedAt': '2026-11-21T12:00:00Z',
    'notes': '内容更新与稳定性改进',
    'apk': {'url': apkUrl().toString(), 'size': bytes.length, 'sha256': hash},
  };

  void serveManifest(String body, {int status = HttpStatus.ok}) {
    server.listen((request) async {
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(body);
      await request.response.close();
    });
  }

  void serveApk({
    bool honorRange = true,
    bool split = false,
    Future<void>? secondChunkGate,
  }) {
    server.listen((request) async {
      if (request.uri.path != '/app.apk') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final range = request.headers.value(HttpHeaders.rangeHeader);
      requests.add(range ?? 'none');
      var start = 0;
      if (honorRange && range != null) {
        start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${bytes.length - 1}/${bytes.length}',
        );
      }
      request.response.bufferOutput = false;
      final payload = bytes.sublist(start);
      if (split) {
        final half = payload.length ~/ 2;
        request.response.add(payload.sublist(0, half));
        await request.response.flush();
        if (secondChunkGate != null) await secondChunkGate;
        request.response.add(payload.sublist(half));
      } else {
        request.response.add(payload);
      }
      await request.response.close();
    });
  }

  test('拉取并解析更新清单', () async {
    serveManifest(jsonEncode(manifestJson()));
    final service = UpdateService(
      gateway: gateway,
      manifestUrl: manifestUrl(),
      allowInsecure: true,
    );
    final result = await service.fetchManifest();
    expect(result.versionCode, 3);
    expect(result.versionName, '1.2.0');
    expect(result.apkSize, bytes.length);
  });

  test('清单 HTTP 错误转换为可读错误', () async {
    serveManifest('oops', status: HttpStatus.internalServerError);
    final service = UpdateService(
      gateway: gateway,
      manifestUrl: manifestUrl(),
      allowInsecure: true,
    );
    await expectLater(
      service.fetchManifest(),
      throwsA(isA<UpdateServiceException>()),
    );
  });

  test('清单不是有效 JSON 时报错', () async {
    serveManifest('not json');
    final service = UpdateService(
      gateway: gateway,
      manifestUrl: manifestUrl(),
      allowInsecure: true,
    );
    await expectLater(
      service.fetchManifest(),
      throwsA(isA<UpdateServiceException>()),
    );
  });

  test('从头下载并写入目标文件', () async {
    serveApk();
    final service = UpdateService(gateway: gateway);
    final target = await service.downloadApk(
      manifest: manifest(),
      directory: tempDir,
    );

    expect(await target.readAsBytes(), bytes);
    expect(target.path, endsWith('update-3.apk'));
    expect(requests, ['none']);
    expect(gateway.verifyCalls, 1);
  });

  test('已有 part 文件时使用 Range 续传', () async {
    serveApk();
    final service = UpdateService(gateway: gateway);
    final part = File('${tempDir.path}/update-3.apk.part');
    await part.writeAsBytes(bytes.sublist(0, 1000));

    final target = await service.downloadApk(
      manifest: manifest(),
      directory: tempDir,
    );

    expect(await target.readAsBytes(), bytes);
    expect(requests, ['bytes=1000-']);
    expect(await part.exists(), isFalse);
  });

  test('服务端忽略 Range 时从头重写，不拼接重复字节', () async {
    serveApk(honorRange: false);
    final service = UpdateService(gateway: gateway);
    final part = File('${tempDir.path}/update-3.apk.part');
    await part.writeAsBytes(bytes.sublist(0, 1000));

    final target = await service.downloadApk(
      manifest: manifest(),
      directory: tempDir,
    );

    expect(await target.readAsBytes(), bytes);
    expect(requests, ['bytes=1000-']);
  });

  test('416 时删除失效的 part 并报错', () async {
    server.listen((request) async {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await request.response.close();
    });
    final service = UpdateService(gateway: gateway);
    final part = File('${tempDir.path}/update-3.apk.part');
    await part.writeAsBytes(bytes.sublist(0, 1000));

    await expectLater(
      service.downloadApk(manifest: manifest(), directory: tempDir),
      throwsA(isA<UpdateServiceException>()),
    );
    expect(await part.exists(), isFalse);
  });

  test('取消后保留已写入的 part，便于下次续传', () async {
    final releaseSecondChunk = Completer<void>();
    var cancel = false;
    serveApk(split: true, secondChunkGate: releaseSecondChunk.future);
    final service = UpdateService(gateway: gateway);
    final part = File('${tempDir.path}/update-3.apk.part');

    await expectLater(
      service.downloadApk(
        manifest: manifest(),
        directory: tempDir,
        onProgress: (received, total) {
          cancel = true;
          if (!releaseSecondChunk.isCompleted) {
            releaseSecondChunk.complete();
          }
        },
        isCancelled: () => cancel,
      ),
      throwsA(isA<UpdateCancelled>()),
    );

    expect(await part.exists(), isTrue);
    expect(await part.length(), greaterThan(0));
    expect(await part.length(), lessThan(bytes.length));
  });
}
