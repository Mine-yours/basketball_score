import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/action_type.dart';
import '../../providers/game_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/clock_provider.dart';
import 'player_list.dart';

class HeaderScoreboard extends ConsumerStatefulWidget {
  const HeaderScoreboard({super.key});
  
  @override
  ConsumerState<HeaderScoreboard> createState() => _HeaderScoreboardState();
}

class _HeaderScoreboardState extends ConsumerState<HeaderScoreboard> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleClock() {
    final isRunning = ref.read(isClockRunningProvider);
    ref.read(isClockRunningProvider.notifier).toggle();
    
    if (!isRunning) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final currentClock = ref.read(gameClockProvider);
        if (currentClock > 0 && ref.read(isClockRunningProvider)) {
          ref.read(gameClockProvider.notifier).tick();
        } else {
          timer.cancel();
          if (ref.read(isClockRunningProvider)) {
            ref.read(isClockRunningProvider.notifier).toggle();
          }
        }
      });
    } else {
      _timer?.cancel();
    }
  }

  String _formatClock(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final homeScore = ref.watch(homeScoreProvider);
    final awayScore = ref.watch(awayScoreProvider);
    final homeFouls = ref.watch(homeFoulsProvider);
    final awayFouls = ref.watch(awayFoulsProvider);
    final isSubMode = ref.watch(isSubstitutionModeProvider);
    
    final clockSeconds = ref.watch(gameClockProvider);
    final isRunning = ref.watch(isClockRunningProvider);

    final events = ref.watch(gameEventsProvider);
    final homeEvents = events.where((e) => e.team == TeamType.home).toList().reversed.take(3).toList();
    final awayEvents = events.where((e) => e.team == TeamType.away).toList().reversed.take(3).toList();

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 120, // Increased height
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // HOME INFO & HISTORY
          Expanded(
            child: Row(
              children: [
                _TeamHeader('HOME', homeScore, homeFouls, Colors.blue),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Recent Plays', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      if (homeEvents.isEmpty) const Text('-', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ...homeEvents.map((e) => Text(
                        e.action.name.toUpperCase(),
                        style: TextStyle(fontSize: 12, color: Colors.blue[300], fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // CLOCK & PERIOD (Center)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Q1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Row(
                children: [
                  Text(_formatClock(clockSeconds), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  IconButton(
                    icon: Icon(isRunning ? LucideIcons.pause : LucideIcons.play),
                    onPressed: _toggleClock,
                    color: isRunning ? Colors.amber : Colors.green,
                  ),
                ],
              ),
              SizedBox(
                height: 30, // constrain button size
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSubMode ? Colors.orange : null,
                    foregroundColor: isSubMode ? Colors.white : null,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () {
                    ref.read(isSubstitutionModeProvider.notifier).state = !isSubMode;
                    ref.read(substitutionTargetProvider.notifier).state = null;
                  },
                  icon: const Icon(LucideIcons.arrowRightLeft, size: 14),
                  label: const Text('SUB', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          
          // AWAY INFO & HISTORY
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Recent Plays', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      if (awayEvents.isEmpty) const Text('-', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ...awayEvents.map((e) => Text(
                        e.action.name.toUpperCase(),
                        style: TextStyle(fontSize: 12, color: Colors.red[300], fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _TeamHeader('AWAY', awayScore, awayFouls, Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  final String label;
  final int score;
  final int fouls;
  final Color color;

  const _TeamHeader(this.label, this.score, this.fouls, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text('$score', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace', height: 1.0)),
        Text('Fouls: $fouls', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
