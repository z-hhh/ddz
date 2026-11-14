import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/audio/game_audio.dart';
import 'package:doudizhu/game/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.audio');
  final calls = <MethodCall>[];
  var saved = <String, dynamic>{
    'effectsOn': true,
    'speechOn': false,
    'muted': false,
  };
  setUp(() {
    calls.clear();
    saved = {'effectsOn': true, 'speechOn': false, 'muted': false};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize') return saved;
          if (call.method == 'settings') {
            saved = Map<String, dynamic>.from(call.arguments as Map);
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  int count(String method) => calls.where((c) => c.method == method).length;
  test('所有音效能从Flutter资源包加载，PCM头与时长正确，总量小于1MB', () async {
    var total = 0;
    for (final effect in GameAudio.effects) {
      final data = await rootBundle.load('assets/audio/$effect.wav');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      total += bytes.length;
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      final b = ByteData.sublistView(bytes);
      expect(b.getUint16(20, Endian.little), 1);
      expect(b.getUint16(22, Endian.little), 1);
      expect(b.getUint32(24, Endian.little), 22050);
      expect(b.getUint16(34, Endian.little), 16);
      if (effect == 'click' || effect == 'select') {
        expect((bytes.length - 44) / 44100, lessThan(.080));
      }
      expect(bytes.skip(44).any((v) => v != 0), true);
    }
    expect(total, lessThan(1024 * 1024));
    expect(File('tool/synthesize_audio.py').existsSync(), true);
  });
  test('默认音效开、报牌关；设置经原生保存并恢复', () async {
    final a = GameAudio(channel: channel);
    await a.initialize();
    expect(a.effectsOn, true);
    expect(a.speechOn, false);
    expect(a.muted, false);
    a.speak('单张');
    expect(count('speak'), 0);
    await a.settings(effects: false, speech: true, mute: true);
    a.dispose();
    final b = GameAudio(channel: channel);
    await b.initialize();
    expect(b.effectsOn, false);
    expect(b.speechOn, true);
    expect(b.muted, true);
    b.dispose();
  });
  test('音效开关、语音开关和总静音独立生效，静音停止已有声音', () async {
    final a = GameAudio(channel: channel);
    await a.initialize();
    a.play('play');
    expect(count('play'), 1);
    await a.settings(effects: false, speech: true);
    a.play('play');
    a.speak('对子');
    expect(count('play'), 1);
    expect(count('speak'), 1);
    await a.settings(mute: true);
    a.play('bomb');
    a.speak('炸弹');
    expect(count('play'), 1);
    expect(count('speak'), 1);
    expect(count('stopEffects'), greaterThan(0));
    expect(count('stopSpeech'), greaterThan(0));
    await a.settings(mute: false, effects: true);
    a.play('bomb');
    expect(count('play'), 2);
    a.dispose();
  });
  testWidgets('连选节流，切后台取消延迟提示，返回前台不重播', (tester) async {
    final a = GameAudio(channel: channel);
    await a.initialize();
    for (int i = 0; i < 20; i++) {
      a.play('select');
    }
    expect(count('play'), 1);
    final g = GameState();
    a.observe(g.snapshot(0), 0);
    g.act(0, 'bid', value: 3);
    a.observe(g.snapshot(0), 0);
    final before = count('play');
    a.setActive(false);
    await tester.pump(const Duration(seconds: 1));
    a.play('bomb');
    expect(count('play'), before);
    expect(count('suspend'), 1);
    a.setActive(true);
    await tester.pump(const Duration(seconds: 1));
    expect(count('play'), before);
    a.dispose();
  });
  testWidgets('同一状态重复广播与UI重建不重播，真实出牌只响一次', (tester) async {
    final a = GameAudio(channel: channel);
    await a.initialize();
    final g = GameState();
    a.observe(g.snapshot(0), 0);
    g.act(0, 'bid', value: 3);
    a.observe(g.snapshot(0), 0);
    await tester.pump(const Duration(milliseconds: 150));
    final before = count('play');
    final card = g.hands[0].first;
    expect(g.act(0, 'play', cards: [card]), null);
    a.observe(g.snapshot(0), 0);
    a.observe(g.snapshot(0), 0);
    a.observe(g.snapshot(0), 0);
    expect(count('play'), before + 1);
    a.dispose();
  });
  test('系统音频或TTS缺失时静默降级，不抛异常', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'unavailable');
        });
    final a = GameAudio(channel: channel);
    await a.initialize();
    await a.settings(speech: true);
    a.play('play');
    a.speak('王炸');
    a.setActive(false);
    a.reset();
    a.dispose();
    await Future<void>.delayed(Duration.zero);
  });
}
