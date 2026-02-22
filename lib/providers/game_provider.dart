import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_event.dart';

class GameEventNotifier extends Notifier<List<GameEvent>> {
  static const _prefsKey = 'game_events_v1';
  late SharedPreferences _prefs;

  @override
  List<GameEvent> build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _loadEvents();
  }

  List<GameEvent> _loadEvents() {
    final String? eventsJson = _prefs.getString(_prefsKey);
    if (eventsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(eventsJson);
        return decoded.map((e) => GameEvent.fromJson(e)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  Future<void> _saveEvents(List<GameEvent> newEvents) async {
    final String eventsJson = jsonEncode(newEvents.map((e) => e.toJson()).toList());
    await _prefs.setString(_prefsKey, eventsJson);
  }

  void addEvent(GameEvent event) {
    final newState = [...state, event];
    state = newState;
    _saveEvents(newState);
  }

  void undoLastEvent() {
    if (state.isNotEmpty) {
      final newState = List<GameEvent>.from(state)..removeLast();
      state = newState;
      _saveEvents(newState);
    }
  }

  void clearEvents() {
    state = [];
    _prefs.remove(_prefsKey);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize shared_preferences in main.dart first');
});

final gameEventsProvider = NotifierProvider<GameEventNotifier, List<GameEvent>>(() {
  return GameEventNotifier();
});
