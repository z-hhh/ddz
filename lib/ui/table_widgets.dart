import 'dart:math';

import 'package:flutter/material.dart';

import '../game/cards.dart';
import 'app_theme.dart';

const gold = AppColors.gold;

/// 程序绘制绒面纹理与桌沿，无图片资源和网络依赖。
class TableSurface extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.2),
          radius: 1,
          colors: [AppColors.jade, AppColors.ink],
        ).createShader(rect),
    );
    final p = Paint()
      ..color = AppColors.paper.withValues(alpha: .025)
      ..strokeWidth = .7;
    for (double x = -size.height; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
    final border = RRect.fromRectAndRadius(
      rect.deflate(12),
      const Radius.circular(AppRadius.panel),
    );
    canvas.drawRRect(
      border,
      Paint()
        ..color = gold.withValues(alpha: .16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(17),
        const Radius.circular(AppRadius.panel),
      ),
      Paint()
        ..color = gold.withValues(alpha: .06)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant TableSurface oldDelegate) => false;
}

class SeatTile extends StatelessWidget {
  final String name;
  final int count, score;
  final int avatarVariant;
  final bool active, lord, compact;
  final List<int> played;
  final bool passed;
  const SeatTile({
    super.key,
    required this.name,
    this.avatarVariant = 0,
    required this.count,
    required this.score,
    required this.active,
    required this.lord,
    required this.compact,
    required this.played,
    required this.passed,
  });
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    padding: EdgeInsets.all(compact ? 8 : 8),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: active
            ? [AppColors.red, AppColors.ink]
            : [AppColors.jade, AppColors.ink],
      ),
      borderRadius: BorderRadius.circular(AppRadius.panel),
      border: Border.all(
        color: active ? gold : gold.withValues(alpha: .12),
        width: active ? 1.5 : 1,
      ),
      boxShadow: [
        if (active)
          BoxShadow(color: gold.withValues(alpha: .12), blurRadius: 18),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Image.asset(
                lord
                    ? 'assets/art/player-owner-v2.webp'
                    : avatarVariant.isEven
                    ? 'assets/art/player-woman-v2.webp'
                    : 'assets/art/player-man-v2.webp',
                width: compact ? 36 : 44,
                height: compact ? 36 : 44,
                fit: BoxFit.cover,
                semanticLabel: lord ? '地主头像' : '农民头像',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppType.body,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    lord ? '地主' : '${score >= 0 ? '+' : ''}$score 分',
                    style: const TextStyle(
                      color: gold,
                      fontSize: AppType.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$count 张',
                  style: TextStyle(
                    fontSize: compact ? AppType.body : AppType.label,
                    fontWeight: FontWeight.w800,
                    color: count <= 2 ? AppColors.gold : AppColors.ink,
                  ),
                ),
              ),
            ),
            if (active)
              const Text(
                '思考中',
                style: TextStyle(color: gold, fontSize: AppType.caption),
              ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 7),
          SizedBox(
            height: 34,
            child: Center(
              child: passed
                  ? const Text(
                      '不出',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: AppType.body,
                      ),
                    )
                  : played.isEmpty
                  ? Text(
                      active ? '等待出牌' : '准备就绪',
                      style: const TextStyle(
                        color: AppColors.faint,
                        fontSize: AppType.caption,
                      ),
                    )
                  : Text(
                      played.map((id) => label(id)).join(' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: gold,
                        fontSize: AppType.caption,
                      ),
                    ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// 手牌触点在整块区域计算，按下后横滑可以连续选择/取消，跨行保持一致。
class HandFan extends StatefulWidget {
  final List<int> cards;
  final Set<int> selected;
  final bool compact, enabled;
  final double cardWidth;
  final double fanHeight;
  final ValueChanged<Set<int>> onChanged;
  const HandFan({
    super.key,
    required this.cards,
    required this.selected,
    required this.compact,
    required this.enabled,
    required this.onChanged,
    this.cardWidth = 56,
    this.fanHeight = 106,
  });
  @override
  State<HandFan> createState() => _HandFanState();
}

class _HandFanState extends State<HandFan> {
  int? anchor;
  Set<int> initial = {};
  bool selecting = true;
  double available = 0;
  int get rows =>
      widget.compact &&
          (available <= 0 ||
              (available - 24 - widget.cardWidth) /
                      max(1, widget.cards.length - 1) >=
                  22)
      ? 1
      : 2;
  // A viewport-specific fixed step keeps a shrinking hand together.
  // Reserve enough room for the entire last card, including on narrow screens.
  double stepFor(int count) => max(
    0,
    min(
      32,
      (available - widget.cardWidth) / max(1, max(count, 20 ~/ rows) - 1),
    ),
  );
  int get perRow => max(1, (widget.cards.length / rows).ceil());
  double get rowHeight => widget.compact ? widget.fanHeight : 92;
  int? hit(Offset point) {
    final row = (point.dy / rowHeight).floor().clamp(0, rows - 1);
    final list = widget.cards.skip(row * perRow).take(perRow).toList();
    if (list.isEmpty) return null;
    final width = widget.cardWidth;
    final step = stepFor(list.length);
    final left = (available - (width + step * (list.length - 1))) / 2;
    if (point.dx < left || point.dx > left + width + step * (list.length - 1)) {
      return null;
    }
    final column = ((point.dx - left) / step).floor().clamp(0, list.length - 1);
    return row * perRow + column;
  }

  void drag(Offset p) {
    if (!widget.enabled) return;
    final current = hit(p);
    if (current == null) return;
    if (anchor == null) return;
    final next = {...initial};
    for (int i = min(anchor!, current); i <= max(anchor!, current); i++) {
      if (selecting) {
        next.add(widget.cards[i]);
      } else {
        next.remove(widget.cards[i]);
      }
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, outer) {
      available = outer.maxWidth;
      return SizedBox(
        height: rowHeight * rows,
        child: LayoutBuilder(
          builder: (context, box) {
            available = box.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                if (!widget.enabled) return;
                final i = hit(d.localPosition);
                if (i == null) return;
                final next = {...widget.selected};
                if (!next.add(widget.cards[i])) next.remove(widget.cards[i]);
                widget.onChanged(next);
              },
              onLongPressStart: (d) {
                final i = hit(d.localPosition);
                if (i == null || widget.cards[i] < 52) return;
                final id = widget.cards[i];
                showDialog<void>(
                  context: context,
                  builder: (context) => Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 44),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${label(id)} · 牌面预览',
                              style: const TextStyle(color: AppColors.ink),
                            ),
                            const SizedBox(height: 4),
                            CardFace(id: id, width: 104, height: 156),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('关闭预览'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              onPanDown: (d) {
                anchor = hit(d.localPosition);
                initial = {...widget.selected};
                if (anchor != null) {
                  selecting = !initial.contains(widget.cards[anchor!]);
                }
              },
              onPanStart: (d) => drag(d.localPosition),
              onPanCancel: () => anchor = null,
              onPanUpdate: (d) => drag(d.localPosition),
              onPanEnd: (_) {
                anchor = null;
              },
              child: Column(
                children: List.generate(rows, (row) {
                  final list = widget.cards
                      .skip(row * perRow)
                      .take(perRow)
                      .toList();
                  if (list.isEmpty) return SizedBox(height: rowHeight);
                  final width = widget.cardWidth;
                  final step = stepFor(list.length);
                  final total = width + step * (list.length - 1);
                  return SizedBox(
                    height: rowHeight,
                    child: Center(
                      child: SizedBox(
                        width: total,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: List.generate(list.length, (i) {
                            final id = list[i],
                                selected = widget.selected.contains(id);
                            return AnimatedPositioned(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutCubic,
                              left: i * step,
                              top: selected ? 0 : 15,
                              child: Semantics(
                                label:
                                    '${suit(id)}${label(id)}${selected ? ' 已选中' : ''}',
                                button: true,
                                selected: selected,
                                onTap: widget.enabled
                                    ? () {
                                        final next = {...widget.selected};
                                        if (!next.add(id)) next.remove(id);
                                        widget.onChanged(next);
                                      }
                                    : null,
                                child: IgnorePointer(
                                  child: CardFace(
                                    id: id,
                                    width: width,
                                    height: widget.compact
                                        ? widget.fanHeight - 18
                                        : 72,
                                    selected: selected,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      );
    },
  );
}

class CardFace extends StatelessWidget {
  final int id;
  final double width, height;
  final double minCornerSize;
  final bool selected;
  final bool animate;
  const CardFace({
    super.key,
    required this.id,
    this.width = 48,
    this.height = 66,
    this.selected = false,
    this.minCornerSize = 0,
    this.animate = true,
  });
  @override
  Widget build(BuildContext context) {
    final ink = id < 0
        ? gold
        : red(id)
        ? const Color(0xffa45d46)
        : AppColors.ink;
    return AnimatedContainer(
      duration: animate ? const Duration(milliseconds: 130) : Duration.zero,
      width: width,
      height: height,
      padding: EdgeInsets.all(height < 36 ? 1 : 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: id < 0
              ? [AppColors.red, AppColors.ink]
              : selected
              ? [Colors.white, Colors.white]
              : [Colors.white, Colors.white],
        ),
        borderRadius: BorderRadius.circular(width * .12),
        border: Border.all(
          color: selected ? gold : AppColors.gold,
          width: selected ? 2 : 1,
        ),
        boxShadow: AppElevation.shadows(
          selected ? AppElevation.action : AppElevation.card,
        ),
      ),
      child: id < 0
          ? ClipRRect(
              borderRadius: BorderRadius.circular(width * .08),
              child: Image.asset(
                'assets/art/card-back-v2.webp',
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            )
          : id >= 52
          ? JokerArt(id: id)
          : Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label(id),
                        style: TextStyle(
                          color: ink,
                          fontSize: max(minCornerSize, width * .40),
                          letterSpacing: label(id) == '10' ? -width * .07 : 0,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      Text(
                        suit(id),
                        style: TextStyle(
                          color: ink,
                          fontSize: max(minCornerSize, width * .40),
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (width >= 70)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      suit(id),
                      style: TextStyle(color: ink, fontSize: AppType.heading),
                    ),
                  ),
                if (selected)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: AppColors.gold,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Bounds are calculated before rendering; each row exposes the entire corner.
class PlayedLayout {
  final int columns, rows;
  final double width, height, step;
  const PlayedLayout._(
    this.columns,
    this.rows,
    this.width,
    this.height,
    this.step,
  );

  factory PlayedLayout(
    int count,
    double availableWidth,
    double availableHeight,
    double preferred,
  ) {
    // Keep the rank (including 10) and suit exposed, even at the 13px floor.
    double cornerStrip(double width) => max(13, width * .40) * 1.10 + 6;
    final maxWidth = min(preferred, availableHeight / 1.4);
    var rows = 1;
    var columns = max(1, count);
    var width = maxWidth;
    double span(double w, int n) => w + (n - 1) * cornerStrip(w);
    // Overlap by default. Only wrap when readable corners cannot fit one row.
    if (span(32.5, columns) > availableWidth &&
        count > 1 &&
        availableHeight >= 68) {
      rows = 2;
      columns = (count / rows).ceil();
      width = min(width, (availableHeight - 4) / 2 / 1.4);
    }
    while (width > 32.5 && span(width, columns) > availableWidth) {
      width = max(32.5, width - .25);
    }
    width = min(width, availableWidth);
    final fraction = count <= 2
        ? .9
        : count <= 6
        ? .60
        : .48;
    final step = columns <= 1
        ? 0.0
        : min(
            max(cornerStrip(width), width * fraction),
            (availableWidth - width) / (columns - 1),
          );
    final height = width * 1.4;
    return PlayedLayout._(columns, rows, width, height, step);
  }
}

class PlayedZone extends StatelessWidget {
  final List<int> cards;
  final bool passed, current, compact, highlighted;
  final double cardWidth;
  const PlayedZone({
    super.key,
    required this.cards,
    required this.passed,
    required this.current,
    required this.compact,
    this.cardWidth = 56,
    this.highlighted = false,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final layout = PlayedLayout(
        cards.length,
        box.maxWidth,
        max(0, box.maxHeight - 16),
        cardWidth,
      );
      if (cards.isEmpty) return const SizedBox.expand();
      final columns = min(cards.length, layout.columns);
      final groupWidth = layout.width + (columns - 1) * layout.step;
      final groupHeight = layout.rows * layout.height + (layout.rows - 1) * 4;
      return Center(
        child: SizedBox(
          width: groupWidth,
          height: groupHeight,
          child: Opacity(
            opacity: current || highlighted ? 1 : .70,
            child: Stack(
              children: [
                for (int i = 0; i < cards.length; i++)
                  Positioned(
                    left:
                        (groupWidth -
                                (layout.width +
                                    (min(
                                              layout.columns,
                                              cards.length -
                                                  (i ~/ layout.columns) *
                                                      layout.columns,
                                            ) -
                                            1) *
                                        layout.step)) /
                            2 +
                        (i % layout.columns) * layout.step,
                    top: (i ~/ layout.columns) * (layout.height + 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: highlighted
                            ? [
                                BoxShadow(
                                  color: gold.withValues(alpha: .8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: CardFace(
                        id: cards[i],
                        width: layout.width,
                        height: layout.height,
                        minCornerSize: 13,
                        animate: false,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 王的插画与普通牌共享纸色和边界，竖排角标在重叠手牌中仍可辨认。
class JokerArt extends StatelessWidget {
  final int id;
  const JokerArt({super.key, required this.id});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final big = id == 53;
      return Semantics(
        label: big ? '大王插画牌面' : '小王插画牌面',
        child: Stack(
          children: [
            Positioned.fill(
              top: box.maxHeight * .12,
              left: box.maxWidth * .08,
              child: Image.asset(
                'assets/art/joker-${big ? 'big' : 'small'}-v2.webp',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              width: box.maxWidth * .30,
              height: box.maxHeight * .42,
              child: FittedBox(
                alignment: Alignment.topLeft,
                fit: BoxFit.contain,
                child: Text(
                  big ? '大\n王' : '小\n王',
                  style: TextStyle(
                    color: big
                        ? const Color(0xff977131)
                        : const Color(0xff53696b),
                    fontSize: AppType.label,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
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
