import 'dart:convert';
import 'dart:io';

import 'package:doudizhu/model/douzero.dart';

void main() {
  final models = {
    for (final r in ['landlord', 'landlord_down', 'landlord_up'])
      r: DouZeroNetwork(File('assets/models/$r.dzf').readAsBytesSync()),
  };
  final references =
      jsonDecode(File('tool/model/reference.json').readAsStringSync()) as List;
  var maximum = 0.0;
  for (final raw in references) {
    final m = raw as Map;
    final value = models[m['role']]!.forward(
      List<double>.from(m['z'] as List),
      List<double>.from(m['x'] as List),
    );
    final expected = (m['value'] as num).toDouble(),
        error = (value - expected).abs();
    if (error > maximum) maximum = error;
    if (error > 0.0001) {
      throw StateError('Forward mismatch $value != $expected');
    }
  }
  print(
    jsonEncode({
      'vectors': references.length,
      'max_absolute_error': maximum,
      'tolerance': 0.0001,
    }),
  );
}
