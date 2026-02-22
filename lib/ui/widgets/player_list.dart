import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/action_type.dart';
import '../../models/game_event.dart';
import '../../providers/game_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/period_provider.dart';
import '../../providers/clock_provider.dart';
import '../../models/player.dart';
import 'package:uuid/uuid.dart';
import 'court_area.dart';
import 'action_pad.dart';

const uuid = Uuid();

class PlayerList extends ConsumerWidget {
  final TeamType team;
  const PlayerList({super.key, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubMode = ref.watch(isSubstitutionModeProvider);
    final allPlayers = team == TeamType.home 
        ? ref.watch(homeTeamPlayersProvider) 
        : ref.watch(awayTeamPlayersProvider);
    
    final selectedPlayer = ref.watch(selectedPlayerProvider);
    final subTarget = ref.watch(substitutionTargetProvider);

    final List<Player> players = (isSubMode 
        ? allPlayers.toList() 
        : allPlayers.where((p) => p.isOnCourt).toList())
      ..sort((a, b) => int.parse(a.number).compareTo(int.parse(b.number)));
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: isSubMode ? Colors.orange : (team == TeamType.home ? Colors.blue[900] : Colors.red[900]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(team.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('PTS  FOUL', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: players.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final player = players[index];
              final isSelected = isSubMode ? subTarget?.id == player.id : selectedPlayer?.id == player.id;
              
              return _PlayerListTile(
                player: player,
                isSelected: isSelected,
                isSubMode: isSubMode,
                onTap: () {
                  if (isSubMode) {
                    _handleSubTap(ref, player, team);
                  } else {
                    _handleActionTap(ref, player, context);
                  }
                }
              );
            },
          ),
        ),
        _TeamActionTile(team: team),
      ],
    );
  }

  void _handleActionTap(WidgetRef ref, Player player, BuildContext context) async {
    final pendingAction = ref.read(pendingActionProvider);
    final pendingShot = ref.read(pendingShotLocationProvider);
    
    if (pendingAction != null) {
      ActionType action = pendingAction;
      
      // In Reverse Flow, we must set the selected player BEFORE calling handlers
      // so they can access it, and it also updates the UI to show who was picked.
      ref.read(selectedPlayerProvider.notifier).setPlayer(player);

      if (action == ActionType.reb) {
        handleRebound(ref, context);
        return;
      }
      
      if (action == ActionType.ft) {
        startFTSet(context, ref);
        return;
      }

      if (action == ActionType.putback) {
        handlePutback(ref, context);
        return;
      }

      handleAction(ref, action, context);
      return;
    } else if (pendingShot != null) {
      final x = pendingShot.x;
      final y = pendingShot.y;

      final is3P = pendingShot.is3P;
      final isPaint = (x < 0.2 || x > 0.8) && (y > 0.3 && y < 0.7);

      final shotType = await showShotResultDialog(context, isPaint);
      if (shotType == null) return;

      final isMake = shotType == 'MAKE' || shotType == 'LAYUP' || shotType == 'DUNK';
      
      String? assistPlayerId;
      if (isMake) {
        assistPlayerId = await showAssistDialog(context, ref, player.team, player.id);
      }
      
      ActionType action;
      if (shotType == 'LAYUP' || shotType == 'DUNK') {
        action = ActionType.p2Make;
      } else if (is3P) {
        action = isMake ? ActionType.p3Make : ActionType.p3Miss;
      } else {
        action = isMake ? ActionType.p2Make : ActionType.p2Miss;
      }

      final period = ref.read(currentPeriodProvider);
      final clockSeconds = ref.read(gameClockProvider);
      final m = clockSeconds ~/ 60;
      final s = clockSeconds % 60;
      final gameClock = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

      final event = GameEvent(
        id: uuid.v4(),
        timestamp: DateTime.now(),
        gameClock: gameClock,
        period: period,
        team: player.team,
        playerId: player.id,
        action: action,
        x: x,
        y: y,
        assistPlayerId: assistPlayerId,
      );

      ref.read(gameEventsProvider.notifier).addEvent(event);
      ref.read(pendingShotLocationProvider.notifier).setLocation(null);
    } else {
      final selectedPlayer = ref.read(selectedPlayerProvider);
      if (selectedPlayer?.id == player.id) {
        ref.read(selectedPlayerProvider.notifier).setPlayer(null);
      } else {
        ref.read(selectedPlayerProvider.notifier).setPlayer(player);
      }
    }
  }

  void _handleSubTap(WidgetRef ref, Player player, TeamType team) {
    final subTarget = ref.read(substitutionTargetProvider);
    
    if (subTarget == null) {
      if (player.team == team) {
        ref.read(substitutionTargetProvider.notifier).setPlayer(player);
      }
    } else {
      if (subTarget.team == player.team && subTarget.id != player.id && subTarget.isOnCourt != player.isOnCourt) {
        // Perform swap
        if (player.team == TeamType.home) {
            ref.read(homeTeamPlayersProvider.notifier).toggleCourtStatus(subTarget.id);
            ref.read(homeTeamPlayersProvider.notifier).toggleCourtStatus(player.id);
        } else {
            ref.read(awayTeamPlayersProvider.notifier).toggleCourtStatus(subTarget.id);
            ref.read(awayTeamPlayersProvider.notifier).toggleCourtStatus(player.id);
        }
        ref.read(substitutionTargetProvider.notifier).setPlayer(null);
      } else {
        // Change target
        ref.read(substitutionTargetProvider.notifier).setPlayer(player);
      }
    }
  }
}

class _PlayerListTile extends ConsumerWidget {
  final Player player;
  final bool isSelected;
  final bool isSubMode;
  final VoidCallback onTap;

  const _PlayerListTile({
    required this.player,
    required this.isSelected,
    required this.isSubMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerStats = ref.watch(playerStatsProvider(player.id));

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: isSelected 
            ? (isSubMode ? Colors.orange.withAlpha(128) : Theme.of(context).colorScheme.primaryContainer) 
            : (player.isOnCourt ? null : Colors.grey.withAlpha(50)),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                player.number,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: player.isOnCourt ? null : Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                player.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: player.isOnCourt ? null : Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            if (playerStats != null) ...[
              SizedBox(
                width: 30,
                child: Center(
                  child: Text(
                    '${playerStats.points}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Center(
                  child: Text(
                    '${playerStats.fouls}',
                    style: TextStyle(
                      color: playerStats.fouls >= 5 ? Colors.red : (playerStats.fouls >= 4 ? Colors.orange : null),
                      fontWeight: playerStats.fouls >= 4 ? FontWeight.bold : null,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamActionTile extends ConsumerWidget {
  final TeamType team;
  const _TeamActionTile({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(selectedPlayerProvider)?.id == 'TEAM_${team.name}';
    
    return InkWell(
      onTap: () {
        final dummyPlayer = Player(
          id: 'TEAM_${team.name}',
          number: '-',
          name: 'TEAM',
          team: team,
          isOnCourt: true,
        );
        ref.read(selectedPlayerProvider.notifier).setPlayer(dummyPlayer);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Text('TEAM', style: TextStyle(fontWeight: FontWeight.bold))),
      ),
    );
  }
}
