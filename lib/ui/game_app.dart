import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/rules.dart';
import 'table_widgets.dart';
import 'app_theme.dart';
import 'asset_menu_button.dart';
import 'table_controller.dart';

const cream = AppColors.ink;

class GameApp extends StatefulWidget {
  const GameApp({super.key});
  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> with WidgetsBindingObserver {
  late final TableController c;
  bool settingsExpanded = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    c = TableController()..addListener(changed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    c.audio.setActive(state == AppLifecycleState.resumed);
  }

  void changed() {
    if (!mounted) return;
    setState(() {});
    if (c.notice != null) {
      final text = c.notice!;
      c.notice = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(changed);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: c.screen != 'table',
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave();
    },
    child: Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.canvas, AppColors.canvas],
          ),
          image: c.screen == 'table'
              ? const DecorationImage(
                  image: AssetImage('assets/art/table-linen-v2.webp'),
                  fit: BoxFit.fill,
                )
              : c.screen == 'menu'
              ? const DecorationImage(
                  image: AssetImage('assets/art/home-scene-v4.webp'),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (c.screen) {
                  'table' => table(),
                  'lobby' => lobby(),
                  'rules' => rules(),
                  'audio' => soundSettings(),
                  'settings' => preferences(),
                  _ => menu(),
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget heading(String title, String subtitle) => Column(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: AppType.title,
          fontWeight: FontWeight.w900,
          color: cream,
          letterSpacing: 5,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted, height: 1.6),
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget menu() => LayoutBuilder(
    key: const ValueKey('menu'),
    builder: (context, box) {
      final content = Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Spacer(flex: 5),
            const SizedBox(width: 24),
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: '斗地主',
                      image: true,
                      child: Image.asset(
                        'assets/art/menu-title-v3.webp',
                        height: 88,
                        excludeFromSemantics: true,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: AssetMenuButton(
                        label: '单机',
                        asset: 'single',
                        onPressed: c.single,
                        height: 64,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AssetMenuButton(
                            label: '创建房间',
                            asset: 'create',
                            onPressed: c.create,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AssetMenuButton(
                            label: '加入房间',
                            asset: 'join',
                            onPressed: c.discover,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AssetMenuButton(
                            label: '设置',
                            asset: 'settings',
                            height: 48,
                            onPressed: () {
                              c.screen = 'audio';
                              c.update();
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: AssetMenuButton(
                            label: '难度',
                            asset: 'difficulty',
                            height: 48,
                            onPressed: () {
                              c.screen = 'settings';
                              c.update();
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: AssetMenuButton(
                            label: '规则',
                            asset: 'rules',
                            height: 48,
                            onPressed: () {
                              c.screen = 'rules';
                              c.update();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      return box.maxHeight > box.maxWidth
          ? RotatedBox(quarterTurns: 1, child: content)
          : content;
    },
  );
  Widget preferences() => Column(
    children: [
      topbar('设置'),
      Expanded(child: SingleChildScrollView(child: settings())),
    ],
  );
  Widget soundSettings() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: WoodPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '返回菜单',
                    onPressed: () {
                      c.screen = 'menu';
                      c.update();
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Text(
                    '设置',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '试听',
                    onPressed: () => c.audio.play('play'),
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('牌面大小'),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 0, label: Text('紧凑')),
                            ButtonSegment(value: 1, label: Text('标准')),
                            ButtonSegment(value: 2, label: Text('大')),
                          ],
                          selected: {c.audio.cardSize},
                          onSelectionChanged: (v) =>
                              c.audio.settings(size: v.first),
                        ),
                        const SizedBox(height: 16),
                        const Text('节奏'),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 3, label: Text('极速')),
                            ButtonSegment(value: 0, label: Text('快')),
                            ButtonSegment(value: 1, label: Text('标准')),
                            ButtonSegment(value: 2, label: Text('慢')),
                          ],
                          selected: {c.audio.pace},
                          onSelectionChanged: (v) =>
                              c.audio.settings(tempo: v.first),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('音效'),
                          value: c.audio.effectsOn,
                          onChanged: (v) => c.audio.settings(effects: v),
                        ),
                        SwitchListTile(
                          title: const Text('报牌'),
                          value: c.audio.speechOn,
                          onChanged: (v) => c.audio.settings(speech: v),
                        ),
                        SwitchListTile(
                          title: const Text('总静音'),
                          value: c.audio.muted,
                          onChanged: (v) => c.audio.settings(mute: v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget settings() => Material(
    color: AppColors.paper.withValues(alpha: .05),
    borderRadius: BorderRadius.circular(AppRadius.panel),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('难度'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: '简单', label: Text('简单')),
              ButtonSegment(value: '普通', label: Text('普通')),
              ButtonSegment(value: '大师', label: Text('大师')),
            ],
            selected: {c.difficulty},
            onSelectionChanged: (s) {
              c.setDifficulty(s.first);
            },
          ),
          if (c.difficulty == '大师' && !c.modelReady)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                c.modelLoadError ?? '加载中…',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          if (c.modelLoadError != null && c.difficulty == '大师')
            TextButton(
              onPressed: () => c.setDifficulty('大师'),
              child: const Text('重试加载'),
            ),
          const SizedBox(height: 16),
          const Text('联机人数'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 2, label: Text('2 人 + AI')),
              ButtonSegment(value: 3, label: Text('3 人')),
            ],
            selected: {c.capacity},
            onSelectionChanged: c.screen == 'lobby'
                ? null
                : (s) {
                    c.capacity = s.first;
                    c.update();
                  },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.volume_up_rounded),
            title: const Text('设置'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              c.audio.play('click');
              c.screen = 'audio';
              c.update();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('春天加倍'),
            value: c.spring,
            onChanged: (v) {
              c.spring = v;
              c.update();
            },
          ),
        ],
      ),
    ),
  );
  Widget topbar(String text) => Row(
    children: [
      IconButton(
        tooltip: '返回菜单',
        onPressed: leave,
        icon: const Icon(Icons.arrow_back),
      ),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: cream,
            fontSize: AppType.label,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      if (c.network)
        const Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(Icons.bluetooth, color: cream),
        ),
    ],
  );
  Widget lobby() => Column(
    key: const ValueKey('lobby'),
    children: [
      topbar(c.host ? '我的房间' : '寻找房间'),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(
                height: 145,
                child: Image.asset(
                  'assets/art/home-scene-v4.webp',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 20),
              heading(c.host ? '等朋友入座' : '附近的牌友', c.status),
              const SizedBox(height: 24),
              if (c.host) ...[
                Text(
                  '${c.connected.length + 1} / ${c.capacity} 人已入座',
                  style: const TextStyle(fontSize: AppType.heading),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: c.connected.length >= c.capacity - 1
                      ? c.start
                      : null,
                  child: const Text('开始对局'),
                ),
                const SizedBox(height: 20),
              ] else ...[
                for (final e in c.devices.entries)
                  Card(
                    child: ListTile(
                      title: Text(e.value),
                      subtitle: Text(e.key),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => c.join(e.key),
                    ),
                  ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: c.discover,
                  child: const Text('重新搜索'),
                ),
              ],
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    ],
  );
  Widget rules() => Column(
    key: const ValueKey('rules'),
    children: [
      topbar('规则'),
      const Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Text(
            '单机玩法\n选择难度后单机开局。各发 17 张，留 3 张底牌。轮流叫 1/2/3 分或不叫，最高叫分者当地主；3 分立即确定，无人叫则重新发牌。地主收底牌并先出牌。\n\n出牌规则\n3 < 4 < … < A < 2 < 小王 < 大王。支持单张、对子、三张、三带一、三带二、顺子、连对、飞机（不带、带单、带对）、四带两单/两对、炸弹、王炸。顺子至少 5 张，连对至少 3 对，飞机至少两组；连续主体不能含 2 或王。跟牌需同类型、同张数且更大；炸弹压非炸弹，王炸最大。\n\n本作规则约定\n飞机翅膀不能含主体点数；单翅可包含对子。四带两单允许带一对，四带两对必须是两个不同点数的对子。\n\n点击手牌抬起选择；提示按钮可循环切换所有可压的最小候选。连续两家不出后由上次出牌者重新领出。地主出完则地主胜，任一农民出完则农民同胜。每个炸弹/王炸翻倍；春天为农民未出牌或地主只出一次，开启时再翻倍。地主得失为农民的两倍，得分总和为零。\n\n离线联机\n房主创建房间，朋友搜索并加入。2 人时第三席由房主运行的 AI 顶上。房主负责发牌、校验和结算，客人只发送操作。房主可把掉线座位交给机器人；接管前客人可重新连接，房主掉线则本局结束。\n\n安卓使用真蓝牙 RFCOMM；iPhone 使用系统 MultipeerConnectivity，可经蓝牙或点对点 Wi-Fi 离线连接，无法强制蓝牙。不需要路由器、服务器或互联网。安卓与 iPhone 的两套协议不能互通。本版本未增加跨平台 Wi-Fi 模式。',
            style: TextStyle(height: 1.8, fontSize: AppType.label),
          ),
        ),
      ),
    ],
  );
  Future<void> leave() async {
    if (c.screen != 'table' || c.view?['phase'] == 'over') {
      await c.menu();
      return;
    }
    final exit = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.ink,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '要离开本局吗？',
                style: TextStyle(
                  color: cream,
                  fontSize: AppType.heading,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                c.network ? '离开会断开蓝牙连接。房主离开后，本局将结束。' : '当前单机对局不会保存。',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续对局'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('离开本局'),
              ),
            ],
          ),
        ),
      ),
    );
    if (exit == true) await c.menu();
  }

  Widget table() => OrientationBuilder(
    builder: (context, orientation) => orientation == Orientation.portrait
        ? RotatedBox(quarterTurns: 1, child: landscapeTable())
        : landscapeTable(),
  );

  String avatarFor(int seat, int landlord) => seat == landlord
      ? 'assets/art/player-owner-v2.webp'
      : seat == (landlord + 1) % 3
      ? 'assets/art/player-woman-v2.webp'
      : 'assets/art/player-man-v2.webp';

  Widget landscapeTable() {
    final v = c.view;
    if (v == null) return const Center(child: CircularProgressIndicator());
    final phase = v['phase'],
        lord = v['landlord'] as int,
        turn = v['turn'] as int;
    final hands = v['hands'] as List,
        recent = v['recent'] as List,
        passed = v['passed'] as List;
    final canPlay = c.myTurn && legal(c.hand, c.selected.toList(), c.target);
    Widget opponent(int i) => SizedBox(
      key: ValueKey('opponent-info-$i'),
      width: 84,
      height: 34,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: turn == i ? gold : Colors.transparent),
              boxShadow: [
                if (turn == i)
                  BoxShadow(color: gold.withValues(alpha: .3), blurRadius: 8),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: Image.asset(
                    avatarFor(i, lord),
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 13,
                    height: 13,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lord == i ? AppColors.red : AppColors.jade,
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: .7),
                    ),
                    child: Text(
                      lord == i ? '地' : '农',
                      semanticsLabel: lord == i ? '地主' : '农民',
                      style: const TextStyle(
                        color: cream,
                        fontSize: 9,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '牌友$i',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: cream, fontSize: 10, height: 1),
                ),
                Text(
                  '${(hands[i] as List).length}',
                  semanticsLabel: '剩余${(hands[i] as List).length}张',
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: gold,
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      key: const ValueKey('table'),
      builder: (context, box) {
        const side = 84.0;
        final small = box.maxHeight < 380;
        final handWidth = [52.0, 56.0, 60.0][c.audio.cardSize];
        final playedWidth = handWidth;
        final handHeight = box.maxHeight < 340 ? 114.0 : 132.0;
        const zoneGap = 20.0;
        final zoneWidth = (box.maxWidth - 24 - 2 * zoneGap) / 3;
        final zoneHeight = box.maxHeight - handHeight - 44 - 80;
        return CustomPaint(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 4,
                right: 14,
                height: 42,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '返回菜单',
                      onPressed: leave,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: cream,
                      ),
                    ),
                    if (c.hostLost || c.paused)
                      Flexible(
                        child: Text(
                          c.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: gold, fontSize: 12),
                        ),
                      ),
                    if (c.paused && !c.modelFailed)
                      IconButton(
                        tooltip: '机器人接管',
                        onPressed: c.takeover,
                        icon: const Icon(Icons.smart_toy_outlined, size: 18),
                      ),
                    const Spacer(),
                    if (c.selected.isNotEmpty)
                      IconButton(
                        tooltip: '清空选牌',
                        onPressed: () => c.setSelection({}),
                        icon: const Icon(Icons.deselect_rounded, size: 18),
                      ),
                    PopupMenuButton<int>(
                      tooltip: '牌面大小',
                      icon: const Icon(
                        Icons.text_increase_rounded,
                        color: gold,
                      ),
                      initialValue: c.audio.cardSize,
                      onSelected: (value) => c.audio.settings(size: value),
                      itemBuilder: (_) => [
                        for (final entry in ['紧凑', '标准', '大'].asMap().entries)
                          CheckedPopupMenuItem(
                            value: entry.key,
                            checked: c.audio.cardSize == entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                    ),
                    const Text(
                      '底牌',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: AppType.caption,
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (int i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: CardFace(
                          id: (v['bottom'] as List).isEmpty
                              ? -1
                              : (v['bottom'] as List)[i] as int,
                          width: 23,
                          height: 33,
                        ),
                      ),
                    const Spacer(),
                    _chip(
                      phase == 'bid'
                          ? '叫分中'
                          : '${v['bid']} 分 · ${v['multiplier']} 倍',
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                top: 40,
                width: side,
                child: opponent((c.self + 2) % 3),
              ),
              Positioned(
                right: 14,
                top: 40,
                width: side,
                child: opponent((c.self + 1) % 3),
              ),
              // 三席各有独立落牌区，本轮牌面保留到重新领出。
              for (final offset in [2, 1, 0])
                Positioned(
                  left:
                      12 +
                      (offset == 2
                              ? 0
                              : offset == 0
                              ? 1
                              : 2) *
                          (zoneWidth + zoneGap),
                  top: offset == 0 ? 92 : 76,
                  width: zoneWidth,
                  height: zoneHeight - (offset == 0 ? 16 : 4),
                  child: PlayedZone(
                    key: ValueKey('played-${(c.self + offset) % 3}'),
                    cards: List<int>.from(
                      recent[(c.self + offset) % 3] as List,
                    ),
                    passed: passed[(c.self + offset) % 3] as bool,
                    current:
                        v['owner'] == (c.self + offset) % 3 && c.target != null,
                    compact: small || offset == 0,
                    cardWidth: playedWidth,
                    highlighted:
                        c.presentationSeat == (c.self + offset) % 3 ||
                        (phase == 'over' &&
                            v['winner'] == (c.self + offset) % 3),
                  ),
                ),
              Positioned(
                bottom: handHeight - 20,
                left: side + 24,
                right: side + 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 64,
                      child: phase == 'bid'
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final n in [0, 1, 2, 3])
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: FilledButton(
                                      onPressed:
                                          c.myTurn &&
                                              (n == 0 || n > (v['bid'] as int))
                                          ? () => c.action('bid', value: n)
                                          : null,
                                      child: Text(n == 0 ? '不叫' : '$n 分'),
                                    ),
                                  ),
                              ],
                            )
                          : phase == 'over'
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TableActionButton(
                                  label: '不出',
                                  onPressed: c.myTurn && c.target != null
                                      ? () => c.action('pass')
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                TableActionButton(
                                  label: '提示',
                                  onPressed: c.myTurn ? c.hint : null,
                                ),
                                const SizedBox(width: 10),
                                TableActionButton(
                                  primary: true,
                                  label: '出牌',
                                  onPressed: canPlay
                                      ? () => c.action('play')
                                      : null,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          foregroundDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                            border: Border.all(
                              color: turn == c.self ? gold : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                            child: Image.asset(
                              avatarFor(c.self, lord),
                              width: 26,
                              height: 26,
                              fit: BoxFit.cover,
                              semanticLabel: '你的角色头像',
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        _chip('你 · ${lord == c.self ? '地主' : '农民'}'),
                        const Spacer(),
                      ],
                    ),
                    HandFan(
                      cards: c.hand,
                      selected: c.selected,
                      compact: true,
                      cardWidth: handWidth,
                      fanHeight: handHeight - 26,
                      enabled: c.myTurn && phase == 'play',
                      onChanged: c.setSelection,
                    ),
                  ],
                ),
              ),
              if (phase == 'over' && !c.presentationBusy && c.resultHidden)
                Positioned(
                  right: 16,
                  bottom: handHeight,
                  child: FilledButton(
                    onPressed: c.toggleResult,
                    child: const Text('查看结算'),
                  ),
                ),
              if (phase == 'over' && c.showResult)
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.ink.withValues(alpha: .25),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 512),
                          child: _resultPanel(v, lord, small),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _resultPanel(Map<String, dynamic> v, int lord, bool small) =>
      Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: '本局结算',
        child: WoodPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/art/result-seal-v2.webp',
                      width: 32,
                      height: 32,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    v['winner'] == lord ? '地主获胜' : '农民获胜',
                    style: TextStyle(
                      color: cream,
                      fontSize: small ? AppType.heading : AppType.title,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              const SizedBox(height: AppSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(3, (i) {
                  final score = (v['scores'] as List)[i] as int;
                  return Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.control,
                              ),
                              child: Image.asset(
                                avatarFor(i, lord),
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Flexible(
                              child: Text(
                                i == c.self ? '你' : '牌友 $i',
                                style: const TextStyle(
                                  fontSize: AppType.body,
                                  color: cream,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          '${score > 0 ? '+' : ''}$score',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: AppType.heading,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          i == lord ? '地主' : '农民',
                          style: TextStyle(
                            fontSize: AppType.caption,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              TextButton.icon(
                onPressed: c.toggleResult,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('查看牌桌'),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: c.host ? c.start : null,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(c.host ? '再来一局' : '等待房主开局'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  OutlinedButton.icon(
                    onPressed: c.menu,
                    icon: const Icon(Icons.home_rounded, size: 20),
                    label: const Text('返回菜单'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.ink.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(AppRadius.panel),
      border: Border.all(color: gold.withValues(alpha: .18)),
    ),
    child: Text(
      text,
      style: const TextStyle(color: gold, fontSize: AppType.caption),
    ),
  );
}

class PlayingCard extends StatelessWidget {
  final int id;
  final double width, height;
  final bool selected;
  const PlayingCard({
    super.key,
    required this.id,
    this.width = 54,
    this.height = 76,
    this.selected = false,
  });
  @override
  Widget build(BuildContext context) =>
      CardFace(id: id, width: width, height: height, selected: selected);
}
