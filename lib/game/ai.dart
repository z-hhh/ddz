import 'cards.dart';
import 'rules.dart';

/// 按点数组合构造候选：可拆对子、三张和炸弹。所有候选经过同一规则校验。
List<List<int>> moves(List<int> hand, Pattern? prev) {
  final g = groups(hand), out = <List<int>>[], seen = <String>{};
  void add(List<int> c) {
    final p = identify(c);
    if (p == null || !beats(p, prev)) return;
    final key = sorted(c).join(',');
    if (seen.add(key)) out.add(sorted(c));
  }

  List<List<int>> wings(List<int> core, int amount, bool pairs) {
    final cg = groups(core),
        entries = g.entries.where((e) => !cg.containsKey(e.key)).toList();
    final result = <List<int>>[];
    void walk(int i, int left, List<int> picked) {
      if (result.length >= 300) return;
      if (left == 0) {
        result.add(picked);
        return;
      }
      if (i == entries.length) return;
      final e = entries[i];
      final max = pairs ? (e.value.length >= 2 ? 1 : 0) : e.value.length;
      for (int take = 0; take <= max && take <= left; take++) {
        walk(i + 1, left - take, [
          ...picked,
          ...e.value.take(pairs ? take * 2 : take),
        ]);
      }
    }

    walk(0, amount, []);
    return result;
  }

  void attach(List<int> core, int count, bool pair) {
    for (final w in wings(core, count, pair)) {
      add([...core, ...w]);
    }
  }

  for (final e in g.entries) {
    for (int count = 1; count <= e.value.length; count++) {
      final core = e.value.take(count).toList();
      add(core);
      if (count == 3) {
        attach(core, 1, false);
        attach(core, 1, true);
      }
      if (count == 4) {
        attach(core, 2, false);
        attach(core, 2, true);
      }
    }
  }
  if (g.containsKey(16) && g.containsKey(17)) add([52, 53]);
  for (int multiplicity = 1; multiplicity <= 3; multiplicity++) {
    final minimum = multiplicity == 1
        ? 5
        : multiplicity == 2
        ? 3
        : 2;
    for (int start = 3; start <= 14; start++) {
      final core = <int>[];
      for (int end = start; end <= 14; end++) {
        if ((g[end]?.length ?? 0) < multiplicity) break;
        core.addAll(g[end]!.take(multiplicity));
        final k = end - start + 1;
        if (k < minimum) continue;
        add([...core]);
        if (multiplicity == 3) {
          attach([...core], k, false);
          attach([...core], k, true);
        }
      }
    }
  }
  out.sort((a, b) {
    final x = identify(a)!, y = identify(b)!;
    int weight(Pattern p) => p.type == '王炸'
        ? 2
        : p.type == '炸弹'
        ? 1
        : 0;
    final bomb = weight(x).compareTo(weight(y));
    if (bomb != 0) return bomb;
    final h = x.high.compareTo(y.high);
    return h != 0 ? h : b.length.compareTo(a.length);
  });
  return out;
}

List<int> choose(List<int> hand, Pattern? prev, {bool normal = true}) {
  final all = moves(hand, prev);
  if (all.isEmpty) return [];
  if (normal && prev == null) {
    all.sort((a, b) {
      final ca = hand.length - a.length, cb = hand.length - b.length;
      return ca != cb
          ? ca.compareTo(cb)
          : identify(a)!.high.compareTo(identify(b)!.high);
    });
  }
  return all.first;
}

int bidFor(List<int> hand) => hand.where((c) => rank(c) >= 15).length >= 3
    ? 3
    : hand.where((c) => rank(c) >= 14).length >= 3
    ? 2
    : 1;
