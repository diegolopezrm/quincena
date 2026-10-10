import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog/tone.dart';
import '../data/category.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'icons.dart';

/// Whether the system text is large enough that a row's amount goes under
/// its name instead of beside it, and the name wraps instead of being cut:
/// past 1.3 times the default, as with the rows of Por revisar.
bool largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(10) > 13;

/// The icon each category is drawn with, wherever it appears.
const Map<Category, IconData> categoryIcon = <Category, IconData>{
  Category.housing: Glyph.house,
  Category.groceries: Glyph.shoppingCart,
  Category.restaurants: Glyph.forkKnife,
  Category.transport: Glyph.train,
  Category.utilities: Glyph.lightning,
  Category.subscriptions: Glyph.arrowsClockwise,
  Category.health: Glyph.heartbeat,
  Category.shopping: Glyph.shoppingBag,
  Category.leisure: Glyph.ticket,
  Category.debt: Glyph.bank,
  Category.other: Glyph.dotsThree,
};

extension CategoryLook on Category {
  IconData get icon => categoryIcon[this]!;
  Color color(BuildContext context) => context.colors.category(name);
}

/// The category's icon on a soft disc of its own color.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge(this.category, {super.key, this.size = 36});

  final Category category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = category.color(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(category.icon, size: size * 0.5, color: color),
      ),
    );
  }
}

extension ToneLook on Tone {
  Color color(BuildContext context) => switch (this) {
    Tone.neutral => context.colors.inkSoft,
    Tone.good => context.colors.positive,
    Tone.caution => context.colors.caution,
    Tone.alert => context.colors.negative,
  };

  Color soft(BuildContext context) => switch (this) {
    Tone.neutral => context.colors.sunken,
    Tone.good => context.colors.brandSoft,
    Tone.caution => context.colors.cautionSoft,
    Tone.alert => context.colors.negativeSoft,
  };

  IconData get icon => switch (this) {
    Tone.neutral => Glyph.info,
    Tone.good => Glyph.checkCircle,
    Tone.caution => Glyph.warningCircle,
    Tone.alert => Glyph.warningCircle,
  };
}

/// Text whose digits line up, for amounts.
class Figures extends StatelessWidget {
  const Figures(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: textAlign,
    style: (style ?? context.type.bodyLarge)?.copyWith(fontFeatures: tabular),
  );
}

/// [value], written by [format], that counts its way from the value it
/// had to a new one, so a change reads as a change; at once with
/// animations turned down. The first value shows as it is.
class CountingFigures extends StatelessWidget {
  const CountingFigures({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: value),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    builder: (BuildContext context, double shown, _) =>
        Figures(format(shown), style: style),
  );
}

/// A block inside an answer: the surface it sits on, with room to breathe.
class Block extends StatelessWidget {
  const Block({super.key, required this.child, this.padding, this.color});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color ?? context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.colors.line),
    ),
    child: child,
  );
}

/// A light tap in the hand as something is saved or recorded: the app took
/// it, felt before the screen changes.
void feelSaved() => unawaited(HapticFeedback.lightImpact());

/// Opens [form], for creating or changing something big, as a goal or a
/// purchase in instalments, as a page of its own that slides over the
/// screen, with the whole height for its fields and an X that closes it
/// without saving. A sheet stays for a quick decision.
///
/// The form brings its title, its fields and its button, as it would in a
/// sheet; the page keeps it above the keyboard and clear of the phone's
/// edges, no wider than a sheet on a wide screen. A message about the
/// screen it covers goes: on the page it would sit over the form's button.
Future<T?> showFormPage<T>(BuildContext context, WidgetBuilder form) {
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      fullscreenDialog: true,
      builder: (BuildContext context) => Scaffold(
        backgroundColor: context.colors.surface,
        appBar: AppBar(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Builder(builder: form),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The title of a form that [showFormPage] opens, at the top of its page:
/// a heading, and on Android the name a screen reader gives the page, as an
/// app bar's title would be.
class FormTitle extends StatelessWidget {
  const FormTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    namesRoute: switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => null,
      _ => true,
    },
    child: Text(text, style: context.type.headlineMedium),
  );
}

/// Where something is still loading: a soft shape that breathes, in the
/// place the content will take, instead of a spinner in an empty space.
/// With animations turned down it stays still.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 12, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_breath),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: context.colors.sunken,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    ),
  );
}

/// What a screen shows while the accounts load: the shape of the figure at
/// its top and of a few rows, breathing where they will be, read as
/// [label] by a screen reader.
class LoadingShapes extends StatelessWidget {
  const LoadingShapes({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: <Widget>[
        const Skeleton(height: 180, radius: 24),
        const SizedBox(height: 28),
        const Skeleton(height: 10, width: 120),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...<Widget>[
          const Row(
            children: <Widget>[
              Skeleton(height: 40, width: 40, radius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Skeleton(height: 12, width: 140),
                    SizedBox(height: 8),
                    Skeleton(height: 10, width: 90),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Skeleton(height: 12, width: 64),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    ),
  );
}
