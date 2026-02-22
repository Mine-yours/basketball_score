import 'package:basket_stats_app/models/action_type.dart';
import 'package:basket_stats_app/models/player.dart';

final List<Player> mockHomeTeam = [
  const Player(id: 'h1', number: '4', name: 'Home PG', team: TeamType.home, isOnCourt: true),
  const Player(id: 'h2', number: '5', name: 'Home SG', team: TeamType.home, isOnCourt: true),
  const Player(id: 'h3', number: '6', name: 'Home SF', team: TeamType.home, isOnCourt: true),
  const Player(id: 'h4', number: '7', name: 'Home PF', team: TeamType.home, isOnCourt: true),
  const Player(id: 'h5', number: '8', name: 'Home C', team: TeamType.home, isOnCourt: true),
  const Player(id: 'h6', number: '9', name: 'Home Bench 1', team: TeamType.home, isOnCourt: false),
  const Player(id: 'h7', number: '10', name: 'Home Bench 2', team: TeamType.home, isOnCourt: false),
  const Player(id: 'h8', number: '11', name: 'Home Bench 3', team: TeamType.home, isOnCourt: false),
  const Player(id: 'h9', number: '12', name: 'Home Bench 4', team: TeamType.home, isOnCourt: false),
  const Player(id: 'h10', number: '13', name: 'Home Bench 5', team: TeamType.home, isOnCourt: false),
];

final List<Player> mockAwayTeam = [
  const Player(id: 'a1', number: '4', name: 'Away PG', team: TeamType.away, isOnCourt: true),
  const Player(id: 'a2', number: '5', name: 'Away SG', team: TeamType.away, isOnCourt: true),
  const Player(id: 'a3', number: '6', name: 'Away SF', team: TeamType.away, isOnCourt: true),
  const Player(id: 'a4', number: '7', name: 'Away PF', team: TeamType.away, isOnCourt: true),
  const Player(id: 'a5', number: '8', name: 'Away C', team: TeamType.away, isOnCourt: true),
  const Player(id: 'a6', number: '9', name: 'Away Bench 1', team: TeamType.away, isOnCourt: false),
  const Player(id: 'a7', number: '10', name: 'Away Bench 2', team: TeamType.away, isOnCourt: false),
  const Player(id: 'a8', number: '11', name: 'Away Bench 3', team: TeamType.away, isOnCourt: false),
  const Player(id: 'a9', number: '12', name: 'Away Bench 4', team: TeamType.away, isOnCourt: false),
  const Player(id: 'a10', number: '13', name: 'Away Bench 5', team: TeamType.away, isOnCourt: false),
];
