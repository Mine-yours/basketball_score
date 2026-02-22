import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/action_type.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import '../models/mock_data.dart';
import 'game_provider.dart';
import 'period_provider.dart';

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

int _calculateScore(List<GameEvent>? events, TeamType team) {
  if (events == null) return 0;
  return events.where((e) => e.team == team).fold(0, (sum, e) {
    if (e.action == ActionType.p1Make) return sum + 1;
    if (e.action == ActionType.p2Make) return sum + 2;
    if (e.action == ActionType.p3Make) return sum + 3;
    return sum;
  });
}

final homeFoulsProvider = Provider<int>((ref) {
  final events = ref.watch(gameEventsProvider);
  final currentPeriod = ref.watch(currentPeriodProvider);
  final filtered = events.where((e) => e.period == currentPeriod).toList();
  return _calculateTeamFouls(filtered, TeamType.home);
});

final awayFoulsProvider = Provider<int>((ref) {
  final events = ref.watch(gameEventsProvider);
  final currentPeriod = ref.watch(currentPeriodProvider);
  final filtered = events.where((e) => e.period == currentPeriod).toList();
  return _calculateTeamFouls(filtered, TeamType.away);
});

int _calculateTeamFouls(List<GameEvent>? events, TeamType team) {
  if (events == null) return 0;
  return events.where((e) => e.team == team && e.action == ActionType.foul).length;
}

class PlayerStats {
  final int pts;
  final int fgm;
  final int fga;
  final int p2m;
  final int p2a;
  final int p3m;
  final int p3a;
  final int ftm;
  final int fta;
  final int oreb;
  final int dreb;
  final int treb;
  final int ast;
  final int stl;
  final int blk;
  final int turnover;
  final int fouls;

  PlayerStats({
    required this.pts,
    required this.fgm,
    required this.fga,
    required this.p2m,
    required this.p2a,
    required this.p3m,
    required this.p3a,
    required this.ftm,
    required this.fta,
    required this.oreb,
    required this.dreb,
    required this.treb,
    required this.ast,
    required this.stl,
    required this.blk,
    required this.turnover,
    required this.fouls,
  });
}

final playerStatsProvider = Provider.family<PlayerStats, String>((ref, playerId) {
  final events = ref.watch(gameEventsProvider);
  final filter = ref.watch(displayPeriodFilterProvider);
  final filtered = filter == 'ALL' ? events : events.where((e) => e.period == filter).toList();
  
  int pts = 0;
  int p2m = 0, p2a = 0;
  int p3m = 0, p3a = 0;
  int ftm = 0, fta = 0;
  int oreb = 0, dreb = 0;
  int ast = 0, stl = 0, blk = 0, to = 0, fouls = 0;

  for (final e in filtered) {
    if (e.playerId == playerId) {
      switch (e.action) {
        case ActionType.p2Make:
          pts += 2; p2m++; p2a++; break;
        case ActionType.p2Miss:
          p2a++; break;
        case ActionType.p3Make:
          pts += 3; p3m++; p3a++; break;
        case ActionType.p3Miss:
          p3a++; break;
        case ActionType.p1Make:
          pts += 1; ftm++; fta++; break;
        case ActionType.p1Miss:
          fta++; break;
        case ActionType.or:
          oreb++; break;
        case ActionType.dr:
          dreb++; break;
        case ActionType.steal:
          stl++; break;
        case ActionType.block:
          blk++; break;
        case ActionType.turnover:
          to++; break;
        case ActionType.foul:
          fouls++; break;
        default:
          break;
      }
    }
    // Assist check (playerId is the one making the shot, assistPlayerId is the assistant)
    if (e.assistPlayerId == playerId) {
      ast++;
    }
  }

  return PlayerStats(
    pts: pts,
    fgm: p2m + p3m,
    fga: p2a + p3a,
    p2m: p2m,
    p2a: p2a,
    p3m: p3m,
    p3a: p3a,
    ftm: ftm,
    fta: fta,
    oreb: oreb,
    dreb: dreb,
    treb: oreb + dreb,
    ast: ast,
    stl: stl,
    blk: blk,
    turnover: to,
    fouls: fouls,
  );
});

final lineScoreProvider = Provider<Map<String, Map<String, int>>>((ref) {
  final events = ref.watch(gameEventsProvider);
  final periods = ref.watch(availablePeriodsProvider);
  
  final Map<String, Map<String, int>> scores = {
    'home': {},
    'away': {},
  };

  for (final p in periods) {
    scores['home']![p] = _calculateScore(events.where((e) => e.period == p).toList(), TeamType.home);
    scores['away']![p] = _calculateScore(events.where((e) => e.period == p).toList(), TeamType.away);
  }

  return scores;
});
