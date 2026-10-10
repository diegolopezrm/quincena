import 'package:flutter/material.dart';

/// A column of [items] in which one that leaves folds away where it was
/// instead of vanishing, so the eye follows what changed: a capture that
/// was confirmed, a movement that was deleted.
///
/// Whatever removed it has already happened; this only keeps a picture of
/// it for a moment. With animations turned down, it simply goes.
class ExitList<T> extends StatefulWidget {
  const ExitList({
    super.key,
    required this.items,
    required this.keyOf,
    required this.builder,
    this.gap = 8,
  });

  final List<T> items;
  final String Function(T item) keyOf;
  final Widget Function(BuildContext context, T item) builder;

  /// The space under each item.
  final double gap;

  /// How long an item takes to fold away.
  static const Duration exit = Duration(milliseconds: 260);

  @override
  State<ExitList<T>> createState() => _ExitListState<T>();
}

class _Leaving<T> {
  _Leaving(this.item, this.index, this.controller);

  final T item;

  /// Where it was, among the items before it left.
  final int index;
  final AnimationController controller;
}

class _ExitListState<T> extends State<ExitList<T>>
    with TickerProviderStateMixin {
  final Map<String, _Leaving<T>> _leaving = <String, _Leaving<T>>{};

  @override
  void didUpdateWidget(ExitList<T> old) {
    super.didUpdateWidget(old);
    final Set<String> now = <String>{
      for (final T item in widget.items) widget.keyOf(item),
    };
    // Something that came back is no longer leaving.
    for (final String key in now) {
      _leaving.remove(key)?.controller.dispose();
    }
    if (MediaQuery.disableAnimationsOf(context)) return;
    for (var i = 0; i < old.items.length; i++) {
      final T item = old.items[i];
      final String key = widget.keyOf(item);
      if (now.contains(key) || _leaving.containsKey(key)) continue;
      final AnimationController controller = AnimationController(
        vsync: this,
        duration: ExitList.exit,
        value: 1,
      );
      _leaving[key] = _Leaving<T>(item, i, controller);
      controller.reverse().whenCompleteOrCancel(() {
        if (!mounted) return;
        setState(() => _leaving.remove(key)?.controller.dispose());
      });
    }
  }

  @override
  void dispose() {
    for (final _Leaving<T> l in _leaving.values) {
      l.controller.dispose();
    }
    super.dispose();
  }

  Widget _entry(BuildContext context, T item) => Padding(
    key: ValueKey<String>(widget.keyOf(item)),
    padding: EdgeInsets.only(bottom: widget.gap),
    child: widget.builder(context, item),
  );

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      for (final T item in widget.items) _entry(context, item),
    ];
    // Each leaving item goes back where it was, folding.
    final List<_Leaving<T>> leaving = _leaving.values.toList()
      ..sort((_Leaving<T> a, _Leaving<T> b) => a.index.compareTo(b.index));
    for (final _Leaving<T> l in leaving) {
      final Animation<double> fold = CurvedAnimation(
        parent: l.controller,
        curve: Curves.easeInCubic,
      );
      children.insert(
        l.index.clamp(0, children.length),
        ExcludeSemantics(
          child: IgnorePointer(
            child: SizeTransition(
              sizeFactor: fold,
              child: FadeTransition(
                opacity: fold,
                child: _entry(context, l.item),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
