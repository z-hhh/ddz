import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:doudizhu/model/master_worker.dart';
import 'package:doudizhu/model/douzero.dart';

Future<void> main() async {
  final worker = MasterWorker(), clock = Stopwatch()..start();
  final detail = await worker.initialize({
    for (final r in ['landlord', 'landlord_down', 'landlord_up'])
      r: File('assets/models/$r.dzf').readAsBytesSync(),
  });
  final startup = clock.elapsedMicroseconds / 1000;
  final traces = jsonDecode(
    File('tool/model/observation_traces.json').readAsStringSync(),
  ) as List;
  var ticks = 0, maxTickGap = 0;
  final heartbeat = Stopwatch()..start();
  var last = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 2), (_) {
    ticks++;
    final now = heartbeat.elapsedMilliseconds;
    if (now - last > maxTickGap) maxTickGap = now - last;
    last = now;
  });
  final times = <double>[];
  for (final row in traces) {
    clock.reset();
    final result = await worker.decide(
      ModelObservation.fromMap(
        Map<String, dynamic>.from(row['observation'] as Map),
      ),
      [for (final x in row['candidates'] as List) List<int>.from(x as List)],
    );
    times.add(clock.elapsedMicroseconds / 1000);
    final scores = List<double>.from(row['scores'] as List);
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    if (result['index'] != best) throw StateError('Worker decision mismatch');
  }
  timer.cancel();
  worker.dispose();
  times.sort();
  final result = {
    'startupWithFileReadMs': startup,
    'workerParseMs': detail['loadMs'],
    'decisions': times.length,
    'roundTripP50Ms': times[times.length ~/ 2],
    'roundTripP95Ms': times[(times.length * .95).floor()],
    'mainIsolateTimerTicks': ticks,
    'maxTimerGapMs': maxTickGap,
  };
  File('../../dist/2.0.0-isolate性能.json')
      .writeAsStringSync('${jsonEncode(result)}\n');
  stdout.writeln(jsonEncode(result));
}
