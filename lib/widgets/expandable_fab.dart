import 'package:flutter/material.dart';

/// A small expandable FAB that shows multiple actions when tapped.
class ExpandableFab extends StatefulWidget {
  const ExpandableFab({super.key, required this.actions});

  final List<Widget> actions;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Background dismiss area
          if (_open)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggle,
                child: Container(color: Colors.black26),
              ),
            ),
          ...List.generate(actions.length, (i) {
            final start = i / (actions.length + 1);
            final end = (i + 1) / (actions.length + 1);
            final anim = CurvedAnimation(parent: _ctrl, curve: Interval(start, end, curve: Curves.easeOut));
            final w = actions[i];
            Widget wrapped = w;
            // If it's an IconButton or FloatingActionButton, give it larger constraints for touch targets
            if (w is IconButton) {
              wrapped = ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: w,
              );
            } else if (w is FloatingActionButton) {
              wrapped = SizedBox(width: 48, height: 48, child: Center(child: w));
            }
            return Positioned(
              right: 4 + (i * 56),
              bottom: 4,
              child: ScaleTransition(
                scale: anim,
                child: FadeTransition(
                  opacity: anim,
                  // Disable Hero animations for action buttons to avoid duplicate hero tags
                  child: HeroMode(
                    enabled: false,
                    child: Semantics(container: true, button: true, child: wrapped),
                  ),
                ),
              ),
            );
          }),
          FloatingActionButton(
            onPressed: _toggle,
            child: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: _anim),
          ),
        ],
      ),
    );
  }
}
