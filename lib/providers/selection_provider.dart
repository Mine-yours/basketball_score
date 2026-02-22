import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/action_type.dart';
import '../models/player.dart';

// Current selected player for actions
class SelectedPlayerNotifier extends Notifier<Player?> {
  @override
  Player? build() => null;
  
  void setPlayer(Player? player) {
    if (state?.id == player?.id) {
      state = null;
    } else {
      state = player;
    }
  }
}
final selectedPlayerProvider = NotifierProvider<SelectedPlayerNotifier, Player?>(SelectedPlayerNotifier.new);

// Substitution mode state
class IsSubstitutionModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void toggle() => state = !state;
  void setMode(bool value) => state = value;
}
final isSubstitutionModeProvider = NotifierProvider<IsSubstitutionModeNotifier, bool>(IsSubstitutionModeNotifier.new);

// Target player for substitution
class SubstitutionTargetNotifier extends Notifier<Player?> {
  @override
  Player? build() => null;
  
  void setPlayer(Player? player) => state = player;
}
final substitutionTargetProvider = NotifierProvider<SubstitutionTargetNotifier, Player?>(SubstitutionTargetNotifier.new);

// Pending action (Action first sequence)
class PendingActionNotifier extends Notifier<ActionType?> {
  @override
  ActionType? build() => null;

  void setAction(ActionType? action) {
    if (state == action) {
      state = null;
    } else {
      state = action;
      if (action != null) {
        // 排他制御: アクション選択時はシュート位置をクリア
        ref.read(pendingShotLocationProvider.notifier).setLocation(null);
      }
    }
  }
}
final pendingActionProvider = NotifierProvider<PendingActionNotifier, ActionType?>(PendingActionNotifier.new);

// Pending shot location
class PendingShotLocation {
  final double x;
  final double y;
  final bool is3P;
  PendingShotLocation(this.x, this.y, this.is3P);
}

class PendingShotLocationNotifier extends Notifier<PendingShotLocation?> {
  @override
  PendingShotLocation? build() => null;

  void setLocation(PendingShotLocation? location) {
    state = location;
    if (location != null) {
      // 排他制御: シュート位置設定時はアクション選択をクリア
      ref.read(pendingActionProvider.notifier).setAction(null);
    }
  }
}
final pendingShotLocationProvider = NotifierProvider<PendingShotLocationNotifier, PendingShotLocation?>(PendingShotLocationNotifier.new);
