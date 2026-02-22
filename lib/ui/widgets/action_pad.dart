import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../models/action_type.dart';
import '../../models/game_event.dart';
import '../../providers/game_provider.dart';
import '../../providers/pending_action_provider.dart';
import '../../providers/period_provider.dart';
import '../../providers/clock_provider.dart';
import 'player_list.dart';

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
                _buildActionButton(context, ref, 'Rebound', LucideIcons.circleDashed, () => _handleRebound(ref, context), isActive: pendingAction == ActionType.dr || pendingAction == ActionType.or || pendingAction == ActionType.reb),
                _buildActionButton(context, ref, 'Foul', LucideIcons.alertCircle, () => _handleAction(ref, ActionType.foul, context), isActive: pendingAction == ActionType.foul),
                _buildActionButton(context, ref, 'Turnover', LucideIcons.xCircle, () => _handleAction(ref, ActionType.turnover, context), isActive: pendingAction == ActionType.turnover),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildActionButton(context, ref, 'Steal', LucideIcons.mousePointerClick, () => _handleAction(ref, ActionType.steal, context), isActive: pendingAction == ActionType.steal),
                _buildActionButton(context, ref, 'Block', LucideIcons.hand, () => _handleAction(ref, ActionType.block, context), isActive: pendingAction == ActionType.block),
                _buildUndoButton(context, ref),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildActionButton(context, ref, 'FT MAKE', LucideIcons.check, () => _handleAction(ref, ActionType.p1Make, context), color: Colors.green, isActive: pendingAction == ActionType.p1Make),
                _buildActionButton(context, ref, 'FT MISS', LucideIcons.x, () => _handleAction(ref, ActionType.p1Miss, context), color: Colors.red, isActive: pendingAction == ActionType.p1Miss),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, String label, IconData icon, VoidCallback onTap, {Color? color, bool isActive = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
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
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
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
              Text('UNDO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(WidgetRef ref, ActionType action, BuildContext context) {
    final player = ref.read(selectedPlayerProvider);
    if (player == null) {
      // Reverse flow: save pending action and wait for player selection
      ref.read(pendingActionProvider.notifier).state = action;
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
    ref.read(selectedPlayerProvider.notifier).state = null; // Clear selection
    ref.read(pendingActionProvider.notifier).state = null; // Clear pending action
  }

  void _handleRebound(WidgetRef ref, BuildContext context) {
    final player = ref.read(selectedPlayerProvider);
    if (player == null) {
      ref.read(pendingActionProvider.notifier).state = ActionType.reb;
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
    ref.read(selectedPlayerProvider.notifier).state = null; // Clear selection
    ref.read(pendingActionProvider.notifier).state = null;
  }
}
