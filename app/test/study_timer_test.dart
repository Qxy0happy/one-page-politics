import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/services/study_timer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('墙钟计时：开始、暂停、完成、重置', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 1, 1, 8);
    final timer = StudyTimer(
      key: 'test',
      label: '测试',
      duration: const Duration(minutes: 30),
      prefs: prefs,
      clock: () => now,
    );

    expect(timer.formatted, '30:00');
    timer.start();
    now = now.add(const Duration(minutes: 5));
    expect(timer.tick(), isFalse);
    expect(timer.remaining.inMinutes, 25);
    timer.pause();
    final paused = timer.remaining;
    now = now.add(const Duration(minutes: 10));
    expect(timer.tick(), isFalse);
    expect(timer.remaining, paused);

    timer.start();
    now = now.add(const Duration(minutes: 30));
    expect(timer.tick(), isTrue);
    expect(timer.isCompleted, isTrue);
    expect(timer.formatted, '00:00');

    timer.reset();
    expect(timer.isCompleted, isFalse);
    expect(timer.formatted, '30:00');
  });

  test('重启恢复：运行中的 endAt 与暂停后的 remaining', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 1, 1, 8);
    final timer = StudyTimer(
      key: 'restore',
      label: '恢复',
      duration: const Duration(minutes: 30),
      prefs: prefs,
      clock: () => now,
    );

    timer.start();
    now = now.add(const Duration(minutes: 7));
    final running = StudyTimer(
      key: 'restore',
      label: '恢复',
      duration: const Duration(minutes: 30),
      prefs: prefs,
      clock: () => now,
    );
    expect(running.isRunning, isTrue);
    expect(running.remaining.inMinutes, 23);

    running.pause();
    now = now.add(const Duration(minutes: 4));
    final paused = StudyTimer(
      key: 'restore',
      label: '恢复',
      duration: const Duration(minutes: 30),
      prefs: prefs,
      clock: () => now,
    );
    expect(paused.isRunning, isFalse);
    expect(paused.remaining.inMinutes, 23);
  });

  test('应用关闭期间到期：下次打开标记完成', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 1, 1, 8);
    final timer = StudyTimer(
      key: 'expire',
      label: '到期',
      duration: const Duration(minutes: 30),
      prefs: prefs,
      clock: () => now,
    );
    timer.start();
    now = now.add(const Duration(minutes: 31));
    final restored = StudyTimer(
      key: 'expire',
      label: '到期',
      duration: const Duration(minutes: 30),
      prefs: prefs,
      clock: () => now,
    );
    expect(restored.isCompleted, isTrue);
    expect(restored.isRunning, isFalse);
    expect(restored.formatted, '00:00');
  });
}
