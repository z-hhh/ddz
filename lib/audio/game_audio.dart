import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/cards.dart';
import '../game/rules.dart';

/// 只在权威状态变化时发声，重建界面、重连首帧与回到前台均不重播。
class GameAudio extends ChangeNotifier {
  static const masterVolume = .46;
  static const levels = {
    'click': .36,
    'select': .36,
    'deal': .52,
    'play': .60,
    'pass': .45,
    'turn': .60,
    'bomb': .80,
    'rocket': .90,
    'spring': .94,
    'win': 1.0,
    'lose': .65,
  };
  static const effects = [
    'click',
    'select',
    'deal',
    'play',
    'pass',
    'turn',
    'bomb',
    'rocket',
    'spring',
    'win',
    'lose',
  ];
  final MethodChannel channel;
  bool effectsOn = true, speechOn = false, muted = false, active = true;
  int cardSize = 1, pace = 0;
  String difficulty = '普通';
  Future<void> presentation = Future<void>.value();
  bool _disposed = false, _changedSettings = false;
  DateTime? _lastUi;
  Map<String, dynamic>? _previous;
  final List<Timer> _pending = [];
  final Set<Completer<void>> _announcements = {};
  GameAudio({this.channel = const MethodChannel('cn.offline.doudizhu/audio')});
  Future<dynamic> _call(String method, [dynamic args]) async {
    if (_disposed) return null;
    try {
      return await channel.invokeMethod<dynamic>(method, args);
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    final result = await _call('initialize', {'effects': effects});
    if (_disposed) return;
    if (result is Map && !_changedSettings) {
      difficulty = ['简单', '普通', '大师'].contains(result['difficulty'])
          ? result['difficulty'] as String
          : '普通';
      effectsOn = result['effectsOn'] != false;
      speechOn = result['speechOn'] == true;
      muted = result['muted'] == true;
      pace = (result['pace'] is int ? result['pace'] as int : 0).clamp(0, 3);
      cardSize = (result['cardSize'] is int ? result['cardSize'] as int : 1)
          .clamp(0, 2);
    }
    notifyListeners();
  }

  Future<void> settings({
    bool? effects,
    bool? speech,
    bool? mute,
    int? size,
    int? tempo,
    String? level,
  }) async {
    _changedSettings = true;
    if (['简单', '普通', '大师'].contains(level)) difficulty = level!;
    pace = (tempo ?? pace).clamp(0, 3);
    cardSize = (size ?? cardSize).clamp(0, 2);
    effectsOn = effects ?? effectsOn;
    speechOn = speech ?? speechOn;
    muted = mute ?? muted;
    if (!_disposed) notifyListeners();
    if (muted || !effectsOn) {
      _cancel();
      await _call('stopEffects');
    }
    if (muted || !speechOn) await _call('stopSpeech');
    await _call('settings', {
      'effectsOn': effectsOn,
      'speechOn': speechOn,
      'muted': muted,
      'cardSize': cardSize,
      'pace': pace,
      'difficulty': difficulty,
    });
  }

  void play(String effect) {
    if (_disposed ||
        !active ||
        muted ||
        !effectsOn ||
        !effects.contains(effect)) {
      return;
    }
    final now = DateTime.now();
    final ui = effect == 'select' || effect == 'click';
    if (ui && _lastUi != null && now.difference(_lastUi!).inMilliseconds < 80) {
      return;
    }
    if (ui) _lastUi = now;
    unawaited(
      _call('play', {
        'effect': effect,
        'volume': masterVolume * (levels[effect] ?? .60),
      }),
    );
  }

  Future<void> speak(String text) async {
    if (!_disposed && active && !muted && speechOn) {
      await _call('speak', {'text': text}).timeout(
        const Duration(milliseconds: 2200),
        onTimeout: () {
          unawaited(_call('stopSpeech'));
          return null;
        },
      );
    }
  }

  Future<void> _announce(String text) {
    final done = Completer<void>();
    _announcements.add(done);
    // Commit the visible cards before starting speech, even when muted.
    _pending.add(
      Timer(const Duration(milliseconds: 150), () {
        speak(text).whenComplete(() {
          _announcements.remove(done);
          if (!done.isCompleted) done.complete();
        });
      }),
    );
    return done.future;
  }

  void finishRound(Map<String, dynamic> next, int self) {
    final won =
        (next['winner'] == next['landlord']) == (self == next['landlord']);
    if (next['springApplied'] == true) play('spring');
    _later(
      next['springApplied'] == true ? 760 : 0,
      () => play(won ? 'win' : 'lose'),
    );
    unawaited(
      speak(
        '${next['winner'] == next['landlord'] ? '地主' : '农民'}获胜${next['springApplied'] == true ? '，春天' : ''}',
      ),
    );
  }

  void _later(int ms, void Function() action) {
    _pending.add(
      Timer(Duration(milliseconds: ms), () {
        if (!_disposed && active && !muted) action();
      }),
    );
  }

  void _cancel() {
    for (final done in _announcements) {
      if (!done.isCompleted) done.complete();
    }
    _announcements.clear();
    for (final t in _pending) {
      t.cancel();
    }
    _pending.clear();
  }

  void setActive(bool value) {
    active = value;
    _cancel();
    if (!value) {
      unawaited(_call('suspend'));
    } else {
      unawaited(_call('resume'));
    }
  }

  void reset() {
    _previous = null;
    _cancel();
    unawaited(_call('stopSpeech'));
  }

  void observe(Map<String, dynamic> next, int self) {
    final old = _previous;
    _previous = next;
    presentation = Future<void>.value();
    if (old == null) {
      if (next['phase'] == 'bid') play('deal');
      return;
    }
    if (next['phase'] == 'bid' && old['phase'] != 'bid') {
      play('deal');
      return;
    }
    if (old['phase'] == 'bid') {
      if (next['bid'] != old['bid'] ||
          next['turn'] != old['turn'] ||
          next['phase'] != old['phase']) {
        play('click');
        speak(
          next['phase'] == 'play'
              ? '地主先出'
              : next['bid'] != old['bid']
              ? '${next['bid']}分'
              : '不叫',
        );
      }
    } else if (old['phase'] == 'play') {
      int count(Map<String, dynamic> v) =>
          (v['hands'] as List).fold<int>(0, (n, h) => n + (h as List).length);
      if (count(next) < count(old)) {
        final owner = next['owner'] as int;
        final cards = List<int>.from((next['recent'] as List)[owner] as List);
        final p = identify(cards);
        play(
          p?.type == '王炸'
              ? 'rocket'
              : p?.type == '炸弹'
              ? 'bomb'
              : 'play',
        );
        presentation = _announce(
          '${p?.type ?? '出牌'}，${cards.length}张${cards.length == 1 ? '，${label(cards.first)}' : ''}',
        );
      } else if (next['turn'] != old['turn']) {
        play('pass');
        presentation = _announce('不出');
      }
    }
    if (next['phase'] == 'play' &&
        next['turn'] == self &&
        (old['turn'] != self || old['phase'] != 'play')) {
      _later(100, () => play('turn'));
    }
  }

  @override
  void dispose() {
    _cancel();
    unawaited(_call('dispose'));
    _disposed = true;
    super.dispose();
  }
}
