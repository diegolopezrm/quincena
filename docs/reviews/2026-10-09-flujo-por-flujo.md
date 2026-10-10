# Revisión flujo por flujo, 9 de octubre de 2026

Cada cosa que una persona puede hacer en Quincena se jugó en un iPhone 17
Pro simulado, con la versión 1.1.0 (build 20): 188 flujos, 1.243 pasos con
su foto y 1.301 comprobaciones sobre los datos, de las que se cumplen
1.300. Cada flujo quedó en una sola imagen, con su objetivo, cada paso y
lo que se comprobó.

Las imágenes están en una página para que expertos digan, flujo por flujo,
si se entiende y qué cambiarían:
https://claude.ai/artifact/BNsYJMmPbvknobNHQ2zZWG. Ahí cada persona marca
«Se entiende», «Con dudas» o «No se entiende» y deja una nota; Diego puede
leer todas las respuestas.

Los flujos se juegan con `tool/flows/run.sh`. Esta vez corrieron por
partes, en varios simuladores a la vez, y las imágenes de todas las partes
quedaron juntas en `capturas/flujos-todo/`, que no va al repositorio.

## Lo que ya sabemos

Mientras se escribían los flujos, el 5 y 6 de octubre, se anotaron 184
observaciones de experiencia y 35 errores que quedaron sin arreglar. Desde
entonces la app cambió: la cuenta de ejemplo abre toda la app, y muchos de
esos errores se corrigieron.

El 9 de octubre se revisó cada una contra el código de la versión 1.1.0
(build 20): 169 seguían, del todo o en parte, y 50 ya se habían resuelto o
ya no aplicaban. En esa revisión salieron 21 más.

Esta lista es lo que ya sabemos. Lo que más nos sirve de ti es lo que no
está aquí, y saber si estas propuestas van en la dirección correcta.

Actualizado el 9 de octubre por la noche, después de la revisión del
experto: con las fases 27 a 29 y 31 a 34, y otros arreglos, se resolvieron
100 y 10 más en parte. Cada una dice qué hace ahora y en qué fase cambió;
para verlas, marca «Mostrar también lo que ya se resolvió». Las fotos de
los flujos son las de esta versión.

- 219 observaciones revisadas contra el código de hoy.
- 81 siguen, del todo o en parte.
- 138 ya resueltas o que ya no aplican.
- 21 nuevas, encontradas en esa revisión.
- 3 pendientes de importancia alta.

Lo que sigue pendiente, por parte de la app, de mayor a menor importancia.
Entre paréntesis, los flujos donde se ve.

### Primeros pasos, Ajustes y respaldos

- **Media.** *Reglas aprendidas.* «Borrar regla» la quita al instante, sin
  preguntar ni ofrecer deshacer; los comercios salen sin tilde («Exito
  Laureles»). Propuesta: Al borrar, mostrar abajo «Regla borrada» con
  «Deshacer», y guardar con la regla el nombre del comercio como llegó la
  última vez para mostrarlo con sus tildes.
- **Baja.** *Configuración paso 2 › calendario.* El calendario muestra
  «Cancelar» y «ACEPTAR» con mayúsculas distintas (textos de Flutter).
  Propuesta: Dar a todos los calendarios sus propios botones, «Cancelar» y
  «Aceptar», desde una función común.
- **Baja.** *Captura automatica.* «Ya reconoce 2 comercios.» sigue debajo
  del panel, separado de la fila «Reglas aprendidas: 4 reglas», y repite
  parte de lo mismo. Propuesta: Dejar un solo texto como subtítulo de la
  fila: «4 reglas: 2 comercios, 1 tarjeta, 1 banco».
- **Baja.** *Captura automatica > Usar la ubicacion del pago.* Bajo «Usar
  la ubicación del pago» sigue el párrafo largo sobre OpenStreetMap,
  Photon y la licencia; además, al encenderla aparece ahora un aviso que
  explica lo mismo. Propuesta: Dejar una línea corta, como «Sugiere el
  comercio cuando la alerta no dice dónde fue», y mover el resto a «Más
  información», ya que el aviso al encenderla lo explica completo.
- **Baja.** *Licencias.* La página de licencias muestra «Powered by
  Flutter» en inglés, debajo del texto legal en español. Propuesta:
  Aceptarlo como texto de Flutter, o hacer una página de licencias propia
  que lea las mismas licencias y no tenga esa línea.
- **Baja.** *Ajustes en el computador.* En el computador, la fila de
  Ajustes sigue prometiendo pagos desde notificaciones y mensajes, y el
  bloque se titula «En este dispositivo»; solo el texto de abajo aclara
  que lo automático es del teléfono. Propuesta: En el computador usar otro
  subtítulo, como «En el computador: pega el mensaje del banco o lee una
  captura», y titular el bloque «En este computador».
- **Baja.** *Exportar mis datos (primer respaldo cifrado).* La primera
  vez, el código de respaldo se crea y se muestra antes de elegir dónde
  guardar; si la persona cierra ese selector, no queda archivo, el código
  ya quedó guardado y nada lo dice. Propuesta: Pedir primero dónde guardar
  y mostrar el código después, con el nombre del archivo guardado.
- **Media.** *Configuración paso 4 › Agregar pago fijo.* Un pago fijo
  escrito a mano llega en la categoría Suscripciones, con preguntas de
  prueba gratis y uso; un gimnasio o un crédito quedan como suscripción
  sin que la persona lo note. Hoy: Ahora configurar ya no pasa por los
  pagos fijos. «Agregar pago fijo» sigue abriendo en Suscripciones.
  Propuesta: Dejar la categoría sin elegir y pedirla antes de guardar, o
  adivinarla por el nombre (arriendo, gimnasio, crédito), y mostrar las
  preguntas de suscripción solo si se elige esa categoría.
- **Media.** *Varios dispositivos y Exportar.* Hay dos códigos distintos
  de 54 caracteres (el de sincronizar y el de respaldo) que se escriben a
  mano; el aviso de código equivocado tiene que explicar que «el de
  respaldo es otro». Hoy: Ahora el código se comparte, se pega y se nombra
  cuando es el otro. No hay QR y siguen siendo dos códigos. Propuesta:
  Ofrecer un QR para unir el otro dispositivo y el botón de compartir para
  guardar el código, y pensar si un solo código puede servir para las dos
  cosas.
- **Baja.** *Licencias › OpenStreetMap.* La licencia de OpenStreetMap solo
  está en inglés, en una app en español. Hoy: Ahora la nota de
  OpenStreetMap también está en español. El texto de la licencia sigue en
  inglés, como se publica. Propuesta: Agregar el párrafo en español antes
  del inglés en la entrada de OpenStreetMap; los enlaces y el nombre de la
  licencia pueden quedar igual.
- **Baja.** *Hoja de Ajustes del ejemplo > Tu key.* En el teléfono ese
  campo ya no existe. En la demo web, «Conectar» con la key vacía sigue
  sin hacer ni decir nada. Hoy: En el teléfono ese campo ya no existe. En
  la demo web, «Conectar» con la key vacía sigue sin hacer ni decir nada.
  Propuesta: En la demo web, desactivar «Conectar» hasta que haya texto, o
  decir «Pega tu key» bajo el campo.

### Inicio y Movimientos

- **Alta.** *Inicio > «Registra tu pago del 30 de septiembre» >
  «Registrar».* El formulario abre en «Ingreso», pero vacío, aunque la app
  ya sabe el monto (el pago del perfil), la categoría (Salario) y la fecha
  (el día de pago que pasó). Hay que llenar tres cosas y retroceder el
  calendario un mes. Propuesta: Abrirlo con el pago del perfil, Salario y
  la fecha del día de pago que pasó, para confirmar con un toque.
- **Media.** *«¿De dónde sale?» y «¿Me alcanza?» (Después del pago).* La
  app muestra «Te llegó la quincena: $2.400.000» por la Nómina del 30,
  pero en otras partes dice «No sabe cuánto te pagan» y «No sé cuánto te
  pagan, así que no lo cuento». Propuesta: Junto a «Te llegó la quincena»,
  preguntar «¿Te pagan $2.400.000 cada quincena?» y guardarlo con un
  toque.
- **Media.** *Editar movimiento, «Eliminar».* Al confirmar, el movimiento
  se borra sin forma de deshacerlo, aunque la cifra de Inicio cambie.
  Propuesta: Después de borrar, mostrar unos segundos un aviso con
  «Deshacer».
- **Media.** *Inicio, «Tus cuentas».* La cuenta en dólares, Binance y
  Bitcoin aparecen en la misma lista que Bancolombia y Nequi, sin decir
  que no cuentan en «Puedes gastar». Propuesta: En Inicio, separar «De uso
  diario» de «Ahorro e inversión» como en Cuentas, o marcar las que no
  cuentan.
- **Media.** *Pagos fijos (desde «Por hacer»).* Propone Rappi como pago
  fijo, pero no el Arriendo de $1.200.000. «No tengo pagos fijos» se
  acepta con un toque aunque haya un arriendo en el historial, y la cifra
  deja de ser provisional. Propuesta: Proponer también los gastos de
  Arriendo, Servicios y Créditos aunque haya uno solo, y antes de aceptar
  «No tengo pagos fijos» preguntar por ese arriendo.
