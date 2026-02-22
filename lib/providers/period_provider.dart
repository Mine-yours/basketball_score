import 'package:flutter_riverpod/flutter_riverpod.dart';

class AvailablePeriodsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ['Q1', 'Q2', 'Q3', 'Q4'];

  @override
  set state(List<String> value) => super.state = value;

  void addOvertime() {
    final otCount = state.where((p) => p.startsWith('OT')).length;
    state = [...state, 'OT${otCount + 1}'];
  }
}

final availablePeriodsProvider = NotifierProvider<AvailablePeriodsNotifier, List<String>>(AvailablePeriodsNotifier.new);

class CurrentPeriodNotifier extends Notifier<String> {
  @override
  String build() => 'Q1';

  @override
  set state(String value) => super.state = value;
}

final currentPeriodProvider = NotifierProvider<CurrentPeriodNotifier, String>(CurrentPeriodNotifier.new);

class DisplayPeriodFilterNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  @override
  set state(String value) => super.state = value;
}

final displayPeriodFilterProvider = NotifierProvider<DisplayPeriodFilterNotifier, String>(DisplayPeriodFilterNotifier.new);

enum AttackDirection { left, right }

class HomeAttackDirectionNotifier extends Notifier<AttackDirection> {
  @override
  AttackDirection build() => AttackDirection.right;

  void toggle() {
    state = state == AttackDirection.right ? AttackDirection.left : AttackDirection.right;
  }
}

final homeAttackDirectionProvider = NotifierProvider<HomeAttackDirectionNotifier, AttackDirection>(HomeAttackDirectionNotifier.new);

