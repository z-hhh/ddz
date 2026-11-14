import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/main.dart';
import 'package:doudizhu/ui/game_app.dart';
import 'package:doudizhu/ui/table_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
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
  });
  testWidgets('竖屏进入后牌桌横向显示，叫分与出牌无异常', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DoudizhuApp());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('斗地主'), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.ensureVisible(find.bySemanticsLabel('单机'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('单机'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '3 分'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('3 分'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '不出'))
          .onPressed,
      null,
    );
    await tester.tap(find.text('提示'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    final play = find.byWidgetPredicate(
      (w) => w is Text && w.data != null && w.data == '出牌',
    );
    expect(play, findsOneWidget);
    await tester.tap(play);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('844×390 横屏牌桌无溢出', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DoudizhuApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('单机'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('单机'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('720×320 启动与退出对局都保持横屏', (tester) async {
    tester.view.physicalSize = const Size(720, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final orientations = <List<dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientations.add(List<dynamic>.from(call.arguments as List));
          }
          return null;
        });
    await tester.pumpWidget(const DoudizhuApp());
    await tester.pumpAndSettle();
    expect(orientations.single, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    await tester.ensureVisible(find.bySemanticsLabel('单机'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('单机'));
    await tester.pumpAndSettle();
    expect(orientations.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    expect(tester.takeException(), null);
    await tester.tap(find.byTooltip('返回菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('离开本局'));
    await tester.pumpAndSettle();
    expect(
      orientations.every((v) => !v.contains('DeviceOrientation.portraitUp')),
      true,
    );
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('结算面板显示分数并支持再来一局', (tester) async {
    tester.view.physicalSize = const Size(720, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DoudizhuApp());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('单机'));
    await tester.pumpAndSettle();
    final TableController c =
        (tester.state(find.byType(GameApp)) as dynamic).c as TableController;
    c.view = {
      ...c.view!,
      'phase': 'over',
      'winner': 0,
      'landlord': 0,
      'scores': [12, -6, -6],
    };
    c.update();
    await tester.pumpAndSettle();
    expect(find.text('地主获胜'), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);
    expect(find.text('-6'), findsNWidgets(2));
    expect(tester.takeException(), null);
    await tester.tap(find.text('再来一局'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '3 分'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