- **Baja.** *Inicio, «¿Me alcanza para…?».* «Ver» sin precio abre una
  página vacía en vez de pedir el precio ahí mismo. Propuesta: Sin precio,
  que «Ver» se quede en Inicio y ponga el foco en el campo, o que no se
  pueda tocar.
- **Baja.** *Dividir un gasto.* «Quitar la división» es un botón de texto
  común, sin color de peligro ni confirmación. El grupo nuevo toma el
  nombre del comercio («Crepes & Waffles») en vez del de las personas.
  Propuesta: Pedir confirmación al quitar, diciendo que lo que te deben
  deja de contar, y nombrar el grupo por las personas, como «Con Ana y
  Juan».
- **Baja.** *Nueva categoría.* La categoría creada queda con una etiqueta
  gris genérica, sin ícono ni color propio, y es difícil de distinguir en
  las listas. Propuesta: Dejar elegir ícono y color al crearla.
- **Baja.** *Inicio y Movimientos, botón flotante.* Quieto, el botón
  «Movimiento» tapa el monto de la última fila visible. Propuesta: Hacerlo
  compacto, solo con el +, mientras haya filas debajo, o correrlo para que
  no quede sobre los montos.
- **Baja.** *Inicio, «¿Me alcanza para…?» y la página «¿Me alcanza?».* El
  campo del precio siempre muestra «$», aunque la moneda de los totales
  sea euros, libras o reales; el resto de la app usa el símbolo de esa
  moneda. (Nuevo.) Propuesta: Usar en los dos campos el símbolo de la
  moneda de los totales, como ya hace «Dividir un gasto».
- **Baja.** *Pregúntale a tu plata.* El título se corta («Pregúntale a tu
  p…») por «Nueva» y el ícono de información. Sin conexión, el error es
  genérico («No pude responder esta vez»), aunque la app distingue el caso
  sin conexión. Hoy: Con una conversación abierta, el título se corta por
  «Nueva» y el ícono de información. Sin red, el código ya muestra «Sin
  conexión a internet…»; «No pude responder esta vez» queda para otros
  errores. Propuesta: Pasar «Nueva» a un ícono o acortar el título, y
  probar en modo avión que salga el mensaje de sin conexión.
- **Baja.** *Tasas (desde «Ver tasas»).* Ofrece «Usar la automática» para
  EUR aunque no hay tasa automática, lo que volvería a contar los euros
  como cero. El ícono de actualizar parece de «deshacer». Hoy: «Usar la
  automática» aparece aunque la app no tenga la tasa de hoy; si no la
  consigue, avisa y deja la tuya, sin volver a cero. El ícono de
  actualizar sigue pareciendo «deshacer». Propuesta: Mostrar «Usar la
  automática» solo cuando se sepa la tasa automática de hoy, y usar el
  ícono de flechas en círculo.
- **Baja.** Las dos pantallas se contradicen: el aviso de Inicio usa una
  proyección de 45 días y dice «El 5 nov te quedarías sin plata», mientras
  «Próximos 30 días» dice «No te quedas sin plata en estos 30 días»
  (hallazgo del agente anterior, sigue igual). Además, después de guardar
  los sobres, Inicio sigue diciendo «Tu saldo mínimo estimado será
  $157.961», como si los sobres no existieran. Hoy: Inicio y «Próximos 30
  días» ya no se contradicen. Después de guardar los sobres, «Próximos
  días» sigue mostrando el mismo saldo mínimo, como si los sobres no
  existieran. Propuesta: Decir junto al saldo mínimo cuánto de eso está en
  sobres y reserva, o mostrar el mínimo de lo libre para gastar. (Ver los
  próximos días; Atender lo que está por hacer)

### Cuentas y Cripto

- **Media.** *Agregar cuenta.* Al elegir una cripto (ETH, BTC) como
  moneda, «Cuenta de uso diario» sigue encendida aunque su propia ayuda
  dice «Apágalo para … cripto»; hay que apagarla a mano. Propuesta: Apagar
  el interruptor solo al elegir una moneda cripto (también «Otra cripto»),
  salvo que la persona ya lo haya tocado, igual que pasa con Exchange y
  Ahorro.
- **Media.** *Binance (conectar).* El botón para ver la Secret Key es un
  candado que cambia a un chulo, sin tooltip: un lector de pantalla no
  dice qué hace. Propuesta: Usar un ojo y un ojo tachado, con la etiqueta
  «Mostrar» / «Ocultar» para el lector de pantalla.
- **Media.** *Binance conectada, con cuentas llevadas a mano.* Si al
  conectar no se toca «Archivarlas», lo de Binance queda contado dos veces
  en el patrimonio y solo la página de Binance lo dice; ni Cuentas ni la
  fila de Binance en «Gestionar fuentes» avisan. (Nuevo.) Propuesta:
  Mientras haya cuentas a mano repetidas, decirlo en la fila de Binance
  («Hay saldos contados dos veces») con un paso directo a «Archivarlas».
- **Baja.** *Cripto (cuenta en 0) y página de cripto vacía.* Una cuenta de
  bitcoin nueva en 0 muestra «Precio —» aunque el precio se conoce, y la
  página de cripto dice «Aún no tienes cripto. Agrega una billetera o
  conecta Binance» justo después de crear la cuenta. Propuesta: Mostrar el
  precio de la moneda aunque el saldo sea 0 y, si ya hay una cuenta cripto
  vacía, ofrecer en la página vacía «Registrar tu primera compra» en esa
  cuenta.
- **Baja.** *Agregar billetera.* Hay que elegir la red aunque la dirección
  la delata (bc1/1/3 Bitcoin, 0x Ethereum, T TRON); con la red equivocada
  solo sale un error. Propuesta: Elegir la red sola al pegar la dirección
  (bc1, 1 o 3: Bitcoin; 0x: Ethereum; T: TRON) y dejar el selector solo
  para corregir.
- **Baja.** *Cuentas (resumen arriba).* «Lo que debes en tarjetas» va con
  signo menos (−$844.800) mientras la fila de la tarjeta dice «Debes
  $844.800» en positivo. Propuesta: Usar la misma forma en los dos
  lugares: «Debes en tarjetas $844.800», sin signo.
- **Baja.** *Cripto (gráfica en «Valor»).* En «Valor» la cifra de arriba
  sigue siendo lo ganado por precio (+$95.805 en 7 días) mientras la línea
  salta con la plata que entró; hace falta leer la nota para entenderlo.
  Propuesta: En «Valor», poner arriba el valor al inicio y al final del
  periodo (por ejemplo «$5,2M → $6,4M en 7 días») y dejar la ganancia por
  precio como segunda línea.
- **Baja.** *Calendario de fecha (compra/venta y movimiento).* Los botones
  salen «Cancelar» y «ACEPTAR», uno en mayúsculas y otro no. Propuesta:
  Pasar «Aceptar» y «Cancelar» a todos los calendarios de la app, no solo
  a estos dos (por ejemplo con una función común para abrir el
  calendario).
- **Baja.** *Cuentas, fila «Rendimiento y ganancia».* Solo dice el
  porcentaje (+6,95 %), no cuánta plata es. Propuesta: Agregar el monto:
  «Ganancia no realizada +$576.715 · +6,95 %».
- **Baja.** *Registrar venta.* Vender todo exige escribir la cantidad
  exacta (0,0123); un error de dígitos deja residuos o se rechaza.
  Propuesta: Un botón «Todo» junto a la cantidad que llene el saldo de la
  cuenta.
- **Baja.** *Agregar cuenta, «Otra cripto».* Hasta escribir el símbolo, el
  saldo dice «COP» y no aparece «¿Cuánto te costó?». El error solo repite
  la etiqueta «Símbolo, por ejemplo ADA». Propuesta: Tratar «Otra cripto»
  como cripto desde que se elige (saldo con decimales y campo de costo
  visible) y mostrar un error claro: «Escribe el símbolo de la moneda, por
  ejemplo ADA».
- **Baja.** *Editar tarjeta, «Cuenta de uso diario».* La ayuda dice que lo
  que debes deja de restarse, pero también dejan de restarse los cobros
  fijos de la tarjeta (Netflix, $26.900). Propuesta: Decir: «Si está
  encendido, lo que debes en esta tarjeta y lo que se cobra en ella se
  restan de lo que puedes gastar, porque los pagas con tus cuentas de uso
  diario.».
- **Baja.** *Tasas.* En una moneda normal, la línea de abajo repite la de
  arriba: «1 USD = $3.312,84» y luego «Conversión a COP: 1 US$ = $3.312,84
  · TRM oficial…». Propuesta: Cuando la conversión es de un solo paso,
  mostrar debajo solo de dónde sale y de qué día: «TRM oficial del 3 oct».
- **Baja.** *Tasas, «Volver a la tasa automática» del bitcoin.* Además
  trae otra vez todas las tasas (el dólar pasó de $3.312,84 a $4.000 en la
  prueba) sin decir que cambiaron otras. Propuesta: Mostrar un aviso corto
  con lo que cambió (por ejemplo «También se actualizó el dólar: $3.312,84
  → $4.000»), o volver solo esa tasa.
