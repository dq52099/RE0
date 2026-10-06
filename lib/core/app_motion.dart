import 'package:flutter/material.dart';

const appMotionDuration = Duration(milliseconds: 220);

/// Animates only the arriving content, without retaining stale interactive UI.
class AppEntrance extends StatefulWidget {
  const AppEntrance({
    super.key,
    required this.child,
    this.identity,
    this.animateOnMount = true,
  });

  final Widget child;
  final Object? identity;
  final bool animateOnMount;

  @override
  State<AppEntrance> createState() => _AppEntranceState();
}

class _AppEntranceState extends State<AppEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: appMotionDuration,
    value: widget.animateOnMount ? 0 : 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  void _enter() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.isDismissed) {
      _enter();
    }
  }

  @override
  void didUpdateWidget(AppEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) _enter();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: 0.65 + _curve.value * 0.35,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - _curve.value)),
            child: child,
          ),
        ),
      );
}

/// Keeps visited tabs mounted while pausing tickers outside the visible page.
class AppTabStack extends StatelessWidget {
  const AppTabStack({
    super.key,
    required this.index,
    required this.visited,
    required this.children,
  });

  final int index;
  final Set<int> visited;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRect(
          child: AppEntrance(
        identity: index,
        animateOnMount: false,
        child: IndexedStack(
          index: index,
          children: List.generate(children.length, (i) {
            if (!visited.contains(i)) return const SizedBox.shrink();
            return TickerMode(
              enabled: i == index,
              child: RepaintBoundary(child: children[i]),
            );
          }),
        ),
      ));
}

/// Keeps Android's predictive back gesture, including canceled swipes.
class AppAndroidPageTransitionsBuilder
    extends PredictiveBackPageTransitionsBuilder {
  const AppAndroidPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return super.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
      child: SlideTransition(
        position: animation.drive(Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic))),
        child: child,
      ),
    );
  }
}

/// Opening feedback is independent of the dialog's keyboard inset layout.
class AppDialogRoute<T> extends DialogRoute<T> {
  AppDialogRoute({
    required super.context,
    required super.builder,
    super.barrierDismissible,
  });

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final eased = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: eased,
      child: ScaleTransition(
        alignment: Alignment.topCenter,
        scale: eased.drive(Tween<double>(begin: 0.98, end: 1)),
        child: child,
      ),
    );
  }
}
