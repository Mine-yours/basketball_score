import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../models/action_type.dart';
import '../../models/game_event.dart';
import '../../providers/game_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/period_provider.dart';
import '../../providers/clock_provider.dart';

const uuid = Uuid();

class ActionPad extends ConsumerWidget {
  const ActionPad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAction = ref.watch(pendingActionProvider);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildActionButton(context, ref, 'Rebound', LucideIcons.circleDashed, () => handleRebound(ref, context), isActive: pendingAction == ActionType.dr || pendingAction == ActionType.or || pendingAction == ActionType.reb),
                _buildActionButton(context, ref, 'Foul', LucideIcons.alertCircle, () => handleAction(ref, ActionType.foul, context), isActive: pendingAction == ActionType.foul),
                _buildActionButton(context, ref, 'Turnover', LucideIcons.xCircle, () => handleAction(ref, ActionType.turnover, context), isActive: pendingAction == ActionType.turnover),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildActionButton(context, ref, 'Steal', LucideIcons.mousePointerClick, () => handleAction(ref, ActionType.steal, context), isActive: pendingAction == ActionType.steal),
                _buildActionButton(context, ref, 'Block', LucideIcons.hand, () => handleAction(ref, ActionType.block, context), isActive: pendingAction == ActionType.block),
                _buildActionButton(context, ref, 'PUTBACK', LucideIcons.trendingUp, () => handlePutback(ref, context), color: Colors.indigo, isActive: pendingAction == ActionType.putback),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildActionButton(context, ref, 'FT SET', LucideIcons.list, () => startFTSet(context, ref), color: Colors.deepPurple, isActive: pendingAction == ActionType.ft),
                _buildUndoButton(context, ref),
                const Spacer(), // Keep layout balanced or add another button later
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, String label, IconData icon, VoidCallback? onTap, {Color? color, bool isActive = false, bool isDisabled = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Opacity(
          opacity: isDisabled ? 0.4 : 1.0,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? Colors.amber : (color ?? Theme.of(context).colorScheme.surfaceContainerHighest),
            foregroundColor: isActive ? Colors.black : (color != null ? Colors.white : null),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isActive ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
            ),
          ),
          onPressed: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildUndoButton(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            ref.read(gameEventsProvider.notifier).undoLastEvent();
          },
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.undo, size: 24),
              SizedBox(height: 4),
              Text('UNDO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

  void handleAction(WidgetRef ref, ActionType action, BuildContext context) {
    final player = ref.read(selectedPlayerProvider);
    if (player == null) {
      // Reverse flow: save pending action and wait for player selection
      ref.read(pendingActionProvider.notifier).setAction(action);
      return;
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
    );

    ref.read(gameEventsProvider.notifier).addEvent(event);
    ref.read(selectedPlayerProvider.notifier).setPlayer(null); // Normal action

    ref.read(pendingActionProvider.notifier).setAction(null); // Clear pending action
  }

  void startFTSet(BuildContext context, WidgetRef ref) {
    final player = ref.read(selectedPlayerProvider);
    if (player == null) {
      ref.read(pendingActionProvider.notifier).setAction(ActionType.ft);
      return;
    }

    if (ref.read(pendingActionProvider) == ActionType.ft) {
      ref.read(pendingActionProvider.notifier).setAction(null);
    }

    int? shotCount;
    final List<bool?> results = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          if (shotCount == null) {
            return AlertDialog(
              title: const Text('Free Throw Set'),
              content: const Text('How many shots?'),
              actions: [1, 2, 3].map((n) => TextButton(
                onPressed: () => setState(() {
                  shotCount = n;
                  results.addAll(List.generate(n, (_) => null));
                }),
                child: Text('$n Shots'),
              )).toList(),
            );
          }

          final allDone = !results.contains(null);

          return AlertDialog(
            title: Text('$shotCount Shot FT Set'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(shotCount!, (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Text('Shot ${index + 1}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: results[index] == true ? Colors.green : null,
                        foregroundColor: results[index] == true ? Colors.white : null,
                      ),
                      onPressed: () => setState(() => results[index] = true),
                      child: const Text('○ MAKE'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: results[index] == false ? Colors.red : null,
                        foregroundColor: results[index] == false ? Colors.white : null,
                      ),
                      onPressed: () => setState(() => results[index] = false),
                      child: const Text('✗ MISS'),
                    ),
                  ],
                ),
              )),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
              ElevatedButton(
                onPressed: allDone ? () {
                  final now = DateTime.now();
                  final period = ref.read(currentPeriodProvider);
                  final clockSeconds = ref.read(gameClockProvider);
                  final m = clockSeconds ~/ 60;
                  final s = clockSeconds % 60;
                  final gameClock = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

                  final events = <GameEvent>[];
                  for (int i = 0; i < results.length; i++) {
                    events.add(GameEvent(
                      id: uuid.v4(),
                      timestamp: now.add(Duration(milliseconds: i * 100)),
                      gameClock: gameClock,
                      period: period,
                      team: player.team,
                      playerId: player.id,
                      action: results[i]! ? ActionType.p1Make : ActionType.p1Miss,
                    ));
                  }
                  ref.read(gameEventsProvider.notifier).addEvents(events);
                  ref.read(selectedPlayerProvider.notifier).setPlayer(null);
                  Navigator.pop(context);
                } : null,
                child: const Text('LOG SET'),
              ),
            ],
          );
        },
      ),
    );
  }

  void handlePutback(WidgetRef ref, BuildContext context) async {
    final player = ref.read(selectedPlayerProvider);
    if (player == null) {
      ref.read(pendingActionProvider.notifier).setAction(ActionType.putback);
      return;
    }

    final isMake = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Putback Result'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('MISS')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('MAKE')),
        ],
      ),
    );

    if (isMake == null) return;

    final period = ref.read(currentPeriodProvider);
    final clockSeconds = ref.read(gameClockProvider);
    final m = clockSeconds ~/ 60;
    final s = clockSeconds % 60;
    final gameClock = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final events = <GameEvent>[];
    
    // 1. Previous Miss (Assume 2P miss for simplicity, or just log O.REB if we don't know the miss)
    events.add(GameEvent(
      id: uuid.v4(),
      timestamp: DateTime.now(),
      gameClock: gameClock,
      period: period,
      team: player.team,
      playerId: player.id,
      action: ActionType.p2Miss, 
    ));

    // 2. O.REB
    events.add(GameEvent(
      id: uuid.v4(),
      timestamp: DateTime.now().add(const Duration(milliseconds: 100)),
      gameClock: gameClock,
      period: period,
      team: player.team,
      playerId: player.id,
      action: ActionType.or,
    ));

    // 3. Putback Shot
    events.add(GameEvent(
      id: uuid.v4(),
      timestamp: DateTime.now().add(const Duration(milliseconds: 200)),
      gameClock: gameClock,
      period: period,
      team: player.team,
      playerId: player.id,
      action: isMake ? ActionType.p2Make : ActionType.p2Miss,
    ));

    ref.read(gameEventsProvider.notifier).addEvents(events);
    ref.read(selectedPlayerProvider.notifier).setPlayer(null);
    ref.read(pendingActionProvider.notifier).setAction(null);
  }

  void handleRebound(WidgetRef ref, BuildContext context) {
    final player = ref.read(selectedPlayerProvider);
    if (player == null) {
      ref.read(pendingActionProvider.notifier).setAction(ActionType.reb);
      return;
    }
    
    final events = ref.read(gameEventsProvider);
    final lastEvent = events.isNotEmpty ? events.last : null;
    
    ActionType reboundType = ActionType.dr;
    if (lastEvent != null && (lastEvent.action == ActionType.p2Miss || lastEvent.action == ActionType.p3Miss || lastEvent.action == ActionType.p1Miss)) {
      reboundType = lastEvent.team == player.team ? ActionType.or : ActionType.dr;
    } else {
      reboundType = (lastEvent?.team == player.team) ? ActionType.or : ActionType.dr;
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
      action: reboundType,
    );

    ref.read(gameEventsProvider.notifier).addEvent(event);
    ref.read(selectedPlayerProvider.notifier).setPlayer(null); // Clear selection
    ref.read(pendingActionProvider.notifier).setAction(null);
  }