- **Baja.** *Binance conectada.* Cada vez que se abre la cripto y pasaron
  más de 30 minutos, se lee Binance sola; con una llave que falla aparece
  otra vez el aviso rojo «Algo salió mal… Intenta de nuevo», sin decir qué
  hacer. Propuesta: Tras dos o tres fallos seguidos, decir «Revisa tu
  llave o pégala de nuevo» con un botón «Cambiar la llave» que abra el
  formulario, y espaciar las lecturas automáticas mientras siga fallando.
- **Baja.** *Registrar compra/venta contra una cuenta propia.* Para una
  compra o venta, el formulario no ofrece volver a «Fuera de Quincena» con
  una explicación. Al elegir una cuenta, el selector de moneda desaparece
  sin aviso. Propuesta: Cuando se elige una cuenta, dejar una línea bajo
  el total: «El total va en la moneda de esa cuenta (USDT)».
- **Baja.** *Agregar billetera.* Una dirección con la forma correcta pero
  mal copiada (un carácter cambiado) se rechaza con «No se pudo leer esa
  dirección. Revisa tu conexión e intenta de nuevo.»: culpa a la conexión
  y reintentar nunca funciona. (Nuevo.) Propuesta: Comprobar que la
  dirección esté bien escrita antes de consultarla y decir «Revisa que la
  dirección esté completa y bien copiada»; hablar de la conexión solo
  cuando de verdad no la hay.

### Plan

- **Media.** *Viajes › página del viaje.* Todo gasto entre las fechas del
  viaje cuenta, aunque sea en Medellín y en pesos (Éxito, Metro de
  Medellín, gimnasio): hay que sacarlos uno por uno con «No es del viaje».
  Propuesta: En un viaje en otra moneda, contar por defecto los cobros en
  esa moneda o de la tarjeta usada afuera, y preguntar por el resto en
  bloque («Estos 6 gastos en pesos, ¿son del viaje?»).
- **Media.** *Ingresos variables › Cobro.* «Borrar cobro» borra de una
  vez, sin confirmar ni deshacer; y sin hoja de compartir el aviso de
  «Mensaje copiado» queda tapado por el formulario. Propuesta: Pedir
  confirmación o mostrar «Deshacer» al borrar, y mostrar el aviso de
  mensaje copiado dentro de la hoja (o cerrar la hoja antes).
- **Media.** *Viajes › página del viaje.* «No es del viaje» saca el gasto
  de una vez, sin «Deshacer», y no hay dónde ver ni devolver lo que se
  sacó. Propuesta: Mostrar un aviso con «Deshacer» y una sección «Gastos
  que sacaste» para devolverlos. (Cuadrar los gastos de un viaje)
- **Media.** *Ingresos variables › Cobro.* La primera opción de «¿Con qué
  movimiento llegó?» sigue siendo «No, o no está en Quincena», y no
  propone el ingreso de $700.000 de Agencia Uno aunque coinciden nombre y
  valor. Propuesta: Decir «Ninguno, o no está en Quincena» y dejar elegido
  el ingreso que coincide. Mejor aún: cuando llegue ese ingreso, ofrecer
  marcar el cobro como cobrado. (Anotar lo que me deben mis clientes)
- **Baja.** *Cargos para revisar.* Para el pago visto dos veces dice
  «ábrelo y bórralo tú»: hay que tocar el movimiento, buscar «Eliminar» y
  confirmar. Propuesta: Botón «Borrar el repetido» en la tarjeta, que pida
  confirmar y deje deshacer. Si la app no debe borrar sola, al menos
  «Abrir el repetido», que lleve directo al movimiento que sobra.
- **Baja.** *Gastos compartidos › Registrar pago.* «Registrar pago» no
  deja elegido «Pedro te envió · $50.000» aunque coinciden nombre y valor;
  hay que buscarlo en la lista. Propuesta: Dejar elegido el ingreso que
  coincide en nombre y valor. (Quedar a paz y salvo)
- **Baja.** *Viajes › Incluir un gasto de antes.* «Incluir un gasto de
  antes» sigue listando todos los gastos de 120 días, arriendo y
  suscripciones incluidos, sin buscador. Propuesta: Mostrar primero
  transporte, alojamiento y gastos grandes, y permitir buscar. (Cuadrar
  los gastos de un viaje)
- **Baja.** *Lo quiero, pero después.* Un deseo no se puede cambiar: tocar
  la tarjeta no abre nada y la hoja solo sirve para agregar. Para corregir
  el precio, la prioridad o la espera hay que borrarlo y crearlo otra vez.
  (Nuevo.) Propuesta: Que tocar el deseo abra su hoja con lo guardado,
  como pasa con las metas y los pagos fijos.
- **Baja.** *Compras a cuotas › Pagos y Gastos compartidos › Pagos.* La
  caneca «Quitar este pago» borra un pago ya registrado de una vez, sin
  confirmar ni deshacer: un toque de más cambia lo que falta pagar o lo
  que te deben. (Nuevo.) Propuesta: Mostrar un aviso con «Deshacer» al
  quitar un pago.
- **Media.** *Plan › Colchón en días y Ajustes › Colchón.* Dos cosas
  distintas se llaman «Colchón»: el fondo de emergencia medido en días,
  que no toca «Puedes gastar», y la plata guardada sin tocar de Ajustes,
  que sí lo baja. Elegir cuentas en «Colchón en días» no mueve nada en
  Inicio. Hoy: Ahora la herramienta del Plan se llama «Fondo de emergencia
  en días». El colchón de Ajustes conserva su nombre. Propuesta: Llamarla
  «Fondo de emergencia en días» (y la sección «Dónde está tu fondo») y
  agregar una línea: «La plata que no quieres contar en lo que puedes
  gastar se fija en Ajustes › Colchón».
- **Media.** *Lo quiero, pero después.* No hay «Lo compré»: comprar un
  deseo es ir a Movimientos y luego borrarlo a mano. La caneca lo borra
  sin confirmar ni deshacer. Hoy: Ahora «Lo compré» abre el gasto ya lleno
  y quita el deseo al guardarlo. Borrar un deseo sin poder deshacerlo es
  de la fase 35. Propuesta: «Lo compré» que abra el gasto ya lleno con el
  nombre y el precio y quite el deseo; al quitarlo, mostrar un aviso con
  «Deshacer».
- **Media.** *Plan › Metas.* Una meta con la fecha vencida no avisa nada
  en la fila, y una vez puesta la fecha no se puede quitar; solo se puede
  mover. Hoy: Ahora una meta con la fecha vencida lo dice en la fila. La
  fecha todavía no se puede quitar. Propuesta: Avisar «La fecha ya pasó:
  ¿la mueves?» y agregar un botón para quitar la fecha, como el de la
  prueba gratis. (Poner al día una meta y una prueba gratis vencidas)
- **Baja.** *Hoja de la meta.* «Para el 30 de abril» no dice el año, y el
  calendario abre seis meses adelante, en otro año. Hoy: Ahora la fecha de
  la meta dice el año. El calendario sigue abriendo seis meses adelante.
  Propuesta: Mostrar el año cuando no es el actual: «Para el 30 de abril
  de 2027».
- **Baja.** *¿Y si…? › Pago tarde y Le presté.* Las flechas abajo/arriba
  significan menos/más días; en «Monto» de Le presté el signo va pegado
  («$80.000») y en las demás hojas con espacio («$ 80.000»). Hoy: Ahora
  los días de «Pago tarde» bajan y suben con menos y más. El signo pegado
  en «Le presté» sigue igual. Propuesta: Usar − y + para los días, y un
  solo prefijo en todos los formularios tomado de la moneda de la cuenta
  (hoy tres pantallas ponen «$ » fijo).

### Por revisar e Importar extracto

- **Alta.** *Por revisar, aviso de una transferencia que salió
  («Transferiste $150.000 a tu Nequi»).* Llega como gasto «Sin comercio ·
  Otros» y sin cuenta. Registrarlo como transferencia toma cinco toques
  (Editar, Transferencia, Desde, Bancolombia, Registrar). «¿Viene de otra
  cuenta tuya?» solo aparece en lo que llega. Propuesta: Cuando el mensaje
  dice «a tu Nequi» u otra cuenta propia, proponer de una vez la
  transferencia Bancolombia → Nequi; y en lo que sale, ofrecer «¿Fue a
  otra cuenta tuya?».
- **Media.** *Por revisar, tarjeta en «Posibles repetidos».* «El mismo
  pago ya llegó por otra vía.» no dice con qué movimiento choca (fecha,
  cuenta, si se anotó a mano) ni deja abrirlo, así que la persona no puede
  comprobarlo antes de descartar o tocar «No es repetido». Propuesta:
  Mostrar el gemelo en la tarjeta («Ya está: Spotify US$10,99, 2 oct,
  Cuenta en dólares, anotado a mano») y abrirlo con un toque.
- **Media.** *Por revisar, ingreso de «Diego Lopez».* Un ingreso que trae
  el mismo nombre del perfil (Diego) se propone como ingreso y hay que
  tocar «¿Viene de otra cuenta tuya?». Propuesta: Si quien envía tiene el
  nombre del perfil, proponerlo de una vez como transferencia entre sus
  cuentas.
- **Media.** *Por revisar, menú «⋮».* «Descartar» y «Descartar y no leer
  más Bancolombia» actúan sin confirmar y sin «Deshacer», y no hay dónde
  ver lo descartado. Silenciar todo un banco tiene mucho efecto para un
  toque. Propuesta: Mostrar un aviso con «Deshacer» al descartar, como al
  registrar, y confirmar antes de dejar de leer una app.
