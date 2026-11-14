import 'dart:math';

/// 牌 ID 0–51 为普通牌，52/53 为小王/大王。点数 3–17。
int rank(int id) => id < 52 ? id ~/ 4 + 3 : id - 36;
String label(int id) => const [
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'J',
  'Q',
  'K',
  'A',
  '2',
  '小王',
  '大王',
][rank(id) - 3];
String suit(int id) => id < 52 ? const ['♠', '♥', '♣', '♦'][id % 4] : '★';
bool red(int id) => id == 53 || id < 52 && id.isOdd;
List<int> sorted(Iterable<int> cards) => cards.toList()
  ..sort(
    (a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : a.compareTo(b),
  );
List<int> deck([Random? random]) =>
    List.generate(54, (i) => i)..shuffle(random ?? Random.secure());
Map<int, List<int>> groups(List<int> cards) {
  final out = <int, List<int>>{};
  for (final c in sorted(cards)) {
    out.putIfAbsent(rank(c), () => []).add(c);
  }
  return out;
}
