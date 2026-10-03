import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_CO';
  await initializeDateFormatting('es');
  await initializeDateFormatting('es_CO');
  registerLicenses();
  runApp(const QuincenaApp());
}