- **Media.** *Por revisar, «Corregir» en lo registrado solo.* Corregir la
  categoría de algo registrado solo (Rappi de Restaurantes a Salidas) no
  cambia lo aprendido: el próximo Rappi vuelve a Restaurantes, y la
  tarjeta sigue diciendo «Sugerido porque… reconocimos Rappi». Propuesta:
  Al corregir la categoría, actualizar la regla del comercio o preguntar
  «¿Siempre Salidas para Rappi?», y refrescar el porqué de la tarjeta.
- **Media.** *Importar extracto, hoja de una línea (RETIRO CAJERO).* Un
  retiro en cajero entra como gasto sin categoría. Al cambiarlo a
  «Transferencia», «Hacia» propone la Visa y no Efectivo. Propuesta:
  Reconocer «retiro» o «cajero» como paso a Efectivo y proponer la línea
  así marcada.
- **Media.** *Importar extracto sin tarjeta en la app.* «Parece el pago de
  una tarjeta. Agrégala en Cuentas…» no dice qué línea es ni lleva a
  Cuentas. La línea va marcada como gasto en Créditos. Propuesta: Señalar
  esa línea con el aviso, dejarla sin marcar y poner un botón «Agregar
  tarjeta» que vuelva a la revisión.
- **Media.** *Por revisar, segundo aviso de una misma transferencia.* El
  aviso de Nequi por la plata que ya se registró queda en «Posibles
  repetidos» con «El mismo pago ya llegó por otra vía.». Hay que
  entenderlo y descartarlo a mano. Propuesta: Reconocerlo como la llegada
  de esa transferencia y archivarlo solo, con un aviso: «Llegó a Nequi:
  era la transferencia desde Bancolombia».
- **Media.** *Hoja «¿De qué cuenta salió?» y «Detectamos Bancolombia, pero
  tienes dos cuentas ahí».* Para una transferencia o para plata que llega,
  la Visa (tarjeta de crédito) cuenta como una de las dos cuentas de
  Bancolombia, así que la app no se decide por la cuenta de ahorros.
  Propuesta: Si el aviso es de plata que llega o de una transferencia,
  preferir la cuenta bancaria de ese banco y dejar las tarjetas para las
  compras.
- **Media.** *Hoja de «¿Viene de otra cuenta tuya?» con un aviso de
  Bancolombia.* Propone Bancolombia → Nequi aunque la plata llegó a
  Bancolombia. Hay que cambiar las dos cuentas. Propuesta: Poner en
  «Hacia» la cuenta del banco que mandó el aviso y en «Desde» la otra
  cuenta más probable (la de otra moneda o la que más mueve plata).
- **Media.** *Por revisar, compra de un banco sin cuenta (Falabella,
  Davivienda).* «Elegir la cuenta» solo ofrece las cuentas que ya existen
  y promete «La próxima vez, lo de Davivienda irá directo a esa cuenta».
  Así la app aprendería a mandar Davivienda a Bancolombia o a la Visa.
  Propuesta: Ofrecer «Agregar mi cuenta de Davivienda» en la tarjeta y no
  aprender la regla del banco cuando la cuenta elegida es de otro banco.
- **Media.** *Por revisar, compra con una tarjeta que la app no conoce.*
  Si ya hay regla del banco (aprendida de un aviso sin tarjeta), una
  compra con cualquier tarjeta nueva de ese banco la toma y queda lista en
  esa cuenta (lib/capture/capture_service.dart:392-412 y 440-448). Con la
  Visa de Bancolombia, una compra «T.Cred *9876» iría a la cuenta de
  ahorros, o se registraría sola con «Registrar solo lo que esté claro», y
  al confirmarla se aprende «la tarjeta *9876 va a Bancolombia». (Nuevo.)
  Propuesta: No aplicar la regla del banco a una tarjeta desconocida
  cuando ese banco tiene una tarjeta de crédito en la app: preguntar la
  cuenta la primera vez.
- **Baja.** *Importar extracto de la tarjeta, resultado y revisión.* Con
  «Mi saldo ya los incluye», la tarjeta dice «Lo que debes en Visa:
  $844.800 → $844.800»: parece que algo debía cambiar. Propuesta: Usar
  para la tarjeta la frase del banco: «Lo que debes en Visa sigue en
  $844.800: ya incluía estos movimientos».
- **Baja.** *Por revisar, pegar el mismo mensaje dos veces.* El mismo
  texto exacto pegado otra vez deja una segunda tarjeta en «Posibles
  repetidos» que hay que descartar a mano. Propuesta: Si el texto es
  idéntico a uno leído en los últimos días, no guardarlo y dejar solo el
  aviso «Ese pago ya estaba.».
- **Baja.** *Por revisar con solo un posible repetido.* Arriba dice «Todo
  al día. No tienes movimientos pendientes» mientras abajo espera un
  posible repetido. Propuesta: Decir «Nada por registrar · 1 posible
  repetido por mirar» cuando solo quedan repetidos.
- **Baja.** *Aviso después de registrar.* «Desde ahora, «Laura Gomez» va a
  Otros ingresos. Y una regla más.»: el nombre pierde la tilde que tiene
  la tarjeta («Laura Gómez»), y «una regla más» no dice cuál. Propuesta:
  Escribir el nombre como en la tarjeta y nombrar la otra regla («y lo de
  Nequi va a Nequi»).
- **Baja.** *Hoja «¿De qué cuenta salió?» y diálogo de Reglas aprendidas.*
  Para una compra en pesos se listan Binance y Bitcoin (exchanges de
  cripto), y lo mismo pasa al cambiar la cuenta de una tarjeta. Propuesta:
  Mostrar las cuentas que gastan en esa moneda y dejar el resto bajo
  «Otras cuentas», también en el diálogo de Reglas aprendidas.
- **Baja.** *Reglas aprendidas.* La papelera borra la regla de una vez,
  sin confirmar ni «Deshacer». Propuesta: Mostrar un aviso con «Deshacer»
  al borrar una regla.
- **Baja.** *Importar extracto, nombres de las líneas.* Los nombres
  limpios a veces quedan raros: «SU Pago Gracias», «Tarjeta Visa»,
  «Cajero», «Nomina DL Soft», «Tarjeta Credito». Propuesta: Traducir
  frases conocidas: «Pago recibido», «Pago de la Visa», «Retiro en
  cajero», «Nómina».
- **Baja.** *Importar extracto desde Ajustes.* Si el archivo no nombra el
  banco, el extracto se asigna a la primera cuenta (Bancolombia) y solo el
  menú de arriba lo muestra. Propuesta: Preguntar la cuenta antes de la
  revisión, o resaltar el menú «Cuenta» cuando no salió del archivo.
- **Baja.** *Por revisar, «Registrar 3 de los 5 listos».* No se ve cuáles
  2 de los listos quedan por fuera ni por qué (Laura y Tienda La Esquina,
  por categoría no segura). Propuesta: Marcar en esas filas «categoría por
  confirmar», o decirlo bajo el botón.
- **Baja.** *Ajustes › Captura automática, «Usar la ubicación del pago».*
  El subtítulo del interruptor es un párrafo legal de nueve líneas que
  tapa las otras opciones. Propuesta: Dejar una línea («Sugiere el
  comercio por dónde estabas») y llevar el detalle a un enlace «Cómo se
  usa la ubicación», ya que el aviso al prenderla lo explica.
- **Baja.** *Por revisar, filas cortas (más de 5 esperando).* En la fila
  de Juan Valdez la fecha se parte en «3» y «oct» en dos renglones.
  Propuesta: Unir el día y el mes con un espacio que no se parta, como ya
  se hace con la hora, o quitar el día en la fila corta.
- **Baja.** *Revisar movimiento desde Por revisar, «Fecha».* Solo dice
  «Hoy» o «Ayer». La hora del aviso (9:40) no se ve y no se puede cambiar,
  y un día elegido a mano queda a las 12:00. Propuesta: Mostrar la hora
  («Hoy, 9:40 a. m.») y dejar ajustarla junto con el día.
- **Baja.** *Importar extracto, línea «Tarjeta de Credito · Créditos».* La
  categoría Créditos usa un birrete, que se lee como crédito educativo. En
  el pago de una tarjeta sin agregar, eso refuerza la idea equivocada de
  que es un gasto. Propuesta: Usar un ícono de préstamo o de tarjeta para
  Créditos y ofrecer «Agregar la tarjeta» en esa misma línea.
- **Baja.** *Importar extracto, «No encontré movimientos en este
  archivo.».* No dice qué leyó ni qué formatos sirven. Esa ayuda solo
  aparece cuando el archivo falla del todo. Propuesta: Decir qué se
  encontró («una fila de títulos, ninguna con fecha y valor») y recordar
  los formatos que lee: CSV, Excel (.xlsx) o PDF.
- **Baja.** *Por revisar, aviso que no dice si entró o salió («Sin
  comercio»).* La tarjeta muestra la categoría «Otros», que es de gastos,
  antes de saber si fue gasto o ingreso. Propuesta: Mostrar «Sin
  clasificar» hasta que se elija si es gasto o ingreso.
