import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'look.dart';

/// What Quincena is made with and the licenses it ships under: the same
/// ones the system's page lists, read from [LicenseRegistry], in the app's
/// language and without a line in another.
class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key, required this.version});

  final String version;

  /// Every license, by the package it is for, the packages in order.
  static Future<List<(String, List<LicenseEntry>)>> _byPackage() async {
    final Map<String, List<LicenseEntry>> by = <String, List<LicenseEntry>>{};
    await for (final LicenseEntry e in LicenseRegistry.licenses) {
      for (final String p in e.packages) {
        (by[p] ??= <LicenseEntry>[]).add(e);
      }
    }
    return <(String, List<LicenseEntry>)>[
      for (final String p
          in by.keys.toList()..sort(
            (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
          ))
        (p, by[p]!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(l.licensesTitle, style: context.type.titleLarge),
      ),
      body: FutureBuilder<List<(String, List<LicenseEntry>)>>(
        future: _byPackage(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<(String, List<LicenseEntry>)>> got,
            ) {
              final List<(String, List<LicenseEntry>)>? packages = got.data;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: <Widget>[
                      Text('Quincena', style: context.type.headlineSmall),
                      Text(
                        l.licensesVersion(version),
                        style: context.type.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(l.licensesLegalese, style: context.type.bodySmall),
                      const SizedBox(height: 20),
                      if (packages == null)
                        const Skeleton(height: 48)
                      else
                        Panel(
                          indent: 16,
                          children: <Widget>[
                            for (final (String name, List<LicenseEntry> entries)
                                in packages)
                              ListTile(
                                title: Text(
                                  name,
                                  style: context.type.titleSmall,
                                ),
                                subtitle: Text(
                                  l.licensesCount(entries.length),
                                  style: context.type.bodySmall,
                                ),
                                trailing: Icon(
                                  Glyph.caretRight,
                                  size: 18,
                                  color: context.colors.inkFaint,
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) =>
                                        _PackageLicenses(
                                          name: name,
                                          entries: entries,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
      ),
    );
  }
}

/// The licenses of one package, paragraph by paragraph, as written.
class _PackageLicenses extends StatelessWidget {
  const _PackageLicenses({required this.name, required this.entries});

  final String name;
  final List<LicenseEntry> entries;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: context.colors.canvas,
      surfaceTintColor: Colors.transparent,
      title: Text(name, style: context.type.titleLarge),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            for (final (int i, LicenseEntry e) in entries.indexed) ...<Widget>[
              if (i > 0) const Divider(height: 40),
              for (final LicenseParagraph p in e.paragraphs)
                Padding(
                  padding: EdgeInsets.only(
                    top: 8,
                    left: p.indent == LicenseParagraph.centeredIndent
                        ? 0
                        : 16.0 * p.indent,
                  ),
                  child: Text(
                    p.text,
                    textAlign: p.indent == LicenseParagraph.centeredIndent
                        ? TextAlign.center
                        : TextAlign.start,
                    style: context.type.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
