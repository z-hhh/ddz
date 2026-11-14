import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/ui/table_widgets.dart';
import 'package:doudizhu/main.dart';

void main() {
  testWidgets('横滑连续选择、反向取消、非本人回合不可选择', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = <int>{};
    var enabled = true;
    late StateSetter refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return Align(
                alignment: Alignment.topCenter,
                child: HandFan(
                  cards: List.generate(20, (i) => i),
                  selected: selected,
                  compact: false,
                  enabled: enabled,
                  onChanged: (next) => setState(() => selected = next),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cardFaces = find.descendant(
      of: find.byType(HandFan),
      matching: find.byType(CardFace),
    );
    final start = tester.getTopLeft(cardFaces.at(0)) + const Offset(10, 20);
    final end = tester.getTopLeft(cardFaces.at(4)) + const Offset(10, 20);
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();
    expect(selected, {0, 1, 2, 3, 4});
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    refresh(() => enabled = false);
    await tester.pump();
    await tester.tapAt(start);
    await tester.pump();
    expect(selected, isEmpty);
  });
  testWidgets('空选择禁用出牌、领出禁用不出、退出确认可取消', (tester) async {
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
    await tester.pumpWidget(const DoudizhuApp());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('单机'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 分'));
    await tester.pumpAndSettle();
    final play = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '出牌'),
    );
    expect(play.onPressed, null);
    final pass = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '不出'),
    );
    expect(pass.onPressed, null);
    await tester.tap(find.byTooltip('返回菜单'));
    await tester.pumpAndSettle();
    expect(find.text('要离开本局吗？'), findsOneWidget);
    await tester.tap(find.text('继续对局'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '不出'))
          .onPressed,
      null,
    );
    await tester.tap(find.byTooltip('返回菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('离开本局'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('斗地主'), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
