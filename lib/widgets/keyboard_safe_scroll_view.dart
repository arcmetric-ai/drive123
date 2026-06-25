import 'dart:math' as math;

import 'package:flutter/material.dart';

class KeyboardSafeScrollView extends StatelessWidget {
  const KeyboardSafeScrollView({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
  });

  final Widget child;
  final EdgeInsets padding;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final effectivePadding = padding.copyWith(
      bottom: padding.bottom + keyboardInset,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = math.max(
          0.0,
          constraints.maxHeight - effectivePadding.vertical,
        );

        return SingleChildScrollView(
          keyboardDismissBehavior: keyboardDismissBehavior,
          padding: effectivePadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}