- **Baja.** *Reglas aprendidas y aviso de registro.* Los nombres pierden
  las tildes («Exito Laureles», «Laura Gomez») porque se arman desde la
  clave normalizada, mientras la tarjeta dice «Éxito Laureles». Propuesta:
  Guardar con la regla el nombre como se mostró y usarlo en la lista y en
  los avisos.
- **Baja.** *Por revisar, «Posibles repetidos».* El único botón a la vista
  es «No es repetido»; quitar el repetido, que es lo más común, queda
  escondido en «⋮ › Descartar» (lib/ui/own/inbox_page.dart:918-924 y
  966-970; flujo 07-05). (Nuevo.) Propuesta: Poner «Quitar repetido» como
  botón principal y dejar «No es repetido» al lado. (Quitar un pago que
  llegó dos veces)
- **Baja.** *Importar extracto de la tarjeta, hoja del pago.* Al marcar el
  pago a la tarjeta, «Desde» propone la primera cuenta de uso diario de la
  lista, no la del mismo banco de la tarjeta
  (lib/ui/own/statement_page.dart:1245-1266): con una tarjeta de
  Davivienda propondría Bancolombia si va primero. (Nuevo.) Propuesta:
  Proponer primero la cuenta del mismo banco que la tarjeta.
- **Baja.** *Importar extracto, líneas «Ya registrado».* «Ya registrado»
  no dice con qué movimiento coincidió (mismo valor, hasta 3 días de
  diferencia); si el cruce está mal, la línea queda sin marcar y no hay
  cómo comprobarlo (lib/statements/statement_import.dart:333-362 solo
  guarda recorded; statement_page.dart:1109-1113). (Nuevo.) Propuesta:
  Mostrar en la línea o en su hoja el movimiento con el que coincidió
  («Éxito Laureles, 2 oct, anotado a mano»).
- **Alta.** *Por revisar, después de elegir la cuenta.* Elegir la cuenta
  de una captura con tarjeta *1234 no resuelve las otras que esperan con
  la misma tarjeta o el mismo banco: hay que repetir la elección en cada
  una. Hoy: Lo aprendido al elegir la cuenta (tarjeta, número de cuenta o
  banco) llega solo a las capturas que esperan, que pasan a «Listos para
  registrar», y «Deshacer» lo revierte. El aviso no dice que otras
  quedaron listas. Propuesta: Decir en el aviso cuántas pendientes se
  resolvieron con lo aprendido («y 2 más quedaron listas»).
- **Media.** *Por revisar con una sola cuenta de uso diario.* Cada pago
  sin banco queda en «Necesitan información» con «Revisa la cuenta: la
  elegimos por ser tu única…», aunque ya se confirmó antes. Nunca queda
  listo ni se registra solo. Hoy: Si el pago trae tarjeta, la primera
  confirmación enseña la tarjeta y los demás con esa tarjeta quedan
  listos. Un pago sin banco ni tarjeta sigue cada vez en «Necesitan
  información» con «Revisa la cuenta: la elegimos por ser tu única…» y
  nunca se registra solo. Propuesta: Después de confirmar un pago sin
  banco ni tarjeta, aprender «sin banco → esa cuenta» y tratar los
  siguientes como listos.

### La cuenta de ejemplo y Pregúntale a tu plata

- **Media.** *Pregúntale a tu plata (avisos de error).* Los avisos «Sin
  conexión…», «El modelo está recibiendo demasiadas preguntas…» y «No pude
  responder esta vez» piden volver a intentar, pero no hay botón: hay que
  escribir la pregunta otra vez. Hoy: Ahora el aviso trae «Volver a
  preguntar». No se reintenta solo al volver la red. Propuesta: Poner
  «Volver a preguntar» dentro del aviso, que repita la misma pregunta; sin
  red, que se active solo cuando vuelva la conexión.
- **Baja.** *Inicio con mis cuentas y Pregúntale a tu plata.* Las mismas
  preguntas se ven con chevrón en Inicio y con flecha en la página, y en
  Inicio solo tres de las cinco. Hoy: Ahora las preguntas llevan el mismo
  chevrón en su página y en Inicio. Inicio sigue mostrando tres, con «Otra
  pregunta». Propuesta: Un solo estilo de fila para las preguntas en las
  dos pantallas.

## Lo que dijo el primer experto

El mismo 9 de octubre llegó la revisión de un experto que recorrió los 181
flujos ([texto completo](2026-10-09-experto.md)). Sus afirmaciones sobre
cómo funciona hoy la app se revisaron contra el código y las capturas: de
34, 21 son ciertas, 12 lo son en parte y 1 no. Lo demás son propuestas, y
el plan de abajo las recoge. Entre paréntesis, la sección de su texto.

- **Cierto.** *Dos verdades sobre la misma plata (2 y 3).* Inicio dice
  «Puedes gastar $7.961» y más abajo «Tu saldo mínimo estimado será
  $157.961 el 12 de octubre». La diferencia es la reserva de ingresos
  variables, $150.000, y la pantalla no lo dice. «¿Me alcanza?» ya lo
  explica.
- **Cierto.** *Inicio sin cuentas (5).* Sin cuentas, Inicio da $0, «Tus
  cuentas» queda vacío y «+ Movimiento» muestra «Primero agrega una
  cuenta.» sin botón. Una persona nueva no llega ahí, porque configurar
  exige una cuenta: pasa al archivar o borrar todas.
- **En parte.** *Configurar pide demasiado (6).* Lo obligatorio es un
  nombre y una cuenta, unos 7 toques; la moneda y la forma de pago ya
  vienen marcadas y lo demás es opcional. Pero todo lo opcional se muestra
  en el camino, y el flujo 01-02 lo recorre completo a propósito.
- **Cierto.** *El pago de la quincena no viene lleno (7).* «Registrar»
  abre el ingreso con la primera cuenta, el monto vacío, sin categoría y
  con la fecha de hoy, aunque el perfil sabe que son $2.400.000. El perfil
  no guarda a qué cuenta llega el pago.
- **No es así.** *Una captura clara pide varias acciones (9).* Una captura
  clara ya tiene un solo botón principal, «Registrar gasto», más «Editar»
  y el menú. Con más de 5 esperando, las que están listas son filas con un
  solo chulo.
- **En parte.** *Lo aprendido no resuelve lo que espera (10).* Sí lo
  resuelve: las capturas de la misma tarjeta quedan listas para registrar
  con un toque. Lo que falta es decirlo; el aviso solo habla de la regla.
- **Cierto.** *Las transferencias propias quedan como gasto (11).*
  «Transferiste $150.000 a tu Nequi» llega como un gasto sin cuenta.
  Volverlo transferencia pide Editar, Transferencia y Desde. «¿Viene de
  otra cuenta tuya?» solo aparece en lo que llega.
- **Cierto.** *Nada ataja el pago de la tarjeta como gasto (12).* «Pago
  Visa» se guarda como gasto sin mirar el nombre, la categoría ni el
  monto. Solo el importador de extractos reconoce algunos pagos de tarjeta
  por palabras, y no «Pago Visa».
- **Cierto.** *La cuenta predeterminada es siempre la primera (15).* «+
  Movimiento» toma la primera cuenta creada y no hay forma de
  reordenarlas. No usa la última cuenta ni la del comercio.
- **Cierto.** *Movimientos no tiene filtros (16).* Hay un solo campo que
  busca en el nombre, la nota, la cuenta y la categoría, sin filtros. No
  busca en el monto, así que «187400» no encuentra $187.400.
- **Cierto.** *Las filas cortan lo importante (17).* La segunda línea
  junta categoría, cuenta, «Programado» y «Tu parte» en un solo renglón y
  corta justo la marca, como en «Servicios · Bancolombia · Progra…».
- **Cierto.** *El patrimonio no suma lo que se ve (18 y 19).* «Les debes a
  otras personas» y «Compras a cuotas» entran en la cifra pero solo
  aparecen dentro de «¿De dónde sale?».
- **En parte.** *Deuda negativa (20).* La fila y la página de la tarjeta
  dicen «A favor $55.200». El signo menos solo sale en «Editar cuenta», y
  ahí pasa algo peor: tocar el campo borra el signo y guardar vuelve deuda
  el saldo a favor.
- **En parte.** *Cambiar la moneda reinterpreta los números (21).* Solo
  sin conexión y sin una tasa guardada entre las dos monedas: el pago y el
  colchón conservan el número y cambian de moneda. Con tasa, convierte
  bien, pero no lo dice.
- **En parte.** *Binance no dice qué falta (24).* Sin una de las dos
  llaves, «Conectar» no hace ni dice nada. «Solo lectura» sí está a la
  vista sobre el formulario.
- **En parte.** *Plan no está ordenado (25 y 26).* Plan ya va en cinco
  grupos: el presupuesto, uno sin título con ingresos variables y viajes,
  metas, pagos y herramientas. Las suscripciones van dentro de «Pagos
  fijos» y los préstamos dentro de «Gastos compartidos».
- **Cierto.** *Las metas no miran su fecha (27).* La fila dice «llega en
  julio de 2027» aunque la fecha sea el 30 de abril, y no dice cuánto hace
  falta al mes; solo el planificador de la conversación lo hace. La fecha
  no dice el año.
- **Cierto.** *Las metas no tienen «Abonar» (28).* Para abonar se
  reescribe «¿Cuánto llevas?» con la suma hecha de cabeza, y lo ahorrado
  no toca ninguna cuenta.
