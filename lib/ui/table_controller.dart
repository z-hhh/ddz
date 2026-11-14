import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/game_state.dart';
import '../game/rules.dart';
import '../game/ai.dart';
import '../game/protocol.dart';
import '../transport/local_transport.dart';
import '../audio/game_audio.dart';
import '../model/master_worker.dart';
import '../model/game_observation.dart';

class TableController extends ChangeNotifier {
  final LocalTransport transport;
  final GameAudio audio = GameAudio();
  TableController({LocalTransport? transport})
    : transport = transport ?? BluetoothTransport() {
    audio.addListener(update);
    unawaited(audio.initialize());
    _sub = this.transport.events.listen(
      _event,
      onError: (Object e) => toast('蓝牙服务异常，请返回菜单重试'),
    );
    _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _ai, _heartbeat, _hold, _ceiling;
  final Random random = Random();
  bool presentationBusy = false, resultHidden = false;
  int? presentationSeat;
  int _generation = 0;
  bool get showResult =>
      view?['phase'] == 'over' && !presentationBusy && !resultHidden;
  void toggleResult() {
    resultHidden = !resultHidden;
    update();
  }

  int get thinkingMs => switch (audio.pace) {
    3 => 200 + random.nextInt(201),
    0 => 600 + random.nextInt(201),
    2 => 1000 + random.nextInt(801),
    _ => 600 + random.nextInt(601),
  };
  int get dwellMs => switch (audio.pace) {
    3 => 200,
    0 => 600,
    2 => 900 + random.nextInt(301),
    _ => 600 + random.nextInt(201),
  };
  void _cancelPresentation() {
    _generation++;
    modelThinking = false;
    _hold?.cancel();
    _ceiling?.cancel();
    presentationBusy = false;
    presentationSeat = null;
    resultHidden = false;
  }

  void _present(Map<String, dynamic> next) {
    final old = view;
    final action =
        old?['phase'] == 'play' &&
        (old?['turn'] != next['turn'] || next['phase'] == 'over');
    view = next;
    audio.observe(next, self);
    if (!action) return;
    _cancelPresentation();
    _ai?.cancel();
    final generation = _generation;
    final terminal = next['phase'] == 'over';
    presentationBusy = true;
    presentationSeat = terminal ? next['winner'] as int : old!['turn'] as int;
    var held = false, spoken = false;
    void release() {
      if (generation != _generation || !presentationBusy) return;
      _hold?.cancel();
      _ceiling?.cancel();
      presentationBusy = false;
      presentationSeat = null;
      if (terminal) audio.finishRound(next, self);
      update();
      if (host) _schedule();
    }

    _hold = Timer(Duration(milliseconds: terminal ? 1200 : dwellMs), () {
      held = true;
      if (spoken) release();
    });
    // Cap speech waiting without blocking UI or shortening the final reveal.
    final speechBudget = terminal
        ? 1600
        : switch (audio.pace) {
            3 => 200,
            0 => 1000,
            2 => 2000,
            _ => 1500,
          };
    _ceiling = Timer(Duration(milliseconds: speechBudget), release);
    audio.presentation.then((_) {
      if (generation != _generation) return;
      spoken = true;
      if (held) release();
    });
  }

  GameState? game;
  Map<String, dynamic>? view;
  String screen = 'menu', status = '', session = '';
  String get difficulty => audio.difficulty;
  set difficulty(String value) {
    unawaited(setDifficulty(value));
  }

  MasterWorker? _master;
  Future<void>? _masterLoading;
  bool modelReady = false, modelThinking = false, modelFailed = false;
  double? modelLoadMs;
  String? modelLoadError;
  Future<void> prepareMaster() => _masterLoading ??= _loadMaster();
  Future<void> _loadMaster() async {
    modelLoadError = null;
    final clock = Stopwatch()..start();
    final worker = MasterWorker();
    _master = worker;
    update();
    try {
      final weights = <String, Uint8List>{};
      for (final role in ['landlord', 'landlord_down', 'landlord_up']) {
        final data = await rootBundle.load('assets/models/$role.dzf');
        weights[role] = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      }
      if (_disposed) {
        worker.dispose();
        return;
      }
      await worker.initialize(weights);
      if (_disposed) return;
      modelLoadMs = clock.elapsedMicroseconds / 1000;
      modelReady = true;
      update();
    } catch (e) {
      worker.dispose();
      if (!_disposed) {
        _master = null;
        _masterLoading = null;
        modelLoadError = '大师模型加载失败，请重试';
        toast('$modelLoadError：$e');
      }
      rethrow;
    }
  }

  Future<void> setDifficulty(String value) async {
    if (!['简单', '普通', '大师'].contains(value)) return;
    await audio.settings(level: value);
    if (value == '大师') {
      try {
        await prepareMaster();
      } catch (_) {
        /* Error is visible; no rule fallback. */
      }
    }
  }

  bool _disposed = false;

  String? notice;
  bool host = false,
      network = false,
      started = false,
      spring = true,
      hostLost = false;
  int self = 0, capacity = 2, seq = 0, revision = 0;
  IntentGuard? guard;
  final peers = <String, int>{},
      connected = <String>{},
      devices = <String, String>{},
      deadlines = <String, PeerDeadline>{};
  Set<int> selected = {};
  int hintIndex = 0;
  String? hostPeer;
  void toast(String text) {
    notice = text;
    notifyListeners();
  }

  void update() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> safe(Future<void> Function() f) async {
    try {
      await f();
    } on PlatformException catch (e) {
      toast(e.message ?? '蓝牙操作失败，请重试');
    } catch (_) {
      toast('操作失败，请返回菜单重试');
    }
  }

  void single() {
    if (difficulty == '大师' && !modelReady) {
      unawaited(
        prepareMaster()
            .then((_) {
              if (!_disposed && screen == 'menu') single();
            })
            .catchError((Object _) {}),
      );
      return;
    }
    _cancelPresentation();
    modelFailed = false;
    audio.reset();
    audio.play('click');
    network = false;
    host = true;
    self = 0;
    started = true;
    hostLost = false;
    game = GameState()..spring = spring;
    screen = 'table';
    _publish();
  }

  Future<void> create() async {
    audio.play('click');
    await safe(() async {
      await reset();
      network = true;
      host = true;
      self = 0;
      screen = 'lobby';
      session =
          '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
      guard = IntentGuard(session);
      status = '等待朋友加入，请允许系统蓝牙可发现请求';
      update();
      await transport.createRoom();
    });
  }

  Future<void> discover() async {
    audio.play('click');
    await safe(() async {
      await reset();
      network = true;
      host = false;
      screen = 'lobby';
      status = '正在寻找房主（30 秒）…';
      update();
      await transport.discover();
    });
  }

  Future<void> join(String id) async {
    hostPeer = id;
    status = '正在连接，请完成系统配对（30 秒）…';
    update();
    await safe(() => transport.join(id));
  }

  void start() {
    if (difficulty == '大师' && !modelReady) {
      unawaited(
        prepareMaster()
            .then((_) {
              if (!_disposed) start();
            })
            .catchError((Object _) {}),
      );
      return;
    }
    _cancelPresentation();
    audio.play('click');
    modelFailed = false;
    if (!host || (network && connected.length < capacity - 1)) {
      toast('还需要 ${capacity - 1 - connected.length} 位朋友加入');
      return;
    }
    audio.reset();
    game = GameState()..spring = spring;
    started = true;
    screen = 'table';
    _publish();
  }

  Future<void> reset() async {
    _cancelPresentation();
    modelFailed = false;
    audio.reset();
    _ai?.cancel();
    started = false;
    game = null;
    view = null;
    selected.clear();
    peers.clear();
    connected.clear();
    deadlines.clear();
    devices.clear();
    hostPeer = null;
    hostLost = false;
    revision = 0;
    seq = 0;
    await transport.dispose();
  }

  Future<void> menu() async {
    await safe(reset);
    screen = 'menu';
    update();
  }

  void _send(String? peer, Map<String, dynamic> m) {
    unawaited(
      transport.send(peer, m).catchError((Object e) {
        toast('发送失败，请检查蓝牙连接后重试');
      }),
    );
  }

  void _event(Map<String, dynamic> e) {
    final type = e['type'];
    final peer = e['peer'] as String?;
    if (type == 'error') {
      toast(e['message'] as String? ?? '蓝牙连接失败');
      return;
    }
    if (type == 'found') {
      devices[e['id'] as String] = e['name'] as String;
      update();
      return;
    }
    if (type == 'scanDone') {
      status = '搜索结束，未找到可点“重新搜索”；房主需要允许可发现';
      update();
      return;
    }
    if (type == 'connected' && peer != null) {
      if (host) {
        guard?.resetPeer(peer);
        if (!peers.containsKey(peer)) {
          final seats = peers.values.toSet();
          final available = [
            1,
            2,
          ].where((i) => i < capacity && !seats.contains(i));
          if (available.isEmpty) {
            _send(peer, {'kind': 'error', 'text': '房间已满'});
            return;
          }
          peers[peer] = available.first;
        }
        connected.add(peer);
        deadlines[peer] = PeerDeadline(DateTime.now());
        status = '已连接 ${connected.length} 位朋友';
        _send(peer, {
          'kind': 'welcome',
          'v': protocolVersion,
          'session': session,
          'seat': peers[peer],
        });
        if (started) {
          _publish();
        } else {
          update();
        }
      } else {
        if (hostPeer != null && hostPeer != peer) return;
        audio.reset();
        hostPeer = peer;
        hostLost = false;
        connected.add(peer);
        deadlines[peer] = PeerDeadline(DateTime.now());
        status = '已连接，等待房主开局';
        update();
      }
      return;
    }
    if (type == 'left' && peer != null) {
      _left(peer);
      return;
    }
    if (type != 'message' || peer == null) return;
    final raw = e['message'];
    if (raw is! Map) return;
    final m = Map<String, dynamic>.from(raw);
    deadlines[peer]?.touch(DateTime.now());
    if (m['kind'] == 'ping') {
      _send(peer, {'kind': 'pong'});
      return;
    }
    if (m['kind'] == 'pong') return;
    if (host) {
      if (m['kind'] != 'intent' ||
          !connected.contains(peer) ||
          guard?.accept(peer, m) != true) {
        return;
      }
      if (m['revision'] != revision) {
        _send(peer, {'kind': 'error', 'text': '牌局已更新，请重新操作'});
        return;
      }
      final action = m['action'];
      final value = m['value'];
      final cards = m['cards'];
      if (action is! String ||
          value is! int ||
          cards is! List ||
          cards.any((c) => c is! int)) {
        return;
      }
      _act(peers[peer]!, action, value, List<int>.from(cards));
    } else if (peer == hostPeer) {
      if (m['kind'] == 'welcome') {
        session = m['session'] as String;
        self = m['seat'] as int;
        seq = 0;
        status = '已连接，等待房主开局';
        update();
      }
      if (m['kind'] == 'state' &&
          m['session'] == session &&
          m['state'] is Map) {
        _present(Map<String, dynamic>.from(m['state'] as Map));
        revision = m['revision'] as int;
        selected.clear();
        hintIndex = 0;
        started = true;
        screen = 'table';
        update();
      }
      if (m['kind'] == 'error') toast(m['text'] as String? ?? '操作未成功');
    }
  }

  void _left(String peer) {
    if (!connected.remove(peer)) return;
    deadlines.remove(peer);
    if (host) {
      status = '座位 ${peers[peer]} 已掉线，等待重连或由机器人接管';
      _ai?.cancel();
      toast(status);
    } else {
      hostLost = true;
      status = '房主连接已断开，本局结束。请返回菜单重新加入房间。';
      toast(status);
    }
    update();
  }

  void takeover() {
    if (!host) return;
    final lost = peers.keys.where((p) => !connected.contains(p)).toList();
    for (final p in lost) {
      peers.remove(p);
    }
    status = '掉线座位已由机器人接管';
    _publish();
  }

  void _tick() {
    if (!network) return;
    final now = DateTime.now();
    for (final p in connected.toList()) {
      if (deadlines[p]?.expired(now) == true) {
        _left(p);
      } else {
        _send(p, {'kind': host ? 'ping' : 'pong'});
      }
    }
  }

  bool get paused =>
      modelFailed ||
      host && network && peers.keys.any((p) => !connected.contains(p));
  bool get myTurn =>
      view != null &&
      view!['turn'] == self &&
      view!['phase'] != 'over' &&
      !presentationBusy &&
      !hostLost &&
      !paused;
  List<int> get hand => view == null
      ? []
      : List<int>.from((view!['hands'] as List)[self] as List);
  Pattern? get target {
    final m = view?['target'];
    return m is Map
        ? Pattern(
            m['type'] as String,
            m['high'] as int,
            m['length'] as int,
            m['chain'] as int,
          )
        : null;
  }

  void action(String action, {int value = 0}) {
    if (action != 'again' && !myTurn) {
      toast('请等待轮到你');
      return;
    }
    if (hostLost) return;
    if (host) {
      _act(self, action, value, selected.toList());
    } else if (hostPeer != null) {
      _send(hostPeer, {
        'kind': 'intent',
        'v': protocolVersion,
        'session': session,
        'seq': ++seq,
        'revision': revision,
        'action': action,
        'value': value,
        'cards': selected.toList(),
      });
    }
  }

  void _act(int seat, String action, int value, List<int> cards) {
    if (game == null || paused || presentationBusy) return;
    if (action == 'again' && seat != 0) {
      toast('请等待房主开始下一局');
      return;
    }
    final error = game!.act(seat, action, value: value, cards: cards);
    if (error != null) {
      final peer = peers.entries.where((e) => e.value == seat);
      if (seat == self) {
        toast(error);
      } else if (peer.isNotEmpty) {
        _send(peer.first.key, {'kind': 'error', 'text': error});
      }
      return;
    }
    _publish();
  }

  void _publish() {
    if (game == null) return;
    revision++;
    _present(game!.snapshot(self));
    selected.clear();
    hintIndex = 0;
    if (network) {
      for (final p in connected) {
        _send(p, {
          'kind': 'state',
          'session': session,
          'revision': revision,
          'state': game!.snapshot(peers[p]!),
        });
      }
    }
    update();
    _schedule();
  }

  void _schedule() {
    _ai?.cancel();
    if (game == null ||
        game!.phase == 'over' ||
        paused ||
        presentationBusy ||
        modelThinking) {
      return;
    }
    final seat = game!.turn;
    if (seat == 0 || network && peers.values.contains(seat)) return;
    final delay = game!.phase == 'bid' ? min(thinkingMs, 800) : thinkingMs;
    _ai = Timer(Duration(milliseconds: delay), () {
      final g = game!;
      if (g.phase == 'bid') {
        final bid = bidFor(g.hands[seat]);
        _act(seat, 'bid', bid > g.bid ? bid : 0, []);
      } else {
        if (difficulty == '大师') {
          unawaited(_masterAct(g, seat));
        } else {
          final cards = choose(
            g.hands[seat],
            g.target,
            normal: difficulty == '普通',
          );
          _act(seat, cards.isEmpty ? 'pass' : 'play', 0, cards);
        }
      }
    });
  }

  Future<void> _masterAct(GameState g, int seat) async {
    if (modelThinking) return;
    final generation = _generation, expectedRevision = revision;
    modelThinking = true;
    update();
    try {
      await prepareMaster();
      final candidates = moves(g.hands[seat], g.target);
      if (g.target != null) candidates.add([]);
      if (candidates.isEmpty) throw StateError('No legal candidates');
      final result = await _master!.decide(
        gameObservation(g, seat),
        candidates,
      );
      if (_disposed ||
          generation != _generation ||
          !identical(g, game) ||
          revision != expectedRevision ||
          paused ||
          g.turn != seat) {
        return;
      }
      final cards = candidates[result['index'] as int];
      // The authority validates the selected candidate again inside GameState.act.
      modelThinking = false;
      _act(seat, cards.isEmpty ? 'pass' : 'play', 0, cards);
    } catch (e) {
      if (!_disposed && generation == _generation) {
        modelFailed = true;
        status = '大师模型异常，本局已暂停，请返回菜单重试';
        toast('$status：$e');
      }
    } finally {
      if (!_disposed && generation == _generation) {
        modelThinking = false;
        update();
      }
    }
  }

  void hint() {
    audio.play('click');
    if (!myTurn || view?['phase'] != 'play') return;
    final all = moves(hand, target);
    if (all.isEmpty) {
      toast('没有可压牌，请选择“不出”');
      return;
    }
    selected = all[hintIndex % all.length].toSet();
    hintIndex++;
    update();
  }

  void setSelection(Set<int> ids) {
    if (!myTurn || setEquals(selected, ids)) return;
    selected = ids.where(hand.contains).toSet();
    hintIndex = 0;
    audio.play('select');
    HapticFeedback.selectionClick();
    update();
  }

  void select(int id) {
    if (!myTurn) return;
    if (!selected.add(id)) selected.remove(id);
    audio.play('select');
    hintIndex = 0;
    update();
  }

  @override
  void dispose() {
    _disposed = true;
    _master?.dispose();
    _cancelPresentation();
    audio.removeListener(update);
    audio.dispose();
    _ai?.cancel();
    _heartbeat?.cancel();
    _sub?.cancel();
    unawaited(transport.dispose());
    super.dispose();
  }
}
