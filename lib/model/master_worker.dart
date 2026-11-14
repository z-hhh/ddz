import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'douzero.dart';

/// One persistent worker; parsing weights and every matrix multiply stay off UI.
class MasterWorker {
  Isolate? _isolate;
  SendPort? _send;
  final ReceivePort _receive = ReceivePort();
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  late final StreamSubscription<dynamic> _subscription;
  int _sequence = 0;
  bool _disposed = false;
  MasterWorker() {
    _subscription = _receive.listen((dynamic raw) {
      if (raw is SendPort) {
        _send = raw;
        return;
      }
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw),
            done = _pending.remove(raw['id']);
        if (m.containsKey('error')) {
          done?.completeError(StateError(m['error'] as String));
        } else {
          done?.complete(m);
        }
      }
    });
  }
  Future<Map<String, dynamic>> initialize(
    Map<String, Uint8List> weights,
  ) async {
    final ready = Completer<Map<String, dynamic>>();
    _pending[0] = ready;
    _isolate = await Isolate.spawn(
      _entry,
      [
        _receive.sendPort,
        {
          for (final e in weights.entries)
            e.key: TransferableTypedData.fromList([e.value]),
        },
      ],
      onError: _receive.sendPort,
      errorsAreFatal: true,
    );
    if (_disposed) _isolate?.kill(priority: Isolate.immediate);
    return ready.future.timeout(const Duration(seconds: 30));
  }

  Future<Map<String, dynamic>> decide(
    ModelObservation observation,
    List<List<int>> candidates,
  ) {
    if (_disposed || _send == null) throw StateError('Master model not ready');
    final id = ++_sequence, done = Completer<Map<String, dynamic>>();
    _pending[id] = done;
    _send!.send({
      'id': id,
      'observation': observation.toMap(),
      'candidates': candidates,
    });
    return done.future.timeout(const Duration(seconds: 15));
  }

  static void _entry(List<dynamic> args) {
    final output = args[0] as SendPort, weights = args[1] as Map;
    final input = ReceivePort();
    output.send(input.sendPort);
    final watch = Stopwatch()..start();
    final models = <String, DouZeroNetwork>{};
    try {
      for (final key in weights.keys) {
        models[key as String] = DouZeroNetwork(
          (weights[key] as TransferableTypedData).materialize().asUint8List(),
        );
      }
      output.send({'id': 0, 'loadMs': watch.elapsedMicroseconds / 1000});
    } catch (e) {
      output.send({'id': 0, 'error': '$e'});
      input.close();
      return;
    }
    input.listen((dynamic raw) {
      final m = raw as Map;
      try {
        final observation = ModelObservation.fromMap(
          Map<String, dynamic>.from(m['observation'] as Map),
        );
        final candidates = [
          for (final x in m['candidates'] as List) List<int>.from(x as List),
        ];
        final watch = Stopwatch()..start();
        final scores = models[observation.role]!.scoreActions(
          observation,
          candidates,
        );
        var index = 0;
        for (var i = 1; i < scores.length; i++) {
          if (scores[i] > scores[index]) index = i;
        }
        if (scores.isEmpty || scores.any((v) => !v.isFinite)) {
          throw StateError('Invalid model score');
        }
        output.send({
          'id': m['id'],
          'index': index,
          'scores': scores,
          'winProbabilities': [
            for (final value in scores) ((value + 1) / 2).clamp(0.0, 1.0),
          ],
          'inferenceMs': watch.elapsedMicroseconds / 1000,
        });
      } catch (e) {
        output.send({'id': m['id'], 'error': '$e'});
      }
    });
  }

  void dispose() {
    _disposed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _subscription.cancel();
    _receive.close();
    for (final done in _pending.values) {
      if (!done.isCompleted) {
        done.completeError(StateError('Model worker closed'));
      }
    }
    _pending.clear();
  }
}