- **En parte.** *Plata que sale sin cuenta (29).* Pagar una cuota, «Le
  pagaste a Camilo», «Me prestaron» y el gasto de grupo que pagaste no
  tocan ninguna cuenta, y «Puedes gastar» sube. «Le presté» sí pregunta de
  qué cuenta salió, y un pago recibido se puede ligar a un movimiento.
- **En parte.** *Repartir deja el día a día en cero (31).* Solo con muy
  poca plata: con $7.961 para repartir, todo va a la meta y el día a día
  queda vacío, porque el cálculo pone las metas primero.
- **En parte.** *«¿Y si…?» infla las cifras (32).* No resta el gasto del
  día a día. La pantalla dice qué cuenta, «tu pago esperado y lo
  programado», pero no lo que deja fuera.
- **Cierto.** *«Ya registrado» no dice con qué (35).* Solo dice «Ya
  registrado». El cruce guarda un sí o un no, así que ninguna pantalla
  puede mostrar con qué movimiento coincidió.
- **Cierto.** *En los repetidos, el botón principal es el menos probable
  (36).* El único botón a la vista es «No es repetido»; quitar el repetido
  está en el menú, y no dice con qué movimiento choca.
- **Cierto.** *Acciones que borran sin preguntar (37).* Borrar una regla,
  descartar una captura, «No es del viaje», borrar un deseo o un cobro no
  preguntan ni dejan deshacer. Borrar un movimiento pregunta, pero después
  no se puede deshacer. «Descartar aprendizaje» no existe.
- **Cierto.** *Ajustes mezcla demasiado (38).* Tiene siete secciones:
  perfil, avisos, widget, captura automática con billeteras y Binance,
  apariencia, tus datos con el ejemplo y «Borrar todo», y privacidad.
- **Cierto.** *Tema e idioma sin título (39).* Son dos filas sin título
  que empiezan con «Sistema».
- **Cierto.** *«Importar un archivo» reemplaza todo sin decir qué trae
  (40).* Está junto a «Importar extracto» y solo pregunta «¿Reemplazar
  todo con este archivo?», aunque ya leyó el archivo.
- **En parte.** *El código de 54 caracteres (41).* Se puede copiar con
  «Copiar el código» y pegar en el otro teléfono, pero no hay QR ni hoja
  de compartir.
- **Cierto.** *Los choques entre dispositivos no se comparan (42).* Solo
  se ve la versión que no quedó, con «Descartar» y «Traer de vuelta».
  Elegir pierde una de las dos ediciones.
- **Cierto.** *El engranaje de la conversación repite Ajustes (44).* En el
  ejemplo abre «Idioma», «Apariencia» y «Empezar de nuevo», que ya están
  en Ajustes, y cambiar el idioma ahí borra la conversación sin avisar.
- **En parte.** *Las 30 preguntas se acaban con un error (46).* Al tocar
  una sugerencia sin preguntas sale un aviso rojo. La página vacía sí
  avisa antes, pero las sugerencias y la barra siguen activas.
- **En parte.** *Las acciones sobre una respuesta gastan preguntas (47).*
  Con tus cuentas, sí: «Guardar gasto», «Guardar este plan» o «Ya las
  cancelé» descuentan una, y con la última pregunta el formulario llega
  pero no se puede guardar. En el ejemplo no hay cupo.
- **Cierto.** *Salir pierde la conversación (48).* Con tus cuentas, cada
  visita crea una conversación nueva y las preguntas quedan gastadas. La
  del ejemplo sí se conserva.
- **Cierto.** *La conversación no dice en qué cuenta guarda (49).* El
  gasto queda en la primera cuenta de la moneda de los totales y la
  respuesta no la nombra.

## Plan para que Quincena sea completa, sencilla y automática

El 9 de octubre llegó la primera revisión de un experto sobre los 181
flujos. Su conclusión: Quincena ya hace casi todo, y el siguiente salto es
que una persona nueva la pueda usar sin aprender cómo piensa por dentro.
De sus 34 afirmaciones sobre cómo funciona hoy la app, al revisarlas
contra el código, 21 resultaron ciertas, 12 lo son en parte y 1 no.

El plan sigue su orden: primero la confianza en las cifras y en que cada
peso quede en una cuenta, después que la app haga el trabajo y sea fácil
empezar, y al final el pulido. Cada fase se construye y se prueba con sus
flujos, como las anteriores, con cinco reglas: si Quincena ya lo sabe, no
lo pregunta; si lo supone, lo propone; si no lo sabe, pregunta solo eso;
si mueve plata, muestra de dónde salió o adónde llegó; y si cambia una
cifra, explica por qué.

Lo que digan los demás expertos en la página de la revisión puede mover el
orden.

### 27. Una sola verdad sobre la plata

**Estado:** Hecha. Inicio, «Próximos días» y «¿Me alcanza?» dicen lo
mismo: lo mínimo que tendrás libre, con lo apartado dicho aparte. El
patrimonio muestra cada parte y suma lo que se ve. Una tarjeta se marca
«Debes» o «A favor», sin signo menos. Sin tasa, cambiar la moneda de los
totales pide la tasa o la deja como estaba; con tasa, dice con cuál
convirtió, y en español los totales en dólares dicen US$. El mes se
compara con el mismo día del mes anterior, el cierre compara los pagos de
cada mes aparte del día a día, y después de importar un extracto dice cómo
cambió «Puedes gastar».

Tamaño: grande. «Puedes gastar $7.961» y «Tu saldo mínimo estimado será
$157.961» salen en la misma pantalla y las dos son ciertas: la diferencia
es la reserva, y no se dice. El patrimonio no suma lo que se ve en
Cuentas, editar una tarjeta con saldo a favor la vuelve deuda, y sin
conexión ni tasa guardada, cambiar la moneda vuelve pesos en dólares. Si
una cifra no cuadra con lo que se ve, la persona deja de creerles a todas.

- Los mismos cuatro conceptos en toda la app, a la vista bajo la cifra de
  Inicio y sin abrir «¿De dónde sale?»: «En tus cuentas», «Ya
  comprometido», «Apartado por ti» y «Puedes gastar».
- Inicio como un resumen de cuatro preguntas: cuánto puedo gastar, qué
  necesita mi atención, qué viene y ¿me alcanza? Lo que pide atención pesa
  menos que la cifra, y «¿Me alcanza?» queda a mano.
- En «Próximos días» y «Próximos 30 días», «Lo mínimo que tendrás libre»
  en vez del saldo mínimo, con lo apartado dicho aparte.
- Patrimonio con lo que tienes y lo que debes a la vista, incluidas las
  filas «Te deben», «Les debes» y «Compras a cuotas», para que lo que se
  ve sume la cifra.
- Un solo criterio de signos: «Debes $844.800» o «A favor $55.200»,
  también en «Editar cuenta», donde hoy tocar el campo borra el signo y
  guardar vuelve deuda el saldo a favor.
- Sin tasa, cambiar la moneda de los totales no cambia los números: ofrece
  mantener la moneda o escribir la tasa. Con tasa, dice que convirtió. Y
  «US$» o el código de la moneda cuando los totales no son en pesos.
- Comparar lo gastado en el mes con el mismo punto del mes anterior, y
  después de importar un extracto, decir cómo cambió lo que se puede
  gastar.

Sabremos que funcionó cuando cada cifra de Inicio, Cuentas y Plan se pueda
reconstruir con lo que está en pantalla, y los flujos lo comprueben.

### 28. La plata siempre queda en una cuenta

**Estado:** Hecha. Pagar una cuota, saldar un grupo, un préstamo o un
gasto compartido pregunta de qué cuenta sale o a cuál llega, con la más
probable escogida, y dice antes qué va a pasar. «Pago Visa» anotado como
gasto pregunta si es el pago de la tarjeta. Las metas tienen «Abonar», y
el cierre ofrece pasar a lo ahorrado lo que el sobre de cada meta apartó,
sin contarlo dos veces. Los deseos tienen «Lo compré», una compra a cuotas
con tarjeta ofrece anotar la compra si no está, y los gastos de un viaje
se dividen desde el viaje.

Tamaño: mediana. Pagar una cuota, saldar un gasto compartido o recibir un
préstamo no toca ninguna cuenta: la deuda baja y «Puedes gastar» sube como
si la plata no hubiera salido. Las metas no tienen «Abonar»: se reescribe
lo que llevas. Y anotar «Pago Visa» como gasto lo cuenta dos veces, sin
que nada lo ataje.

- Toda acción que mueve plata pregunta de qué cuenta salió o a cuál llegó,
  con la más probable ya escogida, y crea el movimiento ligado o deja
  escoger uno ya anotado, como ya hace «Le presté».
- Antes de confirmar, decir qué va a pasar: «Visa deberá $3.721.599,
  Bancolombia baja $338.327 y tu patrimonio no cambia».
- Si un gasto parece el pago de una tarjeta tuya, por el nombre, la
  categoría o el monto, preguntar «¿Estás pagando tu Visa?» y registrarlo
  como pago.
- «Abonar» en las metas, desde una cuenta, y al cerrar la quincena ofrecer
  pasar lo del sobre de la meta a lo ahorrado.
