import '../game/game_state.dart';
import 'douzero.dart';

ModelObservation gameObservation(GameState g, int seat) => observation(
  seat: seat,
  landlord: g.landlord,
  hand: List<int>.from(g.hands[seat]),
  counts: [for (final hand in g.hands) hand.length],
  played: g.playedCards,
  last: g.lastActions,
  history: g.actionHistory,
  bombs: g.bombCount,
);
