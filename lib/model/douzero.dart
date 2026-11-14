// DouZero-compatible observation and Float32 forward pass.
// Reimplemented for Dart from kwai/DouZero (Apache-2.0).
// Changes: input-major tensors, shared first-layer context, no native runtime.
// See assets/licenses/DouZero-NOTICE.md for immutable upstream references.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../game/cards.dart';

Float64List encodeCards(List<int> cards) {
  final out = Float64List(54), counts = List<int>.filled(15, 0);
  for (final card in cards) {
    if (card < 0 || card > 53) throw ArgumentError('Unknown card');
    counts[rank(card) - 3]++;
  }
  for (var r = 0; r < 13; r++) {
    for (var n = 0; n < counts[r]; n++) {
      out[r * 4 + n] = 1;
    }
  }
  out[52] = counts[13].toDouble();
  out[53] = counts[14].toDouble();
  return out;
}

class ModelObservation {
  final String role;
  final List<double> state, history;
  const ModelObservation(this.role, this.state, this.history);
  Map<String, dynamic> toMap() => {
    'role': role,
    'state': state,
    'history': history,
  };
  factory ModelObservation.fromMap(Map<String, dynamic> m) => ModelObservation(
    m['role'] as String,
    List<double>.from(m['state'] as List),
    List<double>.from(m['history'] as List),
  );
}

/// Only own hand, public actions and public counts enter this encoder.
ModelObservation observation({
  required int seat,
  required int landlord,
  required List<int> hand,
  required List<int> counts,
  required List<List<int>> played,
  required List<List<int>> last,
  required List<List<int>> history,
  required int bombs,
}) {
  final role = seat == landlord
      ? 'landlord'
      : seat == (landlord + 1) % 3
      ? 'landlord_down'
      : 'landlord_up';
  final unseen = Set<int>.from(List.generate(54, (i) => i))
    ..removeAll(hand)
    ..removeAll(played.expand((x) => x));
  final latest = history.isEmpty
      ? <int>[]
      : history.last.isNotEmpty
      ? history.last
      : history.length > 1
      ? history[history.length - 2]
      : <int>[];
  List<double> hot(int n, int length) {
    final a = List<double>.filled(length, 0);
    if (n > 0 && n <= length) a[n - 1] = 1;
    return a;
  }

  final bomb = List<double>.filled(15, 0)..[bombs.clamp(0, 14)] = 1;
  final state = <double>[...encodeCards(hand), ...encodeCards(unseen.toList())];
  if (role == 'landlord') {
    final up = (landlord + 2) % 3, down = (landlord + 1) % 3;
    state.addAll([
      ...encodeCards(latest),
      ...encodeCards(played[up]),
      ...encodeCards(played[down]),
      ...hot(counts[up], 17),
      ...hot(counts[down], 17),
      ...bomb,
    ]);
  } else {
    final teammate = 3 - seat - landlord;
    state.addAll([
      ...encodeCards(played[landlord]),
      ...encodeCards(played[teammate]),
      ...encodeCards(latest),
      ...encodeCards(last[landlord]),
      ...encodeCards(last[teammate]),
      ...hot(counts[landlord], 20),
      ...hot(counts[teammate], 17),
      ...bomb,
    ]);
  }
  final recent = history.length > 15
      ? history.sublist(history.length - 15)
      : history;
  final z = <double>[
    ...List<double>.filled((15 - recent.length) * 54, 0),
    for (final action in recent) ...encodeCards(action),
  ];
  return ModelObservation(role, state, z);
}

class _Tensor {
  final List<int> shape;
  final Float32List data;
  const _Tensor(this.shape, this.data);
}

