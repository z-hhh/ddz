import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/main.dart';
import 'package:doudizhu/ui/game_app.dart';
import 'package:doudizhu/ui/table_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('大师手动选择、真实内置权重加载、设置截图与实际AI回合', (tester) async {
    final bytes = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
        .readAsBytesSync();
    for (final family in ['Roboto', 'Ahem', 'sans-serif']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final icons = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? '../../sdk/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    for (final name in ['transport', 'events', 'audio']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('cn.offline.doudizhu/$name'),
            (call) async => null,
          );
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: const DoudizhuApp()),
    );
    await tester.pumpAndSettle();
    final c =
        (tester.state(find.byType(GameApp)) as dynamic).c as TableController;
    expect(c.difficulty, '普通');
    expect(c.modelReady, false);
    await tester.tap(find.text('对局设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('大师'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('大师'));
      await c.prepareMaster();
    });
    await tester.pumpAndSettle();
    expect(c.difficulty, '大师');
    expect(c.modelReady, true);
    expect(c.modelLoadMs, isNotNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('../../dist/2.0.0-大师难度.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
      File('../../dist/2.0.0-首次加载.json').writeAsStringSync(
        jsonEncode({'desktopFlutterDebugAssetsAndWorkerLoadMs': c.modelLoadMs}),
      );
    });
    var revision = 0;
    await tester.runAsync(() async {
      c.single();
      c.action('bid', value: 3);
      c.selected = {c.hand.first};
      c.action('play');
      revision = c.revision;
      final clock = Stopwatch()..start();
      while (c.revision < revision + 2 || c.presentationBusy) {
        if (clock.elapsed.inSeconds > 15) {
          throw StateError('Master AI timeout: ${c.status}');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(c.game!.turn, 0);
    expect(c.modelFailed, false);
    expect(c.revision, revision + 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
