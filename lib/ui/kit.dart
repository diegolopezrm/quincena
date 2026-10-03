import 'package:flutter/material.dart';

import '../catalog/tone.dart';
import '../data/category.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'icons.dart';

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
  Category.debt: Glyph.graduationCap,
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

/// A block inside an answer: the surface it sits on, with room to breathe.
class Block extends StatelessWidget {
  const Block({super.key, required this.child, this.padding, this.color});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color ?? context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.colors.line),
    ),
    child: child,
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
