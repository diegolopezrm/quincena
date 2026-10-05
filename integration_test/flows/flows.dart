// Every flow, in the order of their ids: the part of the app, then the flow.
import 'conversacion.dart';
import 'cuentas.dart';
import 'flow.dart';
import 'inicio_y_movimientos.dart';
import 'plan.dart';
import 'por_revisar.dart';
import 'primeros_pasos_y_ajustes.dart';

final List<AppFlow> flows = <AppFlow>[
  ...primerosPasosYAjustesFlows,
  ...inicioYMovimientosFlows,
  ...cuentasFlows,
  ...planFlows,
  ...porRevisarFlows,
  ...conversacionFlows,
]..sort((AppFlow a, AppFlow b) => a.id.compareTo(b.id));
