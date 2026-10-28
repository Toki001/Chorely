import 'package:flutter/material.dart';

/// Scrolls at large text sizes and keeps forms readable on tablets.
class PageFrame extends StatelessWidget {
  const PageFrame({required this.child, super.key, this.maxWidth = 520});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    ),
  );
}
