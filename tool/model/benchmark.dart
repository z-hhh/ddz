import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:doudizhu/game/ai.dart';
import 'package:doudizhu/game/cards.dart';
import 'package:doudizhu/game/game_state.dart';
import 'package:doudizhu/model/douzero.dart';
import 'package:doudizhu/model/game_observation.dart';

void main(List<String> args) {
  final number = args.isEmpty ? 240 : int.parse(args[0]);
  final output = args.length > 1 ? args[1] : '../../dist/2.0.0-benchmark.json';
  final load = Stopwatch()..start();
  final models = {
    for (final r in ['landlord', 'landlord_down', 'landlord_up'])
      r: DouZeroNetwork(File('assets/models/$r.dzf').readAsBytesSync()),
  };
  final loadMs = load.elapsedMicroseconds / 1000;
  final games = <Map<String, dynamic>>[],
      timings = <double>[],
      traces = <Map<String, dynamic>>[];
  var illegal = 0, timeouts = 0;
  final file = File(output.replaceAll('.json', '.jsonl'))
    ..writeAsStringSync('');
  final total = Stopwatch()..start();
  for (var index = 0; index < number; index++) {
    final seed = 200000 + index ~/ 2,
        masterLandlord = index.isEven,
        landlord = (index ~/ 2) % 3;
    final cards = deck(Random(seed)), g = GameState();
    g.hands = [
      for (var i = 0; i < 3; i++) sorted(cards.sublist(i * 17, i * 17 + 17)),
    ];
    g.bottom = cards.sublist(51);
    g.turn = landlord;
    g.bidder = landlord;
    if (g.act(landlord, 'bid', value: 3) != null) {
      throw StateError('Bid fixture');
    }
    var steps = 0, modelSteps = 0;
    final gameClock = Stopwatch()..start();
    while (g.phase != 'over') {
      if (++steps > 500 || gameClock.elapsed.inSeconds > 120) {
        timeouts++;
        throw StateError('Game timeout seed=$seed');
      }
      final seat = g.turn, isMaster = (seat == landlord) == masterLandlord;
      List<int> action;
      if (isMaster) {
        final clock = Stopwatch()..start();
        final candidates = moves(g.hands[seat], g.target);
        if (g.target != null) candidates.add([]);
        final obs = gameObservation(g, seat);
        final scores = models[obs.role]!.scoreActions(obs, candidates);
        var best = 0;
        for (var j = 1; j < scores.length; j++) {
          if (scores[j] > scores[best]) best = j;
        }
        action = candidates[best];
        modelSteps++;
        final ms = clock.elapsedMicroseconds / 1000;
        timings.add(ms);
        if (ms > 15000) {
          timeouts++;
          throw StateError('Decision timeout');
        }
        if (traces.length < 48) {
          traces.add({
            'seat': seat,
            'landlord': landlord,
            'hand': g.hands[seat].toList(),
            'counts': [for (final h in g.hands) h.length],
            'played': [for (final h in g.playedCards) h.toList()],
            'last': [for (final h in g.lastActions) h.toList()],
            'history': [for (final h in g.actionHistory) h.toList()],
            'bombs': g.bombCount,
            'observation': obs.toMap(),
            'candidates': candidates,
            'scores': scores,
          });
        }
      } else {
        action = choose(g.hands[seat], g.target);
      }
      final error = g.act(
        seat,
        action.isEmpty ? 'pass' : 'play',
        cards: action,
      );
      if (error != null) {
        illegal++;
        throw StateError('Illegal seed=$seed seat=$seat: $error');
      }
    }
    final won = (g.winner == landlord) == masterLandlord;
    final result = {
      'index': index,
      'seed': seed,
      'landlord': landlord,
      'master': masterLandlord ? 'landlord' : 'farmers',
      'masterWon': won,
      'winner': g.winner,
      'steps': steps,
      'modelSteps': modelSteps,
      'durationMs': gameClock.elapsedMilliseconds,
      'deck': cards,
    };
    games.add(result);
    file.writeAsStringSync(
      '${jsonEncode(result)}\n',
      mode: FileMode.append,
      flush: true,
    );
    if ((index + 1) % 10 == 0) {
      stdout.writeln(
        'BENCH ${index + 1}/$number elapsed=${total.elapsed.inSeconds}s',
      );
    }
  }
  timings.sort();
  Map<String, dynamic> rate(String role) {
    final group = games.where((g) => g['master'] == role).toList();
    final won = group.where((g) => g['masterWon'] == true).length;
    return {'games': group.length, 'wins': won, 'winRate': won / group.length};
  }

  final report = {
    'games': games,
    'landlord': rate('landlord'),
    'farmers': rate('farmers'),
    'overall': games.where((g) => g['masterWon'] == true).length / games.length,
    'illegal': illegal,
    'timeouts': timeouts,
    'modelDecisions': timings.length,
    'p50Ms': timings[(timings.length * .5).floor()],
    'p95Ms': timings[(timings.length * .95).floor()],
    'maxMs': timings.last,
    'modelLoadMs': loadMs,
    'wallSeconds': total.elapsedMilliseconds / 1000,
    'runtime': Platform.version,
    'cpu': File('/proc/cpuinfo')
        .readAsStringSync()
        .split('\n')
        .where((x) => x.startsWith('model name'))
        .first,
  };
  File(output).writeAsStringSync('${jsonEncode(report)}\n');
  File('tool/model/observation_traces.json')
      .writeAsStringSync(jsonEncode(traces));
  stdout.writeln(jsonEncode({...report}..remove('games')));
}
