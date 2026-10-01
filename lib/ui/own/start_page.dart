import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../mark.dart';

/// The first screen: the person's own accounts, or the sample.
class StartPage extends StatelessWidget {
  const StartPage({super.key, required this.onOwn, required this.onDemo});

  final VoidCallback onOwn;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: <Widget>[
                const Align(alignment: Alignment.centerLeft, child: Wordmark()),
                const SizedBox(height: 48),
                Text(l.startTitle, style: context.type.displaySmall),
                const SizedBox(height: 28),
                _Choice(
                  icon: Glyph.wallet,
                  title: l.startOwnTitle,
                  body: l.startOwnBody,
                  emphasis: true,
                  onTap: onOwn,
                ),
                const SizedBox(height: 14),
                _Choice(
                  icon: Glyph.sparkle,
                  title: l.startDemoTitle,
                  body: l.startDemoBody,
                  onTap: onDemo,
                ),
                const SizedBox(height: 28),
                Row(
                  children: <Widget>[
                    Icon(Glyph.lock, size: 18, color: context.colors.inkFaint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.privacyNote, style: context.type.bodySmall),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.emphasis = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Material(
    color: emphasis ? context.colors.brandSoft : context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: emphasis ? context.colors.brand : context.colors.line,
        width: emphasis ? 1.5 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: emphasis
                    ? context.colors.brand
                    : context.colors.brandSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: emphasis ? context.colors.onBrand : context.colors.brand,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: context.type.titleMedium),
                  const SizedBox(height: 4),
                  Text(body, style: context.type.bodyMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Icon(
                Glyph.arrowRight,
                size: 18,
                color: context.colors.inkFaint,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
