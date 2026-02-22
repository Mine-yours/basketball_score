import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/action_type.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import '../models/mock_data.dart';
import 'game_provider.dart';

// Player Management
class HomeTeamPlayersNotifier extends Notifier<List<Player>> {
  @override
  List<Player> build() => mockHomeTeam;

  void toggleCourtStatus(String playerId) {
    state = state.map((p) {
      if (p.id == playerId) {
        return p.copyWith(isOnCourt: !p.isOnCourt);
      }
      return p;
    }).toList();
  }
}

class AwayTeamPlayersNotifier extends Notifier<List<Player>> {
  @override
  List<Player> build() => mockAwayTeam;

  void toggleCourtStatus(String playerId) {
    state = state.map((p) {
      if (p.id == playerId) {
        return p.copyWith(isOnCourt: !p.isOnCourt);
      }
      return p;
    }).toList();
  }
}

final homeTeamPlayersProvider = NotifierProvider<HomeTeamPlayersNotifier, List<Player>>(HomeTeamPlayersNotifier.new);

final awayTeamPlayersProvider = NotifierProvider<AwayTeamPlayersNotifier, List<Player>>(AwayTeamPlayersNotifier.new);

final onCourtHomePlayersProvider = Provider<List<Player>>((ref) {
  return ref.watch(homeTeamPlayersProvider).where((p) => p.isOnCourt).toList();
});

final onCourtAwayPlayersProvider = Provider<List<Player>>((ref) {
  return ref.watch(awayTeamPlayersProvider).where((p) => p.isOnCourt).toList();
});

// Stats Derivation
final homeScoreProvider = Provider<int>((ref) {
  final events = ref.watch(gameEventsProvider);
  return _calculateScore(events, TeamType.home);
});

final awayScoreProvider = Provider<int>((ref) {
  final events = ref.watch(gameEventsProvider);
  return _calculateScore(events, TeamType.away);
});

int _calculateScore(List<GameEvent> events, TeamType team) {
  return events.where((e) => e.team == team).fold(0, (sum, e) {
    if (e.action == ActionType.p1Make) return sum + 1;
    if (e.action == ActionType.p2Make) return sum + 2;
    if (e.action == ActionType.p3Make) return sum + 3;
    return sum;
  });
}

final homeFoulsProvider = Provider<int>((ref) {
  final events = ref.watch(gameEventsProvider);
  return _calculateTeamFouls(events, TeamType.home);
});

final awayFoulsProvider = Provider<int>((ref) {
  final events = ref.watch(gameEventsProvider);
  return _calculateTeamFouls(events, TeamType.away);
});

int _calculateTeamFouls(List<GameEvent> events, TeamType team) {
  return events.where((e) => e.team == team && e.action == ActionType.foul).length;
}

class PlayerStats {
  final int points;
  final int fouls;
  PlayerStats({required this.points, required this.fouls});
}

final playerStatsProvider = Provider.family<PlayerStats, String>((ref, playerId) {
  final events = ref.watch(gameEventsProvider);
  int pts = 0;
  int fouls = 0;

  for (final e in events.where((e) => e.playerId == playerId)) {
    if (e.action == ActionType.p1Make) pts += 1;
    if (e.action == ActionType.p2Make) pts += 2;
    if (e.action == ActionType.p3Make) pts += 3;
    if (e.action == ActionType.foul) fouls += 1;
  }

  return PlayerStats(points: pts, fouls: fouls);
});
