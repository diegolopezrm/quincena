# Revisión flujo por flujo, 9 de octubre de 2026

Cada cosa que una persona puede hacer en Quincena se jugó en un iPhone 17
Pro simulado, primero con la versión 1.1.0 (build 20) y el 10 de octubre
otra vez, con la que trae las fases 27 a 36: 196 flujos, 1.309 pasos con
su foto y 1.442 comprobaciones sobre los datos, de las que se cumplen
1.442. Cada flujo quedó en una sola imagen, con su objetivo, cada paso y
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

Actualizado el 10 de octubre, después de la revisión del experto: con las
fases 27 a 36 y otros arreglos se resolvieron 189, y se dejó así a
propósito una. Cada una dice qué hace ahora y en qué fase cambió; para
verlas, marca «Mostrar también lo que ya se resolvió». Las fotos de los
flujos son las de esta versión.

- 219 observaciones revisadas contra el código de hoy.
- 1 siguen, del todo o en parte.
- 218 ya resueltas o que ya no aplican.
- 21 nuevas, encontradas en esa revisión.
- 0 pendientes de importancia alta.

Lo que sigue pendiente, por parte de la app, de mayor a menor importancia.
Entre paréntesis, los flujos donde se ve.

### Cuentas y Cripto

- **Baja.** *Cuentas (resumen arriba).* «Lo que debes en tarjetas» va con
  signo menos (−$844.800) mientras la fila de la tarjeta dice «Debes
  $844.800» en positivo. Hoy: Se dejó así a propósito: en la suma de lo
  que puedes gastar, lo que debes resta y el signo lo dice; la fila de la
  tarjeta dice «Debes» sin signo. Propuesta: Usar la misma forma en los
  dos lugares: «Debes en tarjetas $844.800», sin signo.

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

**Estado:** Hecha. Lo aprendido se dice regla por regla, con «También
quedaron listos otros N movimientos», y la regla de un banco no toma
tarjetas ni bancos que no conoce. Las transferencias propias se reconocen
en un toque, y el segundo aviso de la misma se une solo. «Registrar el
pago del 30» abre lleno. Cada tarjeta de Por revisar dice qué le falta, y
en los repetidos «Quitar repetido» va primero y dice con qué choca. El
extracto se resume antes de entrar («4 nuevos · 2 ya estaban · 1 necesita
revisión»), y los pagos fijos y los cobros de clientes y amigos se
reconocen al llegar.

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

**Estado:** Hecha. Movimientos busca por monto y filtra por cuenta,
categoría, tipo, fechas y monto, con el total de lo encontrado y el de
cada día. «Programado», «Tu parte» y lo que llegó en otra moneda van en
etiquetas enteras; los posibles repetidos se marcan y se quitan desde la
lista, y el formulario dice de dónde vino cada movimiento y a qué hora. Un
viaje en otra moneda cuenta solo lo pagado en ella o afuera, pregunta por
el resto de una vez, e «Incluir un gasto de antes» trae buscador y pone
primero lo más probable.

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

**Estado:** Hecha. Plan se ordena por intención y Ajustes por secciones.
«Restaurar un respaldo» dice qué trae y ofrece guardar lo de ahora; el
primer respaldo pide dónde guardar antes de mostrar su código. El código
para unir otro teléfono se muestra como QR y el otro lo escanea con la
cámara; también se comparte y se pega. Hay CSV de los movimientos. Dos
cambios distintos del mismo movimiento hechos en dos teléfonos se unen
solos, y solo un choque se ve lado a lado, con «Combinar». Las licencias
van en español.

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
Sin red, la pregunta se repite sola cuando vuelve la conexión.

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

**Estado:** Hecha. Todo lo que borra, descarta o archiva ofrece «Deshacer»
unos segundos, con el mismo aviso. Dejar de leer una app pregunta antes.
«Archivado y descartado», en Ajustes y al final de Por revisar, deja ver y
traer de vuelta lo archivado y lo descartado. Cambiar el idioma o empezar
una conversación nueva no la borra sin avisar.

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

