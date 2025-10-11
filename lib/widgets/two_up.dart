import 'package:flutter/widgets.dart';

class TwoUp extends StatelessWidget {
  const TwoUp({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = 560,
  });

  final Widget first;
  final Widget second;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > breakpoint;
        if (isWide) {
          return Row(
            children: [
              Expanded(child: first),
              Expanded(child: second),
            ],
          );
        }
        return Column(children: [first, second]);
      },
    );
  }
}
