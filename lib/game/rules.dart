import 'cards.dart';

class Pattern {
  final String type;
  final int high, length, chain;
  const Pattern(this.type, this.high, this.length, [this.chain = 1]);
}

bool consecutive(List<int> ranks) =>
    ranks.isNotEmpty &&
    ranks.last <= 14 &&
    List.generate(ranks.length, (i) => ranks.first + i).join(',') ==
        ranks.join(',');

/// 飞机单翅允许一对作为两张单牌；翅膀不可含主体点数。四带两单允许一对。
Pattern? identify(List<int> cards) {
  if (cards.isEmpty ||
      cards.toSet().length != cards.length ||
      cards.any((c) => c < 0 || c > 53)) {
    return null;
  }
  final g = groups(cards), n = cards.length;
  final rs = g.keys.toList();
  final cs = g.values.map((v) => v.length).toList()..sort();
  Pattern p(String t, [int? h, int chain = 1]) =>
      Pattern(t, h ?? rs.last, n, chain);
  if (n == 2 && rs.contains(16) && rs.contains(17)) return p('王炸');
  if (g.length == 1) {
    if (n == 1) return p('单张');
    if (n == 2) return p('对子');
    if (n == 3) return p('三张');
    if (n == 4) return p('炸弹');
  }
  int key(int count) =>
      g.entries.firstWhere((e) => e.value.length == count).key;
  if (n == 4 && cs.join() == '13') return p('三带一', key(3));
  if (n == 5 && cs.join() == '23') return p('三带二', key(3));
  if (n >= 5 && g.length == n && consecutive(rs)) return p('顺子', rs.last, n);
  if (n >= 6 && n.isEven && cs.every((v) => v == 2) && consecutive(rs)) {
    return p('连对', rs.last, rs.length);
  }
  if (n == 6 && cs.contains(4)) return p('四带二单', key(4));
  if (n == 8 && cs.join() == '224') return p('四带二对', key(4));
  // 枚举连续三张主体，避免把四张同点误当作翅膀。
  for (final width in [3, 4, 5]) {
    if (n % width != 0) continue;
    final k = n ~/ width;
    if (k < 2) continue;
    for (int start = 3; start + k - 1 <= 14; start++) {
      final core = List.generate(k, (i) => start + i);
      if (!core.every((r) => g[r]?.length == 3)) continue;
      final wings = g.entries.where((e) => !core.contains(e.key)).toList();
      if (width == 3 && wings.isEmpty) return p('飞机', core.last, k);
      if (width == 4 && wings.fold<int>(0, (a, e) => a + e.value.length) == k) {
        return p('飞机带单', core.last, k);
      }
      if (width == 5 &&
          wings.length == k &&
          wings.every((e) => e.value.length == 2)) {
        return p('飞机带对', core.last, k);
      }
    }
  }
  return null;
}

bool beats(Pattern next, Pattern? prev) {
  if (prev == null) return true;
  if (prev.type == '王炸') return false;
  if (next.type == '王炸') return true;
  if (next.type == '炸弹' && prev.type != '炸弹') return true;
  return next.type == prev.type &&
      next.length == prev.length &&
      next.chain == prev.chain &&
      next.high > prev.high;
}

bool legal(List<int> hand, List<int> cards, Pattern? prev) =>
    cards.toSet().length == cards.length &&
    cards.every(hand.contains) &&
    identify(cards) != null &&
    beats(identify(cards)!, prev);
