import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('生成手机原生界面截图', (tester) async {
    final bytes = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
        .readAsBytesSync();
    for (final family in ['Roboto', 'Ahem', 'sans-serif']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('cn.offline.doudizhu/transport'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('cn.offline.doudizhu/events'),
          (call) async => null,
        );
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '/home/comma/.comma/station/sessions/ember/c-aae7762ba8/workspace/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: const DoudizhuApp()),
    );
    await tester.runAsync(() async {
      await Future.wait([
        for (final name in [
          'friends-v2',
          'table-linen-v2',
          'player-owner-v2',
          'player-woman-v2',
          'player-man-v2',
          'card-back-v2',
          'result-seal-v2',
        ])
          precacheImage(
            AssetImage('assets/art/$name.webp'),
            key.currentContext!,
          ),
      ]);
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/work/dist/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('横屏主菜单');
    await tester.tap(find.text('单机'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 分'));
    await tester.pumpAndSettle();
    await capture('横屏牌桌');
    await tester.tap(find.text('提示'));
    await tester.pumpAndSettle();
    await capture('横屏选牌反馈');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
