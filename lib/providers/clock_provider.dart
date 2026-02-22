import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameClockNotifier extends Notifier<int> {
  // remaining seconds in quarter (e.g. 600 = 10:00)
  @override
  int build() => 600;

  void tick() {
    if (state > 0) state--;
  }

  void reset(int seconds) {
    state = seconds;
  }
}

class IsClockRunningNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

final gameClockProvider = NotifierProvider<GameClockNotifier, int>(GameClockNotifier.new);
final isClockRunningProvider = NotifierProvider<IsClockRunningNotifier, bool>(IsClockRunningNotifier.new);
