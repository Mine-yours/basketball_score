import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/action_type.dart';

// Represents an action that was tapped before a player was selected
class PendingActionNotifier extends Notifier<ActionType?> {
  @override
  ActionType? build() => null;
}

final pendingActionProvider = NotifierProvider<PendingActionNotifier, ActionType?>(PendingActionNotifier.new);

// Represents a court location that was tapped before a player was selected
class PendingShotLocation {
  final double x;
  final double y;
  PendingShotLocation(this.x, this.y);
}

class PendingShotLocationNotifier extends Notifier<PendingShotLocation?> {
  @override
  PendingShotLocation? build() => null;
}

final pendingShotLocationProvider = NotifierProvider<PendingShotLocationNotifier, PendingShotLocation?>(PendingShotLocationNotifier.new);
