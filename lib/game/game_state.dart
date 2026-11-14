import 'cards.dart';
import 'rules.dart';

/// 唯一权威状态机：UI、AI 和网络意图都从 act 入口进入。
class GameState {
  List<List<int>> hands = [[], [], []], recent = [[], [], []];
  List<int> bottom = [], scores = [0, 0, 0], plays = [0, 0, 0];
  List<List<int>> actionHistory = [],
      playedCards = [[], [], []],
      lastActions = [[], [], []];
  List<bool> passed = [false, false, false];
  String phase = 'bid';
  int turn = 0,
      landlord = -1,
      bid = 0,
      bidder = -1,
      bids = 0,
      owner = -1,
      passes = 0,
      multiplier = 1,
      winner = -1;
  bool spring = true, springApplied = false;
  int bombCount = 0;
  Pattern? target;
  GameState() {
    deal();
  }
  void deal() {
    final d = deck();
    actionHistory = [];
    playedCards = [[], [], []];
    lastActions = [[], [], []];
    hands = List.generate(3, (i) => sorted(d.sublist(i * 17, i * 17 + 17)));
    bottom = d.sublist(51);
    recent = [[], [], []];
    passed = [false, false, false];
    plays = [0, 0, 0];
    phase = 'bid';
    turn = 0;
    landlord = -1;
    bid = 0;
    bidder = -1;
    bids = 0;
    owner = -1;
    passes = 0;
    multiplier = 1;
    springApplied = false;
    bombCount = 0;
    winner = -1;
    target = null;
  }

  String? act(
    int seat,
    String action, {
    List<int> cards = const [],
    int value = 0,
  }) {
    if (action == 'again') {
      if (phase != 'over') return '本局尚未结束';
      deal();
      return null;
    }
    if (seat != turn) return '还没轮到你';
    if (phase == 'bid') {
      if (action != 'bid' ||
          value < 0 ||
          value > 3 ||
          value != 0 && value <= bid) {
        return '请选择更高的叫分，或不叫';
      }
      bids++;
      if (value > bid) {
        bid = value;
        bidder = seat;
      }
      if (value == 3 || bids == 3) {
        if (bidder < 0) {
          deal();
          return null;
        }
        landlord = bidder;
        hands[landlord] = sorted([...hands[landlord], ...bottom]);
        turn = landlord;
        phase = 'play';
      } else {
        turn = (turn + 1) % 3;
      }
      return null;
    }
    if (phase != 'play') return '本局已结束';
    if (action == 'pass') {
      if (target == null) return '领出时不能不出';
      actionHistory.add([]);
      lastActions[seat] = [];
      passed[seat] = true;
      passes++;
      if (passes == 2) {
        target = null;
        passes = 0;
        turn = owner;
        recent = [[], [], []];
        passed = [false, false, false];
      } else {
        turn = (turn + 1) % 3;
      }
      return null;
    }
    if (action != 'play' || !legal(hands[seat], cards, target)) {
      return '牌型不合法或不能压过上家';
    }
    final p = identify(cards)!;
    actionHistory.add(sorted(cards));
    playedCards[seat].addAll(cards);
    lastActions[seat] = sorted(cards);
    hands[seat].removeWhere(cards.contains);
    recent[seat] = sorted(cards);
    passed[seat] = false;
    plays[seat]++;
    target = p;
    owner = seat;
    passes = 0;
    if (p.type == '炸弹' || p.type == '王炸') {
      multiplier *= 2;
      bombCount++;
    }
    if (hands[seat].isEmpty) {
      winner = seat;
      phase = 'over';
      final lordWins = seat == landlord;
      if (spring &&
          (lordWins
              ? List.generate(
                  3,
                  (i) => i,
                ).where((i) => i != landlord).every((i) => plays[i] == 0)
              : plays[landlord] == 1)) {
        multiplier *= 2;
        springApplied = true;
      }
      final points = bid * multiplier;
      for (int i = 0; i < 3; i++) {
        scores[i] += (i == landlord ? 2 : -1) * (lordWins ? 1 : -1) * points;
      }
    } else {
      turn = (turn + 1) % 3;
    }
    return null;
  }

  Map<String, dynamic> snapshot(int seat) => {
    'phase': phase,
    'owner': owner,
    'turn': turn,
    'landlord': landlord,
    'bid': bid,
    'bottom': landlord >= 0 ? List<int>.from(bottom) : <int>[],
    'hands': List.generate(
      3,
      (i) => i == seat
          ? List<int>.from(hands[i])
          : List.filled(hands[i].length, -1),
    ),
    'recent': [for (final cards in recent) List<int>.from(cards)],
    'passed': List<bool>.from(passed),
    'scores': List<int>.from(scores),
    'winner': winner,
    'multiplier': multiplier,
    'springApplied': springApplied,
    'bombCount': bombCount,
    'target': target == null
        ? null
        : {
            'type': target!.type,
            'high': target!.high,
            'length': target!.length,
            'chain': target!.chain,
          },
  };
}
