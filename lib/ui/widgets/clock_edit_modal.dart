import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/clock_provider.dart';

class ClockEditModal extends ConsumerStatefulWidget {
  const ClockEditModal({super.key});

  @override
  ConsumerState<ClockEditModal> createState() => _ClockEditModalState();
}

class _ClockEditModalState extends ConsumerState<ClockEditModal> {
  late TextEditingController _minController;
  late TextEditingController _secController;

  @override
  void initState() {
    super.initState();
    final totalSeconds = ref.read(gameClockProvider);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    _minController = TextEditingController(text: minutes.toString());
    _secController = TextEditingController(text: seconds.toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _minController.dispose();
    _secController.dispose();
    super.dispose();
  }

  void _save() {
    final mins = int.tryParse(_minController.text) ?? 0;
    final secs = int.tryParse(_secController.text) ?? 0;
    ref.read(gameClockProvider.notifier).setSeconds(mins * 60 + secs);
    Navigator.of(context).pop();
  }

  void _adjust(int delta) {
    final current = ref.read(gameClockProvider);
    final next = (current + delta).clamp(0, 3600);
    ref.read(gameClockProvider.notifier).setSeconds(next);
    
    final minutes = next ~/ 60;
    final seconds = next % 60;
    _minController.text = minutes.toString();
    _secController.text = seconds.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Clock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _minController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Min'),
                ),
              ),
              const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _secController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Sec'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(onPressed: () => _adjust(-1), child: const Text('-1s')),
              ElevatedButton(onPressed: () => _adjust(1), child: const Text('+1s')),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
        TextButton(onPressed: _save, child: const Text('SAVE')),
      ],
    );
  }
}
