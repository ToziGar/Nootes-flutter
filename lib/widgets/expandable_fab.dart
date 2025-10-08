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
      if (_open) _ctrl.forward(); else _ctrl.reverse();
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
            return Positioned(
              right: 4 + (i * 56),
              bottom: 4,
              child: ScaleTransition(scale: _anim, child: actions[i]),
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
