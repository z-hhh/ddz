import 'package:flutter/material.dart';

/// Painted plate and baked lettering are separate: only the blank is sliced.
class AssetMenuButton extends StatefulWidget {
  final String label;
  final String asset;
  final VoidCallback? onPressed;
  final double height;
  const AssetMenuButton({
    super.key,
    required this.label,
    required this.asset,
    required this.onPressed,
    this.height = 56,
  });
  @override
  State<AssetMenuButton> createState() => _AssetMenuButtonState();
}

class _AssetMenuButtonState extends State<AssetMenuButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    button: true,
    enabled: widget.onPressed != null,
    child: SizedBox(
      height: widget.height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (v) => setState(() => pressed = v),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            transform: Matrix4.translationValues(0, pressed ? 2 : 0, 0),
            child: Opacity(
              opacity: widget.onPressed == null
                  ? .38
                  : pressed
                  ? .8
                  : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/art/menu-plaque-v3.webp',
                    fit: BoxFit.fill,
                    scale: 3,
                    centerSlice: const Rect.fromLTWH(24, 8, 252, 88),
                    excludeFromSemantics: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 15,
                    ),
                    child: Image.asset(
                      'assets/art/menu-${widget.asset}-v3.webp',
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
