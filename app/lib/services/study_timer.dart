import 'package:shared_preferences/shared_preferences.dart';

class StudyTimer {
  StudyTimer({
    required this.key,
    required this.label,
    required this.duration,
    required this.prefs,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _load();
  }

  final String key;
  final String label;
  final Duration duration;
  final SharedPreferences prefs;
  final DateTime Function() _clock;

  late Duration _remaining;
  DateTime? _endAt;
  var _running = false;
  var _completed = false;

  Duration get remaining => _remaining;
  bool get isRunning => _running;
  bool get isCompleted => _completed;

  String get formatted {
    final total = _remaining.inSeconds.clamp(0, duration.inSeconds);
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _load() {
    final savedRemaining =
        prefs.getInt('timer.$key.remainingMs') ?? duration.inMilliseconds;
    _remaining = Duration(milliseconds: savedRemaining);
    _running = prefs.getBool('timer.$key.running') ?? false;
    _completed = prefs.getBool('timer.$key.completed') ?? false;
    final endAtMs = prefs.getInt('timer.$key.endAtMs');
    if (_running && endAtMs != null) {
      final endAt = DateTime.fromMillisecondsSinceEpoch(endAtMs);
      final left = endAt.difference(_clock());
      if (left <= Duration.zero) {
        _remaining = Duration.zero;
        _endAt = null;
        _running = false;
        _completed = true;
        _save();
      } else {
        _endAt = endAt;
        _remaining = left;
      }
    }
  }

  void start() {
    if (_running) return;
    if (_completed || _remaining <= Duration.zero) {
      _remaining = duration;
      _completed = false;
    }
    _endAt = _clock().add(_remaining);
    _running = true;
    _save();
  }

  void pause() {
    if (!_running) return;
    final left = _endAt?.difference(_clock());
    if (left == null || left <= Duration.zero) {
      _remaining = Duration.zero;
      _completed = true;
    } else {
      _remaining = left;
    }
    _endAt = null;
    _running = false;
    _save();
  }

  void reset() {
    _remaining = duration;
    _endAt = null;
    _running = false;
    _completed = false;
    _save();
  }

  /// 返回是否在本 tick 刚刚完成。
  bool tick() {
    if (!_running || _endAt == null) return false;
    final left = _endAt!.difference(_clock());
    if (left <= Duration.zero) {
      _remaining = Duration.zero;
      _running = false;
      _completed = true;
      _endAt = null;
      _save();
      return true;
    }
    _remaining = left;
    return false;
  }

  void _save() {
    prefs.setInt('timer.$key.remainingMs', _remaining.inMilliseconds);
    prefs.setBool('timer.$key.running', _running);
    prefs.setBool('timer.$key.completed', _completed);
    final endAt = _endAt;
    if (endAt == null) {
      prefs.remove('timer.$key.endAtMs');
    } else {
      prefs.setInt('timer.$key.endAtMs', endAt.millisecondsSinceEpoch);
    }
  }
}
