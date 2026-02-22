import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/action_type.dart';
import '../../models/game_event.dart';
import '../../providers/game_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/clock_provider.dart';
import '../../providers/period_provider.dart';
import '../../providers/selection_provider.dart';
import 'clock_edit_modal.dart';
import 'box_score_dialog.dart';

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
    final currentPeriod = ref.watch(currentPeriodProvider);
    final availablePeriods = ref.watch(availablePeriodsProvider);
    final displayFilter = ref.watch(displayPeriodFilterProvider);
    final lineScores = ref.watch(lineScoreProvider);
    final homeDirection = ref.watch(homeAttackDirectionProvider);

    // Auto-side change logic
    ref.listen(currentPeriodProvider, (previous, next) {
      if ((next == 'Q3' || next == 'OT1') && previous != next) {
        // Simple heuristic: if we just entered Q3/OT1, toggle
        ref.read(homeAttackDirectionProvider.notifier).toggle();
      }
    });

    final filteredEvents = displayFilter == 'ALL' ? events : events.where((e) => e.period == displayFilter).toList();
    final homeEvents = filteredEvents.where((e) => e.team == TeamType.home).toList().reversed.take(3).toList();
    final awayEvents = filteredEvents.where((e) => e.team == TeamType.away).toList().reversed.take(3).toList();

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 220, // Increased height to prevent overflow
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // HOME INFO & HISTORY
          Expanded(
            child: Row(
              children: [
                _TeamHeader('HOME', homeScore, homeFouls, Colors.blue, direction: homeDirection == AttackDirection.right ? '→' : '←'),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Recent Plays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      if (homeEvents.isEmpty) const Text('-', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ...homeEvents.map((e) => InkWell(
                        onTap: () => _editEventPlayer(context, ref, e),
                        child: Text(
                          e.action.name.toUpperCase(),
                          style: TextStyle(fontSize: 14, color: Colors.blue[300], fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // CLOCK, PERIODS & LINE SCORE (Center)
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Period Selection Tabs & Side Change
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PeriodTab('ALL', displayFilter == 'ALL', () => ref.read(displayPeriodFilterProvider.notifier).state = 'ALL'),
                            ...availablePeriods.map((p) => _PeriodTab(
                              p, 
                              displayFilter == p, 
                              () {
                                ref.read(displayPeriodFilterProvider.notifier).state = p;
                                ref.read(currentPeriodProvider.notifier).state = p;
                              },
                              isCurrent: currentPeriod == p,
                            )),
                            IconButton(
                              icon: const Icon(LucideIcons.plus, size: 14),
                              onPressed: () => ref.read(availablePeriodsProvider.notifier).addOvertime(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(LucideIcons.refreshCw, size: 14),
                      label: const Text('SIDE CHANGE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () => ref.read(homeAttackDirectionProvider.notifier).toggle(),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(LucideIcons.barChart2, size: 14),
                      label: const Text('BOX SCORE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () => showDialog(context: context, builder: (context) => const BoxScoreDialog()),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Main Row: Home Line Scores | Clock | Away Line Scores
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Home Line Scores
                    _MiniLineScore(periods: availablePeriods, scores: lineScores['home']!, color: Colors.blue),
                    const SizedBox(width: 12),
                    // Clock
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (isRunning) _toggleClock();
                              showDialog(context: context, builder: (context) => const ClockEditModal());
                            },
                            child: Text(
                              _formatClock(clockSeconds),
                              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(isRunning ? LucideIcons.pause : LucideIcons.play),
                            onPressed: _toggleClock,
                            color: isRunning ? Colors.amber : Colors.green,
                            iconSize: 32,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Away Line Scores
                    _MiniLineScore(periods: availablePeriods, scores: lineScores['away']!, color: Colors.red),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSubMode ? Colors.orange : null,
                      foregroundColor: isSubMode ? Colors.white : null,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    onPressed: () {
                      ref.read(isSubstitutionModeProvider.notifier).toggle();
                      ref.read(substitutionTargetProvider.notifier).setPlayer(null);
                    },
                    icon: const Icon(LucideIcons.arrowRightLeft, size: 18),
                    label: const Text('SUBSTITUTION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
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
                      const Text('Recent Plays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      if (awayEvents.isEmpty) const Text('-', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ...awayEvents.map((e) => InkWell(
                        onTap: () => _editEventPlayer(context, ref, e),
                        child: Text(
                          e.action.name.toUpperCase(),
                          style: TextStyle(fontSize: 14, color: Colors.red[300], fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _TeamHeader('AWAY', awayScore, awayFouls, Colors.red, direction: homeDirection == AttackDirection.right ? '←' : '→'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editEventPlayer(BuildContext context, WidgetRef ref, GameEvent event) {
    final players = event.team == TeamType.home 
        ? ref.read(homeTeamPlayersProvider) 
        : ref.read(awayTeamPlayersProvider);

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Update Player for ${event.action.name}'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(gameEventsProvider.notifier).updateEventPlayer(event.id, null);
              Navigator.pop(context);
            },
            child: const Text('TEAM'),
          ),
          const Divider(),
          ...players.map((p) => SimpleDialogOption(
            onPressed: () {
              ref.read(gameEventsProvider.notifier).updateEventPlayer(event.id, p.id);
              Navigator.pop(context);
            },
            child: Text('${p.number} ${p.name}'),
          )),
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
  final String direction;

  const _TeamHeader(this.label, this.score, this.fouls, this.color, {required this.direction});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(width: 4),
            Text(direction, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        Text('$score', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, fontFamily: 'monospace', height: 1.0)),
        Text('Fouls: $fouls', style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
class _PeriodTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PeriodTab(this.label, this.isSelected, this.onTap, {this.isCurrent = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
          border: isCurrent ? Border.all(color: Colors.amber, width: 2) : Border.all(color: Colors.grey.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 14, 
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? Colors.amber : null,
        )),
      ),
    );
  }
}

class _MiniLineScore extends StatelessWidget {
  final List<String> periods;
  final Map<String, int> scores;
  final Color color;

  const _MiniLineScore({required this.periods, required this.scores, required this.color});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: periods.map((p) => Container(
              width: 32, // Slightly wider for better readability
              alignment: Alignment.center,
              child: Text(p, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            )).toList(),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: periods.map((p) => Container(
              width: 32, // Slightly wider
              alignment: Alignment.center,
              child: Text('${scores[p] ?? 0}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
