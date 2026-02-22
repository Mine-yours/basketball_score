import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/action_type.dart';

// Represents an action that was tapped before a player was selected
class PendingActionNotifier extends Notifier<ActionType?> {
  @override
  ActionType? build() => null;
  
  set state(ActionType? value) => super.state = value;
}

final pendingActionProvider = NotifierProvider<PendingActionNotifier, ActionType?>(PendingActionNotifier.new);

// Represents a court location that was tapped before a player was selected
class PendingShotLocation {
  final double x;
  final double y;
  final bool is3P;
  PendingShotLocation(this.x, this.y, this.is3P);
}

class PendingShotLocationNotifier extends Notifier<PendingShotLocation?> {
  @override
  PendingShotLocation? build() => null;

  set state(PendingShotLocation? value) => super.state = value;
}

final pendingShotLocationProvider = NotifierProvider<PendingShotLocationNotifier, PendingShotLocation?>(PendingShotLocationNotifier.new);
