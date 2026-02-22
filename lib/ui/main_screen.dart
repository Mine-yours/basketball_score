import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/action_type.dart';
import 'widgets/header_scoreboard.dart';
import 'widgets/player_list.dart';
import 'widgets/court_area.dart';
import 'widgets/action_pad.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const HeaderScoreboard(),
            Expanded(
              child: Row(
                children: [
                  // Home Team Players
                  const Expanded(
                    flex: 2,
                    child: PlayerList(team: TeamType.home),
                  ),
                  // Center Area (Court & Actions)
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            color: Colors.grey[800],
                            child: const CourtArea(),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            color: Colors.grey[900],
                            child: const ActionPad(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Away Team Players
                  const Expanded(
                    flex: 2,
                    child: PlayerList(team: TeamType.away),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
