import 'package:flutter/material.dart';

/// Shared artwork palette.
abstract final class AppColors {
  static const canvas = Color(0xffeee7d4);
  static const red = Color(0xffc39752);
  static const jade = Color(0xff7f8c62);
  static const gold = Color(0xff806332);
  static const paper = Color(0xfffff8e9);
  static const ink = Color(0xff403b30);
  static const muted = Color(0xbf403b30);
  static const faint = Color(0x66403b30);
}

abstract final class AppElevation {
  static const table = 0.0, card = 2.0, action = 6.0, modal = 12.0;
  static List<BoxShadow> shadows(double level, {Color color = Colors.black}) =>
      [
        BoxShadow(
          color: color.withValues(alpha: .18),
          blurRadius: level * 2,
          offset: Offset(0, level / 2),
        ),
      ];
}

abstract final class AppType {
  static const caption = 12.0;
  static const body = 14.0;
  static const label = 16.0;
  static const heading = 24.0;
  static const title = 40.0;
}

abstract final class AppSpace {
  static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0, xl = 32.0;
}

abstract final class AppRadius {
  static const control = 12.0, panel = 24.0;
}

abstract final class AppTheme {
  static ThemeData get data => ThemeData(
    useMaterial3: true,
    fontFamily: 'sans-serif',
    colorScheme: ColorScheme.light(
      primary: AppColors.red,
      onPrimary: AppColors.ink,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      surface: AppColors.canvas,
      onSurface: AppColors.ink,
      error: AppColors.red,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: AppType.title,
        fontWeight: FontWeight.w900,
      ),
      headlineSmall: TextStyle(
        fontSize: AppType.heading,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        fontSize: AppType.label,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(fontSize: AppType.body),
      bodySmall: TextStyle(fontSize: AppType.caption),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(72, 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.ink,
        textStyle: const TextStyle(
          fontFamily: 'sans-serif',
          fontSize: AppType.label,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: AppColors.gold.withValues(alpha: .7)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(72, 44),
        foregroundColor: AppColors.ink,
        side: BorderSide(color: AppColors.gold.withValues(alpha: .65)),
        textStyle: const TextStyle(
          fontFamily: 'sans-serif',
          fontSize: AppType.body,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: AppColors.ink,
        textStyle: const TextStyle(
          fontFamily: 'sans-serif',
          fontSize: AppType.body,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: AppColors.ink,
      ),
    ),
    dividerColor: AppColors.gold.withValues(alpha: .2),
  );
}

/// 同一材质用于首页控件与结算；纹理是装饰层，不承载文字。
class WoodPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const WoodPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.md),
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      image: DecorationImage(
        image: const AssetImage('assets/art/oak-ui-v2.webp'),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          AppColors.canvas.withValues(alpha: .15),
          BlendMode.srcATop,
        ),
      ),
      border: Border.all(color: AppColors.gold.withValues(alpha: .55)),
      boxShadow: AppElevation.shadows(AppElevation.modal),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Grounded table controls with a short physical press response.
class TableActionButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  const TableActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
  @override
  State<TableActionButton> createState() => _TableActionButtonState();
}

class _TableActionButtonState extends State<TableActionButton> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Listener(
      onPointerDown: enabled ? (_) => setState(() => down = true) : null,
      onPointerUp: (_) => setState(() => down = false),
      onPointerCancel: (_) => setState(() => down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, down ? 2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppElevation.shadows(
            down
                ? AppElevation.card
                : widget.primary
                ? AppElevation.action
                : AppElevation.card,
            color: widget.primary && enabled
                ? const Color(0xff897044)
                : Colors.black,
          ),
        ),
        child: SizedBox(
          height: widget.primary ? 52 : 44,
          width: widget.primary ? 108 : 80,
          child: widget.primary
              ? FilledButton(
                  onPressed: widget.onPressed,
                  style: FilledButton.styleFrom(
                    shape: shape.copyWith(
                      side: BorderSide(
                        color: AppColors.gold.withValues(
                          alpha: enabled ? 1 : .4,
                        ),
                      ),
                    ),
                    backgroundColor: const Color(0xffc39752),
                    disabledBackgroundColor: const Color(0xffcdc3a9),
                    disabledForegroundColor: AppColors.paper.withValues(
                      alpha: .44,
                    ),
                    foregroundColor: AppColors.ink,
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text(widget.label),
                )
              : OutlinedButton(
                  onPressed: widget.onPressed,
                  style: OutlinedButton.styleFrom(
                    shape: shape,
                    backgroundColor: const Color(0xe6f5efdf),
                    foregroundColor: AppColors.ink,
                    disabledForegroundColor: AppColors.paper.withValues(
                      alpha: .36,
                    ),
                    side: BorderSide(
                      color: AppColors.gold.withValues(
                        alpha: enabled ? .7 : .25,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(widget.label),
                ),
        ),
      ),
    );
  }
}
