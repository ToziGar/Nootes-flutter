import 'package:flutter/material.dart';

class Responsive {
  static double width(BuildContext context) => MediaQuery.of(context).size.width;
  static double height(BuildContext context) => MediaQuery.of(context).size.height;

  static bool xs(BuildContext context) => width(context) < 360;
  static bool sm(BuildContext context) => width(context) < 600;
  static bool md(BuildContext context) => width(context) >= 600 && width(context) < 900;
  static bool lg(BuildContext context) => width(context) >= 900;
}

