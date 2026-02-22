import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/action_type.dart';
import '../../models/game_event.dart';
import '../../providers/game_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/pending_action_provider.dart';
import '../../providers/period_provider.dart';
import '../../providers/clock_provider.dart';
import 'player_list.dart';

const uuid = Uuid();

class CourtArea extends ConsumerWidget {
  const CourtArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(gameEventsProvider);
    final pendingShot = ref.watch(pendingShotLocationProvider);
    final displayFilter = ref.watch(displayPeriodFilterProvider);

    final filteredEvents = displayFilter == 'ALL' ? events : events.where((e) => e.period == displayFilter).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) => _handleCourtTap(context, ref, details, constraints),
          child: Container(
            color: const Color(0xFF0F172A), // Dark slate
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: CourtPainter(events: filteredEvents, pendingShot: pendingShot),
            ),
          ),
        );
      },
    );
  }

  void _handleCourtTap(BuildContext context, WidgetRef ref, TapDownDetails details, BoxConstraints constraints) async {
    final player = ref.read(selectedPlayerProvider);

    // Calculate relative coordinates
    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;

    if (player == null) {
      final is3P = is3PointShot(details.localPosition.dx, details.localPosition.dy, Size(constraints.maxWidth, constraints.maxHeight));
      ref.read(pendingShotLocationProvider.notifier).state = PendingShotLocation(x, y, is3P);
      return;
    }

    // final aspect = constraints.maxWidth / constraints.maxHeight;
    final is3P = is3PointShot(details.localPosition.dx, details.localPosition.dy, Size(constraints.maxWidth, constraints.maxHeight));

    final isMake = await showMakeMissDialog(context);
    if (isMake == null) return;

    String? assistPlayerId;
    if (isMake) {
      assistPlayerId = await showAssistDialog(context, ref, player.team, player.id);
    }

    final action = is3P 
        ? (isMake ? ActionType.p3Make : ActionType.p3Miss)
        : (isMake ? ActionType.p2Make : ActionType.p2Miss);

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
    ref.read(selectedPlayerProvider.notifier).state = null; // Clear selection
  }
}

bool is3PointShot(double px, double py, Size size) {
    final w = size.width;
    final h = size.height;
    const margin = 10.0;
    
    final isLeftCourt = px < w / 2;
    
    // Constants for 3P geometry
    final cornerYDist = h * 0.15; // Straight line y-offset
    final rx = h * 0.4;           // Horizontal radius of arc (relative to h)
    final ry = h * 0.35;          // Vertical radius of arc (relative to h)
    
    if (isLeftCourt) {
      // Left 3P Center
      final xc = margin + w * 0.05;
      final yc = h / 2;
      
      // Check corner (straight segments)
      if (px < xc) {
        return py < cornerYDist || py > (h - cornerYDist);
      }
      
      // Check arc (ellipse math)
      final dx = px - xc;
      final dy = py - yc;
      return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) >= 1.0;
    } else {
      // Right 3P Center
      final xc = w - margin - w * 0.05;
      final yc = h / 2;
      
      // Check corner
      if (px > xc) {
        return py < cornerYDist || py > (h - cornerYDist);
      }
      
      // Check arc
      final dx = px - xc;
      final dy = py - yc;
      return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) >= 1.0;
    }
}

