import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds what the app ships or shows that is not a Dart package to the
/// licenses page: the fonts and the icons, whose licenses travel with them,
/// and the OpenStreetMap data behind a shop suggested by location.
///
/// Packages register their own; these are the rest.
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (String package, String asset) in const <(String, String)>[
      ('Bricolage Grotesque', 'assets/fonts/OFL-BricolageGrotesque.txt'),
      ('Geist', 'assets/fonts/OFL-Geist.txt'),
      ('Phosphor Icons', 'assets/icons/LICENSE-Phosphor.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(<String>[
        package,
      ], await rootBundle.loadString(asset));
    }
    yield const LicenseEntryWithLineBreaks(<String>['OpenStreetMap'], _osm);
  });
}

/// What the Open Database License asks of anyone who shows data from
/// OpenStreetMap: credit, and where the license and the data can be found.
const String _osm =
    '© OpenStreetMap contributors (colaboradores de OpenStreetMap).\n\n'
    'When a payment notification does not name the shop, Quincena suggests '
    'the shops near where the phone was, found in OpenStreetMap data '
    'through Photon, a search service run by Komoot. The data is available '
    'under the Open Database License (ODbL) 1.0.\n\n'
    'https://www.openstreetmap.org/copyright\n'
    'https://opendatacommons.org/licenses/odbl/1-0/';
