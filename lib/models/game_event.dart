import 'action_type.dart';

class GameEvent {
  final String id;
  final DateTime timestamp;
  final String gameClock;
  final String period;
  final TeamType team;
  final String playerId;
  final ActionType action;
  final double? x;
  final double? y;
  final String? assistPlayerId;

  const GameEvent({
    required this.id,
    required this.timestamp,
    required this.gameClock,
    required this.period,
    required this.team,
    required this.playerId,
    required this.action,
    this.x,
    this.y,
    this.assistPlayerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'gameClock': gameClock,
      'period': period,
      'team': team.name,
      'playerId': playerId,
      'action': action.name,
      'x': x,
      'y': y,
      'assistPlayerId': assistPlayerId,
    };
  }

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      gameClock: json['gameClock'],
      period: json['period'],
      team: TeamType.values.byName(json['team']),
      playerId: json['playerId'],
      action: ActionType.values.byName(json['action']),
      x: json['x'] as double?,
      y: json['y'] as double?,
      assistPlayerId: json['assistPlayerId'],
    );
  }
}