**Estado:** Hecha. Cada color dice una sola cosa: verde fuerte para la
acción principal y la plata que entra, verde claro para lo seleccionado,
ámbar para lo que pide atención y rojo para el riesgo; en cada pantalla
hay un solo botón verde fuerte. Las listas y los ajustes van sobre el
fondo, con una línea entre filas, y las tarjetas quedan para lo que pide
algo. Movimientos, Cuentas, Plan y Ajustes bajaron entre 15 y 20 % de alto
en un iPhone 17 Pro; Por revisar, 10 %, porque sus botones guardan los 48
puntos que pide la accesibilidad. La meta, el viaje, el pago fijo y la
compra a cuotas se abren en página completa. Guardar vibra suave, lo
guardado se ve de una vez, el patrimonio cuenta hasta la cifra nueva y lo
que carga muestra su forma. Los 22 flujos de «Empieza aquí» se leen bien
con VoiceOver y TalkBack.

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

Cada flujo trae su lista de lo que el simulador no puede probar: 80 puntos
en total, como avisos del banco con la app cerrada, el widget, compartir
un comprobante, los permisos de Android y sincronizar entre dos
dispositivos. Están en la página, flujo por flujo, en «Lo que hay que
probar en un teléfono de verdad».

## Notas de la corrida

Actualización del 10 de octubre: los 196 flujos se volvieron a jugar en el
simulador de iOS con la versión que trae las fases 27 a 36, así que las
fotos de cada paso son de esa versión. Pasan los 196. «Conectar Binance»
(05-07), que se detenía en el simulador al escribir la API Key, ahora
llega al final: al abrirse el teclado, la página corría el campo fuera de
la pantalla y la prueba dejaba de verlo, aunque seguía ahí; ahora sigue
escribiendo en el campo que ya tenía. En «Cambiar la llave de Binance»
(05-16), el simulador tiene internet y Binance rechaza la llave de prueba,
mientras que sin simulador la lectura falla sin causa: el flujo cuenta el
caso que le toque.

En el simulador, escribir y pegar fallaba de formas que sin simulador no
se ven: a veces el texto no llegaba al campo, la tecla de enviar se
perdía, iOS pedía permiso para pegar lo que hubiera en el portapapeles del
Mac y el llavero del simulador le pasaba al flujo siguiente las llaves de
sincronizar y de los respaldos. Las pruebas escriben y oprimen teclas
sobre el campo mismo, cada flujo que pega trae su propio mensaje y cada
flujo tiene su propio llavero.

La pantalla útil del iPhone es 96 puntos más baja que la de las pruebas
sin simulador, por la barra de estado y la del inicio. Por eso algunos
flujos necesitan una foto más para mostrar lo que queda abajo.

El aviso con «Deshacer» dura unos segundos en toda la app, como pidió la
fase 35; con un lector de pantalla se queda hasta que se use. En
«Registrar un ingreso de un toque y deshacerlo» (07-02) el flujo deshace
mientras el aviso sigue, como lo haría una persona.

Para ver qué pasa con el teclado arriba,
`test_screens/flows_keyboard_test.dart` juega los flujos sin simulador con
las zonas seguras de un iPhone y su teclado abierto mientras un campo
tiene el foco. En un iPhone SE, con un teclado de 260 puntos, los 196
llegan al final sin que nada se desborde: los flujos se desplazan hasta lo
que van a tocar y lo dejan en el centro de la pantalla.

Los 22 flujos de «Empieza aquí» también se revisan como los lee un lector
de pantalla (`test_screens/semantics_check_test.dart`): cada control tiene
nombre y cada tarjeta se lee entera, sin hallazgos.

Lo que solo se ve en un teléfono de verdad (la cámara al escanear el QR,
el permiso de la ubicación, las notificaciones reales del banco, el
movimiento del teclado) está en cada flujo, en «Lo que hay que probar en
un teléfono de verdad».
