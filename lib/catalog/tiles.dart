import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

part 'tiles.genui.dart';

/// Equal columns that fold to one on a narrow screen.
@GenUiWidget(
  description:
      'Lays two to four components side by side in equal columns, folding to '
      'a single column on a narrow screen. Use it for StatTiles.',
)
class Tiles extends StatelessWidget {
  const Tiles({super.key, required this.children});

  /// The components to lay out, usually StatTiles.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final int columns = box.maxWidth < 360
            ? 1
            : (children.length > 2 && box.maxWidth >= 620 ? children.length : 2)
                  .clamp(1, 4);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final List<Widget> slice = children.sublist(
            i,
            (i + columns).clamp(0, children.length),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var j = 0; j < columns; j++) ...<Widget>[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(
                      child: j < slice.length ? slice[j] : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 12),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}