class DouZeroNetwork {
  final Map<String, _Tensor> _tensors = {};
  late final String role;
  DouZeroNetwork(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    if (ascii.decode(bytes.sublist(0, 4)) != 'DZ01') {
      throw const FormatException('Invalid model header');
    }
    final length = bd.getUint32(4, Endian.little);
    final m = jsonDecode(utf8.decode(bytes.sublist(8, 8 + length))) as Map;
    role = m['role'] as String;
    var offset = 8 + length;
    for (final raw in m['tensors'] as List) {
      final t = raw as Map;
      final size = t['length'] as int;
      final values = Float32List(size);
      for (var i = 0; i < size; i++) {
        values[i] = bd.getFloat32(offset + 4 * i, Endian.little);
      }
      _tensors[t['name'] as String] = _Tensor(
        List<int>.from(t['shape'] as List),
        values,
      );
      offset += 4 * size;
    }
    if (offset != bytes.length) {
      throw const FormatException('Model length mismatch');
    }
    if (_tensors['dense1.weight']!.shape[0] !=
        (role == 'landlord' ? 501 : 612)) {
      throw const FormatException('Wrong role shape');
    }
  }
  Float64List _linear(String prefix, List<double> x, {bool relu = false}) {
    final t = _tensors['$prefix.weight']!, n = t.shape[1];
    final y = Float64List.fromList(_tensors['$prefix.bias']!.data);
    _add(t.data, n, x, y);
    if (relu)
      for (var i = 0; i < n; i++) {
        if (y[i] < 0) y[i] = 0;
      }
    return y;
  }

  static void _add(
    Float32List w,
    int n,
    List<double> x,
    Float64List y, {
    int start = 0,
  }) {
    for (var i = 0; i < x.length; i++) {
      final value = x[i];
      if (value == 0) continue;
      final base = (i + start) * n;
      for (var j = 0; j < n; j++) {
        y[j] += value * w[base + j];
      }
    }
  }

  static double _sigmoid(double x) => 1 / (1 + math.exp(-x.clamp(-80, 80)));
  Float64List _lstm(List<double> z) {
    var h = Float64List(128), c = Float64List(128);
    final wi = _tensors['lstm.weight_ih_l0']!.data,
        wh = _tensors['lstm.weight_hh_l0']!.data;
    final bi = _tensors['lstm.bias_ih_l0']!.data,
        bh = _tensors['lstm.bias_hh_l0']!.data;
    for (var step = 0; step < 5; step++) {
      final gates = Float64List(512);
      for (var i = 0; i < 512; i++) {
        gates[i] = bi[i] + bh[i];
      }
      _add(wi, 512, z.sublist(step * 162, (step + 1) * 162), gates);
      _add(wh, 512, h, gates);
      final next = Float64List(128);
      for (var i = 0; i < 128; i++) {
        final g = gates[i + 256].clamp(-40, 40);
        final e = math.exp(2 * g);
        c[i] =
            _sigmoid(gates[i + 128]) * c[i] +
            _sigmoid(gates[i]) * (e - 1) / (e + 1);
        final ec = math.exp(2 * c[i].clamp(-40, 40));
        next[i] = _sigmoid(gates[i + 384]) * (ec - 1) / (ec + 1);
      }
      h = next;
    }
    return h;
  }

  /// State/history contribution is shared across every legal action.
  Float64List context(List<double> z, List<double> state) {
    return _linear('dense1', [
      ..._lstm(z),
      ...state,
      ...List<double>.filled(54, 0),
    ]);
  }

  double scoreFromContext(Float64List context, List<double> action) {
    final first = Float64List.fromList(context), t = _tensors['dense1.weight']!;
    _add(t.data, 512, action, first, start: t.shape[0] - 54);
    for (var i = 0; i < first.length; i++) {
      if (first[i] < 0) first[i] = 0;
    }
    var x = first;
    for (var layer = 2; layer <= 5; layer++) {
      x = _linear('dense$layer', x, relu: true);
    }
    return _linear('dense6', x).single;
  }

  double forward(List<double> z, List<double> x) => scoreFromContext(
    context(z, x.sublist(0, x.length - 54)),
    x.sublist(x.length - 54),
  );
  List<double> scoreActions(ModelObservation obs, List<List<int>> candidates) {
    if (obs.role != role) throw ArgumentError('Role mismatch');
    final shared = context(obs.history, obs.state);
    return [
      for (final action in candidates)
        scoreFromContext(shared, encodeCards(action)),
    ];
  }
}