- «Lo compré» en los deseos, que abre el gasto ya lleno.
- En una compra a cuotas con tarjeta, ofrecer anotar la compra si no está
  en la tarjeta; en un viaje, dividir con alguien desde los gastos del
  viaje.

Sabremos que funcionó cuando en los flujos de Plan cada acción cambie el
saldo de una sola cuenta una sola vez, y «Puedes gastar» lo muestre
enseguida.

### 29. Metas y simulaciones en las que se puede confiar

**Estado:** Hecha. Cada meta con fecha dice si llega a tiempo y, si no,
cuánto hace falta al mes, con «Usar … al mes», y una meta cumplida lo
dice. El reparto pone primero el día a día y dice qué meta tendrá que
esperar; copiar el reparto anterior lo ajusta a lo que hay. «¿Y si…?»
cuenta lo que sueles gastar al día, o dice que no lo cuenta, y «Ahorro
más» se aplica a una meta. El cierre ofrece a una meta solo lo que el día
a día no va a necesitar hasta el pago.

Tamaño: pequeña. Una meta para el 30 de abril dice «llega en julio de
2027» y no avisa que no se llega ni cuánto hace falta; eso solo lo hace la
conversación. «¿Y si…?» no resta el gasto del día a día ni dice que lo
deja fuera, así que sus cifras salen infladas. Y repartir una quincena muy
corta deja vacío el día a día para darle todo a una meta.

- En cada meta con fecha, decir si se llega a tiempo y, si no, cuánto hace
  falta al mes, con «Usar $750.000 al mes», como ya hace el planificador
  de la conversación. La fecha dice el año.
- «¿Y si…?» cuenta el gasto habitual del día a día, o dice a la vista que
  no lo incluye.
- Al repartir, primero los pagos antes del próximo ingreso y un mínimo
  para el día a día, después las metas; si no alcanza, decirlo y proponer
  retomar la meta en la próxima quincena. Al copiar el reparto anterior,
  ajustarlo a lo que hay y decir qué cambió.

Sabremos que funcionó cuando ninguna meta con fecha quede sin decir si se
llega, y los flujos del reparto comprueben que el día a día nunca queda en
cero sin aviso.

### 30. Que la app haga el trabajo

**Estado:** En curso.

Tamaño: grande. La app ya sabe mucho de lo que todavía pregunta: cuánto te
pagan y cuándo, la categoría de un comercio que ya vio, que «a tu Nequi»
es una cuenta tuya. Lo que aprende ya deja listas las capturas que
esperan, pero no lo dice. Cada toque que se ahorra en Por revisar se
ahorra todos los días.

- Decir lo que se aprendió y lo que resolvió: «Aprendido. También quedaron
  listos otros 2 movimientos». Corregir una categoría actualiza la regla,
  y una regla del banco no se aplica a una tarjeta que la app no conoce.
- Reconocer las transferencias propias con una sola confirmación: «a tu
  Nequi», el nombre de la persona, el segundo aviso de una misma
  transferencia, el retiro en cajero y el pago de la tarjeta.
- Llenar de entrada lo que ya se sabe: «Registrar el pago del 30» abre con
  el monto, la fecha y la categoría; la cuenta de un gasto sale del
  comercio, si no de la última usada y si no de la más usada.
- En Por revisar, cada tarjeta dice qué falta («Lista para registrar»,
  «Falta elegir la cuenta», «Posible repetido») y espera una sola
  respuesta. En los repetidos, «Quitar repetido» va primero y se dice con
  qué movimiento choca.
- Después de leer un extracto, un resumen como «4 nuevos, 2 ya estaban, 1
  necesita revisión», con «Importar 4 nuevos»; y en cada «Ya registrado»,
  con qué movimiento coincide.
- Proponer los pagos fijos a partir del historial, empezando por arriendo,
  servicios y créditos, y reconocer el pago de un cliente o de un amigo
  cuando llega, para marcarlo como cobrado.

Sabremos que funcionó cuando en los flujos de Por revisar, confirmar una
captura clara o una transferencia propia tome un toque, registrar la
quincena un toque y corregir una cuenta desconocida dos, como pide el
experto.

### 31. Empezar sin aprender Quincena

**Estado:** Hecha. Configurar son tres preguntas, cómo te llamas, cuándo
te pagan y dónde tienes tu plata, y llevan a Inicio con la cifra: 7
toques, 6 sin el monto. Bajo la cifra, «Termina de preparar Quincena»
lista lo que falta y se va al completarse. Sin cuentas, Inicio y
«Movimiento» llevan a agregar la primera. El formulario empieza por lo que
pasó, «Gasté plata», «Me entró plata» o «Moví plata entre mis cuentas», y
un gasto normal toma 4 toques: la cuenta y la categoría salen del comercio
o de la última vez.

Tamaño: mediana. Configurar exige poco, un nombre y una cuenta, pero
muestra en el camino todo lo opcional cuando la persona aún no ha visto
para qué sirve la app. Quien se queda sin cuentas ve $0 y secciones
vacías, y «+ Movimiento» le responde «Primero agrega una cuenta.» como un
error. Y un gasto normal pasa por tipo, monto, cuenta, categoría,
comercio, fecha y nota.

- Configurar en tres preguntas, cómo te llamas, cuándo te pagan y dónde
  tienes tu plata, y llegar a Inicio con la cifra.
- En Inicio, «Termina de preparar Quincena» con lo que falta, como los
  pagos fijos o el colchón, que se va cuando está completo.
- Sin cuentas, Inicio lleva a agregar la primera, y «+ Movimiento» la
  ofrece en vez de mostrar un error.
- Un gasto normal en tres pasos: monto, dónde y guardar. La categoría y la
  cuenta vienen del comercio o de la última vez, y la fecha es hoy.
- Empezar el formulario por lo que pasó: «Gasté plata», «Me entró plata» o
  «Moví plata entre mis cuentas».

Sabremos que funcionó cuando una persona nueva llegue a su cifra en Inicio
con menos de 10 toques, y anotar un gasto normal tome 3 o 4, medidos en
los flujos.

### 32. Encontrar lo registrado

**Estado:** Hecha en parte. Movimientos busca por monto y filtra por
cuenta, categoría, tipo, fechas y monto, con el total de lo encontrado y
el de cada día. «Programado», «Tu parte» y lo que llegó en otra moneda van
en etiquetas enteras; los posibles repetidos se marcan y se quitan desde
la lista, con «Deshacer»; y el formulario dice de dónde vino cada
movimiento. Falta lo de los viajes: contar por defecto solo lo cobrado en
la moneda del viaje.

Tamaño: mediana. Movimientos tiene un solo campo de búsqueda, sin filtros
por cuenta, categoría, tipo, fechas ni monto, y buscar «187400» no
encuentra el gasto de $187.400. Las filas cortan justo lo que importa,
como «Programado» o «Tu parte».

- Filtros por cuenta, categoría, tipo y fechas, búsqueda por monto, un
  botón para borrar la búsqueda y el total de lo encontrado.
- Filas que muestran «Programado», «Tu parte $X» y, en una transferencia
  entre monedas, lo que llegó.
- Marcar los posibles repetidos en la lista y dejar unirlos ahí mismo.
- Decir de dónde vino cada movimiento: a mano, de una notificación o de un
  extracto.
- En los viajes, contar por defecto lo cobrado en la moneda del viaje y
  preguntar el resto en bloque.

Sabremos que funcionó cuando cualquier movimiento se encuentre con dos
acciones, y los flujos de Movimientos lo comprueben.

### 33. Plan, Ajustes y respaldos en orden

**Estado:** Hecha en parte. Plan se ordena por intención y Ajustes por
secciones. «Restaurar un respaldo» dice qué trae y ofrece guardar lo de
ahora; borrar todo recuerda el código. Los códigos se comparten y se
pegan, hay CSV de los movimientos, un cambio en dos teléfonos se ve lado a
lado y se combina, y los errores dicen qué falta. Falta el QR y unir los
cambios campo por campo sin preguntar.

Tamaño: mediana. Plan junta doce bloques en cinco grupos, uno sin título;
Ajustes mezcla perfil, avisos, widget, captura, apariencia y datos, y
«Importar un archivo» reemplaza todo sin decir qué trae. Unir otro
teléfono pide pegar o escribir un código de 54 caracteres, y un choque
entre dos dispositivos se resuelve sin ver las dos versiones.

- Plan por intención: «Organizar mi plata» (reparto, ingresos variables,
  pagos fijos), «Lo que quiero lograr» (metas, viajes, lo quiero pero
  después), «Lo que estoy pagando» (compras a cuotas, gastos compartidos,
  préstamos) y «Herramientas» (próximos 30 días, ¿Y si…?, colchón en días,
  cargos para revisar).
- Ajustes en secciones: tu perfil, automatización, cuentas conectadas,
  apariencia con «Tema» e «Idioma» por título, tus datos, ayuda y
  privacidad, y al final borrar todo.
- «Restaurar un respaldo» en vez de «Importar un archivo»: antes de
  reemplazar dice qué trae y ofrece guardar lo de ahora. Al borrar todo,
  recordar el código del respaldo.
- Unir otro teléfono con un QR o con la hoja de compartir; escribir el
  código queda de último recurso. Y exportar los movimientos en CSV.
- Un cambio hecho en dos dispositivos se une campo por campo; si chocan,
  se ven las dos versiones lado a lado y se ofrece combinarlas.
