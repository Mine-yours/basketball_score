import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/action_type.dart';
import '../../models/game_event.dart';
import '../../providers/game_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/pending_action_provider.dart';
import '../../models/player.dart';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

class SelectedPlayerNotifier extends Notifier<Player?> {
  @override
  Player? build() => null;
}
final selectedPlayerProvider = NotifierProvider<SelectedPlayerNotifier, Player?>(SelectedPlayerNotifier.new);

class IsSubstitutionModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}
final isSubstitutionModeProvider = NotifierProvider<IsSubstitutionModeNotifier, bool>(IsSubstitutionModeNotifier.new);

class SubstitutionTargetNotifier extends Notifier<Player?> {
  @override
  Player? build() => null;
}
final substitutionTargetProvider = NotifierProvider<SubstitutionTargetNotifier, Player?>(SubstitutionTargetNotifier.new);

class PlayerList extends ConsumerWidget {
  final TeamType team;
  const PlayerList({super.key, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubMode = ref.watch(isSubstitutionModeProvider);
    final allPlayers = team == TeamType.home 
        ? ref.watch(homeTeamPlayersProvider) 
        : ref.watch(awayTeamPlayersProvider);
    
    final players = isSubMode ? allPlayers : allPlayers.where((p) => p.isOnCourt).toList();
    final selectedPlayer = ref.watch(selectedPlayerProvider);
    final subTarget = ref.watch(substitutionTargetProvider);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
             padding: const EdgeInsets.all(8),
             color: team == TeamType.home ? Colors.blue.withOpacity(0.2) : Colors.red.withOpacity(0.2),
             child: const Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [Text('Num'), Text('Name'), Text('Pts/F')],
             ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
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
                      _handleActionTap(ref, player);
                    }
                  }
                );
              },
            ),
          ),
          if (!isSubMode) _TeamActionTile(team: team),
        ],
      ),
    );
  }

  void _handleActionTap(WidgetRef ref, Player player) {
    final pendingAction = ref.read(pendingActionProvider);
    final pendingShot = ref.read(pendingShotLocationProvider);
    
    if (pendingAction != null) {
      // Execute the pending action immediately
      final event = GameEvent(
        id: uuid.v4(),
        timestamp: DateTime.now(),
        gameClock: '10:00', // To be hooked to clock provider later
        period: 'Q1',
        team: player.team,
        playerId: player.id,
        action: pendingAction,
      );
      ref.read(gameEventsProvider.notifier).addEvent(event);
      ref.read(pendingActionProvider.notifier).state = null;
    } else if (pendingShot != null) {
      // Set the player, and let the court area modal know to open (could be handled via a global provider/event bus, or we simply select the player here)
      // For simplicity, just select the player and the user still needs to click the court, OR we trigger the modal.
      // Easiest is to set selected player.
      ref.read(selectedPlayerProvider.notifier).state = player;
    } else {
      final selectedPlayer = ref.read(selectedPlayerProvider);
      if (selectedPlayer?.id == player.id) {
        ref.read(selectedPlayerProvider.notifier).state = null;
      } else {
        ref.read(selectedPlayerProvider.notifier).state = player;
      }
    }
  }

  void _handleSubTap(WidgetRef ref, Player player, TeamType team) {
    final subTarget = ref.read(substitutionTargetProvider);
    
    if (subTarget == null) {
      if (player.team == team) {
        ref.read(substitutionTargetProvider.notifier).state = player;
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
        ref.read(substitutionTargetProvider.notifier).state = null;
      } else {
        // Change target
        ref.read(substitutionTargetProvider.notifier).state = player;
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
    final stats = ref.watch(playerStatsProvider(player.id));
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : 
                 (isSubMode && !player.isOnCourt ? Colors.grey[800] : null),
          border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(player.number, style: TextStyle(fontWeight: FontWeight.bold, color: isSubMode && !player.isOnCourt ? Colors.grey : null)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(player.name, style: TextStyle(color: isSubMode && !player.isOnCourt ? Colors.grey : null))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${stats.points} / ${stats.fouls}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
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
        ref.read(selectedPlayerProvider.notifier).state = dummyPlayer;
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Text('TEAM', style: TextStyle(fontWeight: FontWeight.bold))),
      ),
    );
  }
}