Future<bool?> showMakeMissDialog(BuildContext context) {
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

Future<String?> showAssistDialog(BuildContext context, WidgetRef ref, TeamType team, String shooterId) async {
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

class CourtPainter extends CustomPainter {
  final List<GameEvent> events;
  final PendingShotLocation? pendingShot;

  CourtPainter({required this.events, this.pendingShot});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF475569) // slate-600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = const Color(0xFF0F172A) // Dark slate
      ..style = PaintingStyle.fill;

    // Court Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);
    
    // Outer boundary
    canvas.drawRect(Rect.fromLTWH(10, 10, size.width - 20, size.height - 20), paint);
    
    // Half court line
    canvas.drawLine(Offset(size.width / 2, 10), Offset(size.width / 2, size.height - 10), paint);
    
    // Center circle
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.15, paint);

    // Draw Keys (Paint) with colors
    final homeKeyPaint = Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final awayKeyPaint = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Left Key Fill
    canvas.drawRect(Rect.fromLTWH(10, size.height * 0.3, size.width * 0.15, size.height * 0.4), homeKeyPaint);
    // Right Key Fill
    canvas.drawRect(Rect.fromLTWH(size.width - 10 - size.width * 0.15, size.height * 0.3, size.width * 0.15, size.height * 0.4), awayKeyPaint);

    // Key outlines and arcs (rest of the code)
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

    // Team Labels to indicate attack direction
    _drawText(canvas, "HOME", Offset(size.width * 0.25, 25), const Color(0xFF3B82F6), size);
    _drawText(canvas, "AWAY", Offset(size.width * 0.75, 25), const Color(0xFFEF4444), size);


    // Left 3P Line
    final left3pXC = 10 + size.width * 0.05;
    canvas.drawLine(Offset(10, size.height * 0.15), Offset(left3pXC, size.height * 0.15), paint);
    canvas.drawLine(Offset(10, size.height * 0.85), Offset(left3pXC, size.height * 0.85), paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(left3pXC, size.height / 2), width: size.height * 0.8, height: size.height * 0.7),
      -1.57, 3.14, false, paint,
    );

    // Right 3P Line
    final right3pXC = size.width - 10 - size.width * 0.05;
    canvas.drawLine(Offset(size.width - 10, size.height * 0.15), Offset(right3pXC, size.height * 0.15), paint);
    canvas.drawLine(Offset(size.width - 10, size.height * 0.85), Offset(right3pXC, size.height * 0.85), paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(right3pXC, size.height / 2), width: size.height * 0.8, height: size.height * 0.7),
      1.57, 3.14, false, paint,
    );

    // Hoops (Goals)
    final hoopPaint = Paint()
      ..color = const Color(0xFFEF4444) // Red for hoop
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(Offset(10 + size.width * 0.03, size.height / 2), 6, hoopPaint);
    canvas.drawCircle(Offset(size.width - 10 - size.width * 0.03, size.height / 2), 6, hoopPaint);

    // Draw saved events
    for (final ev in events) {
      if (ev.x != null && ev.y != null) {
        final cx = ev.x! * size.width;
        final cy = ev.y! * size.height;
        final isMake = ev.action == ActionType.p2Make || ev.action == ActionType.p3Make;
        final isMiss = ev.action == ActionType.p2Miss || ev.action == ActionType.p3Miss;
        
        if (!isMake && !isMiss) continue;

        final teamColor = ev.team == TeamType.home ? const Color(0xFF3B82F6) : const Color(0xFFEF4444);

        if (isMake) {
          canvas.drawCircle(Offset(cx, cy), 8, Paint()..color = teamColor..style = PaintingStyle.fill);
          canvas.drawCircle(Offset(cx, cy), 8, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
        } else {
          final crossPaint = Paint()..color = teamColor..style = PaintingStyle.stroke..strokeWidth = 3;
          canvas.drawLine(Offset(cx - 6, cy - 6), Offset(cx + 6, cy + 6), crossPaint);
          canvas.drawLine(Offset(cx - 6, cy + 6), Offset(cx + 6, cy - 6), crossPaint);
        }
      }
    }

    // Draw pending shot
    if (pendingShot != null) {
      final cx = pendingShot!.x * size.width;
      final cy = pendingShot!.y * size.height;
      canvas.drawCircle(Offset(cx, cy), 14, Paint()..color = Colors.amber..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(cx, cy), 14, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 4);
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, Color color, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withOpacity(0.5),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CourtPainter oldDelegate) {
    return true;
  }
}