- Nombres que dicen lo que hacen, como «Fondo de emergencia en días»;
  errores que dicen qué falta y se van al corregir, como las dos llaves de
  Binance; y ningún «Guardar» se cierra sin guardar y sin decir por qué.
  En la conversación del ejemplo, quitar el engranaje que repite idioma y
  apariencia.

Sabremos que funcionó cuando los expertos marquen «Se entiende» en al
menos 8 de cada 10 flujos de Plan y Ajustes.

### 34. Pregúntale a tu plata sin castigo

**Estado:** Hecha. Solo preguntar gasta del día: guardar, confirmar o
corregir no. La conversación sigue ahí al volver, dice antes cuántas
preguntas quedan y en cero se apaga con calma. El gasto dice de qué cuenta
sale y deja cambiarla, una pregunta sin respuesta trae «Volver a
preguntar», y una respuesta corregida dice que sus cifras son de antes.
Falta reintentar solo cuando vuelve la red.

Tamaño: pequeña. Con tus cuentas, cada acción sobre una respuesta gasta
otra pregunta, y con la última el formulario llega pero no se puede
guardar. Salir de la conversación la pierde aunque las preguntas ya se
gastaron, lo que se acaba se descubre por un aviso en rojo, y un gasto
anotado así queda en la primera cuenta sin decirlo.

- Guardar, confirmar o cambiar algo en una respuesta no gasta preguntas;
  solo preguntar.
- La conversación sigue ahí al volver, por lo menos hasta cerrar la app.
- Decir desde antes cuántas preguntas quedan hoy y, si no quedan, apagar
  las sugerencias con un estado, no con un error.
- Antes de guardar un gasto, decir en qué cuenta queda y dejar cambiarla.
- Un botón «Volver a preguntar».

Sabremos que funcionó cuando los flujos de la conversación comprueben que
solo preguntar descuenta y que nada se pierde al ir y volver.

### 35. Todo se puede deshacer

**Estado:** En curso.

Tamaño: pequeña. Borrar una regla, descartar una captura, «No es del
viaje», borrar un deseo o un cobro pasan con un toque y sin vuelta atrás,
y borrar un movimiento pregunta pero después no se puede deshacer.
«Deshacer» solo existe al registrar en Por revisar y en la conversación.
La persona no sabe qué esperar.

- El mismo aviso con «Deshacer» durante unos segundos para todo lo que
  borra, descarta o archiva, como el que ya tiene «Registrar».
- Confirmar antes de lo que tiene mucho efecto, como dejar de leer una
  app.
- Un lugar para ver y recuperar lo archivado y lo descartado.
- Cambiar el idioma o empezar de nuevo no borra la conversación sin
  avisar.

Sabremos que funcionó cuando ninguna acción que quita datos quede sin
«Deshacer» o sin confirmación, y un flujo lo compruebe en cada pantalla.

### 36. Que se sienta liviana

**Estado:** Pendiente.

Tamaño: mediana. El verde hace de marca, de botón, de selección, de
ingreso y de éxito a la vez; casi todo va en tarjetas con borde, y algunas
pantallas piden desplazarse para una acción sencilla. Los formularios
grandes, como una compra a cuotas o una meta, viven en hojas pequeñas.

- Colores con un solo sentido: verde fuerte para la acción principal y lo
  positivo, verde claro para lo seleccionado, ámbar para lo que pide
  atención, rojo para el riesgo y la deuda vencida, y neutro para lo
  secundario.
- Tarjetas solo para decisiones, resúmenes, alertas e ideas; las listas y
  los ajustes van sin caja.
- Entre 15 y 20 % menos de espacio vertical en Por revisar, Plan, Ajustes,
  Cuentas y Movimientos.
- Hojas para decisiones rápidas y páginas completas para crear o editar
  algo grande.
- Vibración suave al confirmar, números que se animan al cambiar,
  esqueletos mientras carga y el resultado en pantalla sin esperar a que
  termine de guardar.
- Revisar con VoiceOver y TalkBack los flujos de «Empieza aquí».

Sabremos que funcionó cuando cada pantalla de «Empieza aquí» tenga una
sola acción principal, y los expertos la califiquen al menos igual que
hoy.

### 37. Prueba en teléfonos de verdad, también pequeños

**Estado:** Hecha en parte. Los flujos se desplazan hasta lo que van a
tocar, incluso lo que una lista aún no dibuja, y lo dejan en el centro de
la pantalla: con eso, los cuatro flujos que se detenían en un iPhone SE
llegan al final. Un flujo roto dice en qué línea se detuvo. Falta la
sesión con un iPhone y un Android de verdad.

Tamaño: pequeña. Los flujos corren en un simulador. Hay cosas que solo se
prueban en un teléfono: avisos del banco con la app cerrada, el widget,
compartir un comprobante, los permisos de Android y sincronizar entre dos
dispositivos. Y los flujos se escribieron para un iPhone grande: en uno
pequeño, algunos no llegan al final.

- Una sesión con un iPhone y un Android, siguiendo en cada flujo la lista
  «Lo que hay que probar en un teléfono de verdad».
- Que los flujos se desplacen hasta cada fila o botón antes de tocarlo,
  para jugarlos también en un iPhone SE: hoy 4 se detienen porque lo que
  buscan queda fuera de la pantalla.
- En un teléfono pequeño, abrir los cuadros que piden un monto o un código
  mientras el teclado sube y baja. Sin simulador ya caben y se desplazan,
  pero el movimiento del teclado solo se ve en uno de verdad.
- Lo que falle y se pueda automatizar se vuelve un flujo nuevo.

Sabremos que funcionó cuando la lista de pruebas a mano quede revisada en
los dos teléfonos antes de publicar la 1.2, y los 181 flujos terminen
también en un iPhone SE.

## Lo que hay que probar en un teléfono de verdad

Cada flujo trae su lista de lo que el simulador no puede probar: 73 puntos
en total, como avisos del banco con la app cerrada, el widget, compartir
un comprobante, los permisos de Android y sincronizar entre dos
dispositivos. Están en la página, flujo por flujo, en «Lo que hay que
probar en un teléfono de verdad».

## Notas de la corrida

Actualización del 9 de octubre por la noche: los 188 flujos se volvieron a
jugar en el simulador con la versión que trae las fases 27 a 29 y 32 a 34,
y los que cambiaron después, otra vez con la última versión. Los flujos
ahora se desplazan hasta lo que van a tocar y lo dejan en el centro de la
pantalla; con eso, los cuatro que se detenían en un iPhone SE llegan al
final. En el simulador, «Conectar Binance» (05-07) se detiene al escribir
la API Key, después de comprobar que sin llaves dice qué falta; sin
simulador, en un iPhone 17 Pro y en un SE, el flujo llega al final. Los
flujos de primeros pasos y del formulario de movimientos que cambió la
fase 31 todavía muestran la versión anterior: se vuelven a jugar en la
próxima actualización, con las fases 30 y 35.

En el simulador, escribir y pegar fallaba de formas que sin simulador no
se ven: a veces el texto no llegaba al campo, la tecla de enviar se
perdía, iOS pedía permiso para pegar lo que hubiera en el portapapeles del
Mac y el llavero del simulador le pasaba al flujo siguiente las llaves de
sincronizar y de los respaldos. Ahora las pruebas escriben y oprimen
teclas sobre el campo mismo, cada flujo que pega trae su propio mensaje y
cada flujo tiene su propio llavero.

La pantalla útil del iPhone es 96 puntos más baja que la de las pruebas
sin simulador, por la barra de estado y la del inicio. Por eso 18 flujos
necesitaron una foto más para mostrar lo que queda abajo: 1.187 pasos en
vez de 1.168. Por lo mismo, dos comprobaciones no se cumplen en el
simulador y sí sin él: la fila del 5 de octubre en «Ver los próximos días»
y la explicación del pago en «Importar la tarjeta» quedan fuera de la
pantalla, y la comprobación solo lee lo que está dibujado.

En «Planear la meta del viaje a Cartagena», Flutter avisó en el simulador
que la pantalla de atrás y el cuadro del monto se desbordaban mientras
salía el teclado. Para ver qué pasa con el teclado arriba,
`test_screens/flows_keyboard_test.dart` juega los 181 flujos sin simulador
con las zonas seguras de un iPhone y su teclado abierto mientras un campo
tiene el foco. En un iPhone 17 Pro, con un teclado de 336 puntos, nada se
desborda.

En un iPhone SE, con un teclado de 260 puntos, siete flujos abrían un
cuadro que no cabía y no se podía desplazar. Eran cuatro cuadros: el de la
tasa, que también recibe el precio del bitcoin; el del pago de una compra
a cuotas; el que cambia un dato en Ajustes, y el que pide el código para
unir otro teléfono o abrir un respaldo, que se pasaba aun sin teclado. Los
diez cuadros que piden un dato ahora se desplazan cuando no caben. Con
eso, los 181 flujos se juegan en los dos teléfonos sin que nada se
desborde.

En el SE, cuatro flujos se detienen antes del final porque la prueba busca
una fila o un botón que esa pantalla no alcanzó a dibujar, sin desplazarse
hasta él, y nueve tienen una comprobación que lee lo que quedó fuera de la
pantalla. No son errores de la app: que los flujos se desplacen antes de
tocar está en la fase 33.
