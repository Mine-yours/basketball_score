import 'action_type.dart';

class Player {
  final String id;
  final String number;
  final String name;
  final TeamType team;
  final bool isOnCourt;

  const Player({
    required this.id,
    required this.number,
    required this.name,
    required this.team,
    required this.isOnCourt,
  });

  Player copyWith({
    String? id,
    String? number,
    String? name,
    TeamType? team,
    bool? isOnCourt,
  }) {
    return Player(
      id: id ?? this.id,
      number: number ?? this.number,
      name: name ?? this.name,
      team: team ?? this.team,
      isOnCourt: isOnCourt ?? this.isOnCourt,
    );
  }
}
