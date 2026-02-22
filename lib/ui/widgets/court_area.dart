import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/action_type.dart';
import '../../models/game_event.dart';
import '../../models/player.dart';
import '../../providers/game_provider.dart';
import '../../providers/stats_provider.dart';
import 'player_list.dart';

const uuid = Uuid();

class CourtArea extends ConsumerWidget {
  const CourtArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) => _handleCourtTap(context, ref, details, constraints),
          child: Container(
            color: Colors.orange[200], // Temporary court color
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: CourtPainter(),
            ),
          ),
        );
      },
    );
  }

  void _handleCourtTap(BuildContext context, WidgetRef ref, TapDownDetails details, BoxConstraints constraints) async {
    final player = ref.read(selectedPlayerProvider);
    if (player == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a player first')));
      return;
    }

    // Calculate relative coordinates
    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;

    // Simple 3P logic: check distance from hoop (0.5, 0.1) or (0.5, 0.9)
    // Assuming hoop is at y=0.1
    final dx = x - 0.5;
    final dy = y - 0.1;
    final distance = (dx * dx + dy * dy);
    final is3P = distance > 0.08; // Arbitrary 3P line distance

    final isMake = await _showMakeMissDialog(context);
    if (isMake == null) return;

    String? assistPlayerId;
    if (isMake) {
      assistPlayerId = await _showAssistDialog(context, ref, player.team, player.id);
    }

    final action = is3P 
        ? (isMake ? ActionType.p3Make : ActionType.p3Miss)
        : (isMake ? ActionType.p2Make : ActionType.p2Miss);

    final event = GameEvent(
      id: uuid.v4(),
      timestamp: DateTime.now(),
      gameClock: '10:00', // Dummy
      period: 'Q1', // Dummy
      team: player.team,
      playerId: player.id,
      action: action,
      x: x,
      y: y,
      assistPlayerId: assistPlayerId,
    );

    ref.read(gameEventsProvider.notifier).addEvent(event);
    ref.read(selectedPlayerProvider.notifier).state = null; // Clear selection
  }

  Future<bool?> _showMakeMissDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shot Result'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('MISS', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('MAKE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showAssistDialog(BuildContext context, WidgetRef ref, TeamType team, String shooterId) async {
    final players = team == TeamType.home 
        ? ref.read(onCourtHomePlayersProvider) 
        : ref.read(onCourtAwayPlayersProvider);
    
    final teammates = players.where((p) => p.id != shooterId).toList();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assist?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: teammates.length + 1,
            itemBuilder: (context, index) {
              if (index == teammates.length) {
                return ListTile(
                  title: const Text('NO ASSIST', style: TextStyle(color: Colors.grey)),
                  onTap: () => Navigator.of(context).pop(null),
                );
              }
              final p = teammates[index];
              return ListTile(
                title: Text('${p.number} ${p.name}'),
                onTap: () => Navigator.of(context).pop(p.id),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = Colors.orange[800]!
      ..style = PaintingStyle.fill;

    // Court Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);
    
    // Outer boundary
    canvas.drawRect(Rect.fromLTWH(10, 10, size.width - 20, size.height - 20), paint);
    
    // Half court line
    canvas.drawLine(Offset(size.width / 2, 10), Offset(size.width / 2, size.height - 10), paint);
    
    // Center circle
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.15, paint);

    // Left Key
    canvas.drawRect(Rect.fromLTWH(10, size.height * 0.3, size.width * 0.15, size.height * 0.4), paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(10 + size.width * 0.15, size.height / 2), width: size.height * 0.3, height: size.height * 0.3),
      -1.57, 3.14, false, paint,
    );

    // Right Key
    canvas.drawRect(Rect.fromLTWH(size.width - 10 - size.width * 0.15, size.height * 0.3, size.width * 0.15, size.height * 0.4), paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(size.width - 10 - size.width * 0.15, size.height / 2), width: size.height * 0.3, height: size.height * 0.3),
      1.57, 3.14, false, paint,
    );

    // Left 3P Line
    canvas.drawLine(Offset(10, size.height * 0.15), Offset(10 + size.width * 0.1, size.height * 0.15), paint);
    canvas.drawLine(Offset(10, size.height * 0.85), Offset(10 + size.width * 0.1, size.height * 0.85), paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(10 + size.width * 0.05, size.height / 2), width: size.height * 0.8, height: size.height * 0.7),
      -1.57, 3.14, false, paint,
    );

    // Right 3P Line
    canvas.drawLine(Offset(size.width - 10, size.height * 0.15), Offset(size.width - 10 - size.width * 0.1, size.height * 0.15), paint);
    canvas.drawLine(Offset(size.width - 10, size.height * 0.85), Offset(size.width - 10 - size.width * 0.1, size.height * 0.85), paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(size.width - 10 - size.width * 0.05, size.height / 2), width: size.height * 0.8, height: size.height * 0.7),
      1.57, 3.14, false, paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
