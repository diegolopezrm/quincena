import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';

/// Over every screen while the example account is open: whose account it
/// is, the way to the person's own, and, through [ExampleScope], what the
/// screens below need to say when something only works with them.
///
/// It stays in place with [owner] null when the app shows anything else,
/// with no bar, so the screens below keep their place in the tree.
class ExampleFrame extends StatelessWidget {
  const ExampleFrame({
    super.key,
    required this.owner,
    required this.onUseOwn,
    required this.onAbout,
    required this.child,
  });

  /// Whose example is open, or null when none is.
  final String? owner;

  /// To the person's own accounts; null where the build keeps none.
  final VoidCallback? onUseOwn;
  final VoidCallback onAbout;

  /// The app's screens.
  final Widget child;

  static const Key _screens = ValueKey<String>('screens');

  @override
  Widget build(BuildContext context) {
    final String? owner = this.owner;
    return ExampleScope(
      owner: owner,
      onUseOwn: onUseOwn,
      child: Column(
        children: <Widget>[
          if (owner != null)
            ExampleBar(owner: owner, onUseOwn: onUseOwn, onAbout: onAbout),
          // The bar takes the status bar's room; the screens start under it.
          Expanded(
            key: _screens,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: owner != null,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip at the top while the example is open: «Cuenta de ejemplo de
/// Valentina», which says more when tapped, and «Usar mis cuentas».
class ExampleBar extends StatelessWidget {
  const ExampleBar({
    super.key,
    required this.owner,
    required this.onUseOwn,
    required this.onAbout,
  });

  final String owner;
  final VoidCallback? onUseOwn;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    // It sits under the status bar: its icons have to read on it.
    final bool darkBar =
        ThemeData.estimateBrightnessForColor(context.colors.brandSoft) ==
        Brightness.dark;
    final Widget bar = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.6,
      child: Material(
        color: context.colors.brandSoft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.colors.line)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      button: true,
                      child: InkWell(
                        onTap: onAbout,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          // A finger's room, as the button beside it has.
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Glyph.sparkle,
                                size: 18,
                                color: context.colors.brand,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l.exampleBarTitle(owner),
                                  style: context.type.titleSmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Glyph.info,
                                size: 16,
                                color: context.colors.inkFaint,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onUseOwn case final VoidCallback use)
                    TextButton(onPressed: use, child: Text(l.exampleUseOwn)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: darkBar ? Brightness.light : Brightness.dark,
        statusBarBrightness: darkBar ? Brightness.dark : Brightness.light,
      ),
      child: bar,
    );
  }
}

/// What the screens of the example know about it: whose it is, and how to
/// leave it for the person's own accounts.
class ExampleScope extends InheritedWidget {
  const ExampleScope({
    super.key,
    required this.owner,
    required this.onUseOwn,
    required super.child,
  });

  /// Whose example is open, or null when none is.
  final String? owner;

  /// To the person's own accounts; null where the build keeps none.
  final VoidCallback? onUseOwn;

  /// The example open over [context], or null. Read when it is needed, as
  /// on a tap: a screen does not rebuild when the example closes, since
  /// the screens of an example that closed are on their way out.
  static ExampleScope? of(BuildContext context) {
    final ExampleScope? scope = context
        .getInheritedWidgetOfExactType<ExampleScope>();
    return scope?.owner == null ? null : scope;
  }

  @override
  bool updateShouldNotify(ExampleScope oldWidget) => false;
}

/// What the example is, and the ways out of it: to the person's own
/// accounts, back to the first screen where there is one, or to stay.
Future<void> showExampleAbout(
  BuildContext context, {
  required String owner,
  VoidCallback? onUseOwn,
  VoidCallback? onBackToStart,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext sheet) {
    final AppLocalizations l = sheet.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.exampleBarTitle(owner), style: sheet.type.headlineSmall),
          const SizedBox(height: 12),
          Text(l.exampleAboutBody(owner), style: sheet.type.bodyMedium),
          const SizedBox(height: 24),
          if (onUseOwn case final VoidCallback use)
            FilledButton(
              onPressed: () {
                Navigator.of(sheet).pop();
                use();
              },
              child: Text(l.exampleUseOwn),
            ),
          if (onBackToStart case final VoidCallback back) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.of(sheet).pop();
                back();
              },
              child: Text(l.exampleBackToStart),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(sheet).pop(),
            child: Text(l.exampleStay),
          ),
        ],
      ),
    );
  },
);

/// In the example, says plainly that [title] only works with the person's
/// own accounts, offers to go to them, and answers true: the caller does
/// nothing else. Answers false with their own accounts, to go on.
Future<bool> explainExample(
  BuildContext context,
  OwnController own,
  String title,
) async {
  if (!own.example) return false;
  final ExampleScope? scope = ExampleScope.of(context);
  final String owner = scope?.owner ?? own.profile?.name ?? '';
  final bool? useOwn = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) {
      final AppLocalizations l = dialog.l10n;
      return AlertDialog(
        title: Text(title),
        content: Text(l.exampleOnlyBody(owner)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.exampleStay),
          ),
          if (scope?.onUseOwn != null)
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l.exampleUseOwn),
            ),
        ],
      );
    },
  );
  if (useOwn == true) scope?.onUseOwn?.call();
  return true;
}
