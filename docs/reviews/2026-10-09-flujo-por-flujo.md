# Revisión flujo por flujo, 9 de octubre de 2026

Cada cosa que una persona puede hacer en Quincena se jugó en un iPhone 17
Pro simulado, con la versión 1.1.0 (build 20): 181 flujos, 1.187 pasos con
su foto y 1.210 comprobaciones sobre los datos, de las que se cumplen
1.208. Cada flujo quedó en una sola imagen, con su objetivo, cada paso y
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
(build 20): 169 siguen, del todo o en parte, y 50 ya se resolvieron o ya
no aplican. En esa revisión salieron 21 más.

Esta lista es lo que ya sabemos. Lo que más nos sirve de ti es lo que no
está aquí, y saber si estas propuestas van en la dirección correcta.

- 219 observaciones revisadas contra el código de hoy.
- 169 siguen, del todo o en parte.
- 50 ya resueltas o que ya no aplican.
- 21 nuevas, encontradas en esa revisión.
- 9 pendientes de importancia alta.

Lo que sigue pendiente, por parte de la app, de mayor a menor importancia.
Entre paréntesis, los flujos donde se ve.

### Primeros pasos, Ajustes y respaldos

- **Media.** *Ajustes › Apariencia.* Son dos filas de botones sin título;
  las dos empiezan con «Sistema», así que no se sabe cuál es el idioma.
  Propuesta: Poner «Tema» e «Idioma» encima de cada fila, como ya hace la
  hoja de ajustes de la conversación.
- **Media.** *Ajustes › Avisarme el día de pago.* Sin permiso de
  notificaciones, el aviso dice que hay que ir a los ajustes del teléfono
  pero no da un botón (el de la ubicación sí tiene «Abrir ajustes»).
  Propuesta: Agregar «Abrir ajustes» a ese aviso. En Android sirve lo que
  ya abre los ajustes para la ubicación; en iPhone falta abrir la página
  de Quincena en Ajustes.
- **Media.** *Inicio con moneda USD.* Los montos en dólares se escriben
  con «$» igual que los pesos ($89,96, Te llegó la quincena: $600,00).
  Propuesta: Cuando la app está en español y la moneda de los totales no
  es el peso, escribir los dólares como «US$» también en los totales.
- **Media.** *Configuración paso 4 › Agregar pago fijo.* Un pago fijo
  escrito a mano llega en la categoría Suscripciones, con preguntas de
  prueba gratis y uso; un gimnasio o un crédito quedan como suscripción
  sin que la persona lo note. Propuesta: Dejar la categoría sin elegir y
  pedirla antes de guardar, o adivinarla por el nombre (arriendo,
  gimnasio, crédito), y mostrar las preguntas de suscripción solo si se
  elige esa categoría.
- **Media.** *Configuración paso 2.* Si el día de pago fue hace pocos
  días, la app ahora asume que el pago ya está en los saldos; si no ha
  llegado, nadie se lo pregunta. Propuesta: En el paso 2, si hubo un día
  de pago en los últimos 10 días, preguntar «¿Ya te llegó el pago del 30
  de septiembre?» y, si no, tratarlo como pago atrasado.
- **Media.** *Reglas aprendidas.* «Borrar regla» la quita al instante, sin
  preguntar ni ofrecer deshacer; los comercios salen sin tilde («Exito
  Laureles»). Propuesta: Al borrar, mostrar abajo «Regla borrada» con
  «Deshacer», y guardar con la regla el nombre del comercio como llegó la
  última vez para mostrarlo con sus tildes.
- **Media.** *Varios dispositivos › Abrir un archivo.* «Listo: 19
  cambios.» no dice qué llegó. Propuesta: Resumir por tipo: «Llegaron 7
  cuentas y 10 movimientos».
- **Media.** *Varios dispositivos › Para revisar.* Cada cambio que espera
  muestra solo la versión que perdió (Crepes con Laura · −$23.500); no se
  ve qué quedó ni en qué se diferencian. Propuesta: Mostrar lado a lado lo
  que quedó y lo que espera, con el campo distinto resaltado, por ejemplo
  «Nombre: Crepes & Waffles / Crepes con Laura».
- **Media.** *Varios dispositivos y Exportar.* Hay dos códigos distintos
  de 54 caracteres (el de sincronizar y el de respaldo) que se escriben a
  mano; el aviso de código equivocado tiene que explicar que «el de
  respaldo es otro». Propuesta: Ofrecer un QR para unir el otro
  dispositivo y el botón de compartir para guardar el código, y pensar si
  un solo código puede servir para las dos cosas.
- **Media.** *Importar un archivo.* «¿Reemplazar todo con este archivo?»
  no dice qué trae el archivo (fecha, cuentas, movimientos) ni ofrece
  guardar antes lo de ahora. Propuesta: Mostrar lo que trae el archivo,
  que ya está leído en ese momento («Respaldo del 3 oct: 7 cuentas, 10
  movimientos»), y un botón «Exportar lo de ahora primero».
- **Media.** *Ajustes > Tus datos.* En «Tus datos» siguen «Importar
  extracto» e «Importar un archivo»; el segundo no tiene subtítulo y
  reemplaza todo. Propuesta: Llamarlo «Restaurar un respaldo», con el
  subtítulo «Reemplaza todo lo de ahora», y ponerlo junto a «Exportar mis
  datos» bajo un título «Respaldo».
- **Media.** *Exportar mis datos > Sin cifrar (JSON).* «Exportar mis
  datos» ofrece solo cifrado o JSON; el JSON dice que sirve para otra
  herramienta, pero una hoja de cálculo no lo abre bien. Propuesta:
  Agregar una tercera opción «Movimientos en CSV», con fecha, cuenta,
  comercio, categoría, monto y moneda.
- **Media.** *Ajustes > Borrar todo.* «Borrar todo» también borra del
  teléfono el código de respaldo y el diálogo no lo dice; después ya no se
  puede ver con «Ver mi código de respaldo». Propuesta: Si hay código de
  respaldo, agregar al diálogo «Si tienes respaldos cifrados, guarda antes
  tu código de respaldo», con un botón «Ver mi código».
- **Media.** *Varios dispositivos > Para revisar.* Si en un dispositivo se
  cambia el nombre de un movimiento y en otro se le agrega una nota, queda
  una sola versión y la otra espera en «Para revisar»; al elegir, una de
  las dos ediciones se pierde. Propuesta: Como paso corto, que «Para
  revisar» muestre qué campos difieren y que «Traer de vuelta» deje elegir
  cuáles traer; después, mezclar campo por campo como describe
  docs/SYNC.md.
- **Media.** Un nombre cambiado en el teléfono y una nota agregada en el
  computador al mismo movimiento chocan; tras «Traer de vuelta» y
  «Descartar», la nota del computador se pierde. Propuesta: Como paso
  corto, mostrar en «Para revisar» qué campos difieren y dejar traer solo
  los elegidos; después, mezclar campo por campo como describe
  docs/SYNC.md. (Archivos que no sirven y cambios que quedaron esperando)
- **Media.** *Ajustes › Moneda de los totales.* Sin conexión y sin una
  tasa guardada entre las dos monedas, el pago y el colchón conservan el
  número y cambian de moneda: 2.400.000 pesos pasan a ser 2.400.000
  dólares, sin aviso (own_settings_page.dart:145-156; rateBetween devuelve
  null en own_controller.dart:886-897). (Nuevo.) Propuesta: Si no hay
  tasa, avisarlo y no cambiar la moneda, o pedir de nuevo el pago y el
  colchón en la moneda nueva.
- **Baja.** *Ajustes › Captura automática.* Bajo el título «Captura
  automática» están también «Billeteras propias» y «Binance», que no
  capturan pagos. Propuesta: Pasar «Billeteras propias» y «Binance» a una
  sección propia, por ejemplo «Cuentas conectadas», o a la pestaña
  Cuentas.
- **Baja.** *Configuración paso 1.* El error del nombre vacío repite la
  pista «Tu nombre» en rojo, sin decir qué falta. Propuesta: Decir
  «Escribe tu nombre para seguir».
- **Baja.** *Ajustes › Borrar todo.* El diálogo aconseja exportar primero,
  pero hay que cancelar y buscar «Exportar mis datos». Propuesta: Agregar
  «Exportar primero» en el mismo diálogo, que abra la hoja de exportar y
  después vuelva a preguntar.
- **Baja.** *Licencias › OpenStreetMap.* La licencia de OpenStreetMap solo
  está en inglés, en una app en español. Propuesta: Agregar el párrafo en
  español antes del inglés en la entrada de OpenStreetMap; los enlaces y
  el nombre de la licencia pueden quedar igual.
- **Baja.** *Configuración paso 2 › calendario.* El calendario muestra
  «Cancelar» y «ACEPTAR» con mayúsculas distintas (textos de Flutter).
  Propuesta: Dar a todos los calendarios sus propios botones, «Cancelar» y
  «Aceptar», desde una función común.
- **Baja.** *Configuración paso 3.* El aviso «Agrega al menos una cuenta
  para empezar» tapa el botón «Siguiente». Propuesta: Mostrar la frase en
  la pantalla, bajo las sugerencias o justo encima de los botones, en vez
  de un aviso que tapa «Siguiente».
- **Baja.** *Ajustes > Moneda de los totales.* Al cambiar la moneda de los
  totales, «Lo que te pagan» y «Colchón» se convierten con la tasa del
  día, pero nada en la pantalla lo dice. Propuesta: Agregar bajo la lista:
  «Lo que te pagan y el colchón pasan a la nueva moneda con la tasa del
  día.».
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
- **Baja.** *Primera pantalla en ingles.* En inglés, la primera pantalla
  sigue diciendo «in pesos, dollars or crypto»; el ejemplo sigue
  presentando a Valentina en Medellín, ahora aclarando que es inventada.
  Propuesta: En inglés decir «in your currency, dollars or crypto»; lo de
  Medellín puede quedarse porque describe el ejemplo.
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
- **Baja.** *Ajustes › Nombre.* Guardar el nombre en blanco cierra el
  cuadro sin guardar y sin decir por qué; el cuadro de montos ya explica
  su error (own_settings_page.dart:67-78, el diálogo del nombre no tiene
  comprobación). (Nuevo.) Propuesta: Dejar el cuadro abierto con «Escribe
  tu nombre», como hacen los montos.
- **Baja.** *Configuracion paso 1 y formulario de cuenta.* En el
  formulario de cuenta el error se va al escribir; en el paso 1 de la
  configuración, «Tu nombre» en rojo sigue aunque el nombre ya esté
  escrito, hasta tocar «Siguiente» otra vez. Hoy: En el formulario de
  cuenta el error se va al escribir; en el paso 1 de la configuración, «Tu
  nombre» en rojo sigue aunque el nombre ya esté escrito, hasta tocar
  «Siguiente» otra vez. Propuesta: En el paso 1, quitar el error del
  nombre apenas se escriba algo, como ya hacen el formulario de cuenta y
  el cuadro de montos de Ajustes.
- **Baja.** *Hoja de Ajustes del ejemplo > Tu key.* En el teléfono ese
  campo ya no existe. En la demo web, «Conectar» con la key vacía sigue
  sin hacer ni decir nada. Hoy: En el teléfono ese campo ya no existe. En
  la demo web, «Conectar» con la key vacía sigue sin hacer ni decir nada.
  Propuesta: En la demo web, desactivar «Conectar» hasta que haya texto, o
  decir «Pega tu key» bajo el campo.

### Inicio y Movimientos

- **Alta.** *Inicio sin cuentas (Por hacer, Tus cuentas, Movimientos
  vacío).* Sin cuentas, «Por hacer» solo pide pagos fijos y no pide la
  primera cuenta. «Tus cuentas» queda como un título vacío, sin botón.
  «Últimos movimientos» dice que se registra con «Movimiento», pero ese
  botón solo responde «Primero agrega una cuenta.», en un aviso sin
  acción. Propuesta: Poner primero la tarea «Agrega tu primera cuenta» con
  su botón, un «Agregar cuenta» dentro de «Tus cuentas» vacío y la acción
  «Agregar» en el aviso.
- **Alta.** *Inicio > «Registra tu pago del 30 de septiembre» >
  «Registrar».* El formulario abre en «Ingreso», pero vacío, aunque la app
  ya sabe el monto (el pago del perfil), la categoría (Salario) y la fecha
  (el día de pago que pasó). Hay que llenar tres cosas y retroceder el
  calendario un mes. Propuesta: Abrirlo con el pago del perfil, Salario y
  la fecha del día de pago que pasó, para confirmar con un toque.
- **Alta.** *Formulario de movimiento (pago de la tarjeta).* El error
  natural es anotar «Pago Visa» como gasto, o en «Créditos». Eso cuenta
  dos veces la misma plata, y nada en el formulario lo advierte.
  Propuesta: Si el nombre dice tarjeta, Visa o el nombre de una tarjeta, o
  se elige «Créditos» desde una cuenta de banco, proponer «Transferencia
  hacia Visa» con un toque.
- **Media.** *«¿De dónde sale?» y «¿Me alcanza?» (Después del pago).* La
  app muestra «Te llegó la quincena: $2.400.000» por la Nómina del 30,
  pero en otras partes dice «No sabe cuánto te pagan» y «No sé cuánto te
  pagan, así que no lo cuento». Propuesta: Junto a «Te llegó la quincena»,
  preguntar «¿Te pagan $2.400.000 cada quincena?» y guardarlo con un
  toque.
- **Media.** *Movimientos, filas.* Las marcas importantes se cortan por la
  cuenta en la misma línea: «Servicios · Bancolombia · Progra…» y «Mercado
  · Bancolombia · Dividid…». No se lee ni «Programado» ni cuánto es tu
  parte. Propuesta: Mostrar «Programado» y «Tu parte $X» como etiqueta o
  en su propia línea, antes de la cuenta.
- **Media.** *Movimientos, buscador.* Solo se puede buscar con texto: no
  hay filtros por cuenta, categoría, tipo, fechas ni monto. Buscar
  «187400» no encuentra el gasto de $187.400. Propuesta: Buscar también
  por monto (187400 o 187.400) y agregar filtros por cuenta, categoría,
  tipo y fechas.
- **Media.** *Formulario nuevo movimiento.* La cuenta que viene elegida es
  siempre la primera (Bancolombia), no la más usada ni la última. Para
  pagos en efectivo o con Nequi hay que abrir el menú cada vez. Propuesta:
  Elegir de entrada la última cuenta usada, o la más usada en los últimos
  días.
- **Media.** *Editar movimiento, «Eliminar».* Al confirmar, el movimiento
  se borra sin forma de deshacerlo, aunque la cifra de Inicio cambie.
  Propuesta: Después de borrar, mostrar unos segundos un aviso con
  «Deshacer».
- **Media.** *Editar movimiento, «Cuenta».* Al pasar un gasto de una
  cuenta en pesos a una en dólares, el número se queda igual y solo cambia
  la moneda: 15.600 COP pasan a ser 15.600 USD, sin aviso. Propuesta: Al
  cambiar de moneda, convertir el monto con la tasa o avisar «Cambiaste de
  COP a USD: revisa el monto».
- **Media.** *Movimientos, transferencia entre monedas.* La fila
  «Bancolombia → Cuenta en dólares» muestra solo lo que salió ($331.284),
  no lo que llegó (US$98,50), y el título se corta. Propuesta: Agregar
  debajo «Llegaron US$98,50» y dejar que el título use dos líneas o acorte
  el nombre de la cuenta.
- **Media.** *Inicio, «Tus cuentas».* La cuenta en dólares, Binance y
  Bitcoin aparecen en la misma lista que Bancolombia y Nequi, sin decir
  que no cuentan en «Puedes gastar». Propuesta: En Inicio, separar «De uso
  diario» de «Ahorro e inversión» como en Cuentas, o marcar las que no
  cuentan.
- **Media.** *Movimientos.* «Éxito Laureles» y «EXITO LAURELES», por
  $63.200 a la misma hora, salen como dos gastos, sin aviso de que pueden
  ser uno repetido. Propuesta: Marcar los posibles repetidos con
  «¿Repetido?» y dejar unirlos o borrar uno ahí mismo.
- **Media.** *Pagos fijos (desde «Por hacer»).* Propone Rappi como pago
  fijo, pero no el Arriendo de $1.200.000. «No tengo pagos fijos» se
  acepta con un toque aunque haya un arriendo en el historial, y la cifra
  deja de ser provisional. Propuesta: Proponer también los gastos de
  Arriendo, Servicios y Créditos aunque haya uno solo, y antes de aceptar
  «No tengo pagos fijos» preguntar por ese arriendo.
- **Media.** *Próximos 30 días con algo movido en la simulación.* Con la
  matrícula movida al 16, el encabezado sigue diciendo «El 8 oct te
  quedarías sin plata». Solo la línea punteada muestra la prueba.
  Propuesta: Agregar debajo del aviso «Con lo que pruebas: no te quedas
  sin plata», o el nuevo día sin plata si lo hay.
- **Media.** *Formulario de movimiento, categoría.* Un gasto sin categoría
  se guarda como «Otros» sin decirlo. La app ya aprende comercio →
  categoría en las capturas, pero no lo usa al escribir a mano. Propuesta:
  Proponer la categoría según «¿Dónde o a quién?», como hace Por revisar,
  y decir «Quedará en Otros» si no se elige.
- **Media.** *Editar movimiento, un gasto dividido que pasa a «Ingreso» o
  «Transferencia».* Al cambiar el tipo y guardar, la división se borra sin
  aviso y lo que te deben deja de contar. «Eliminar» sí avisa de eso;
  cambiar el tipo no. (Nuevo.) Propuesta: Antes de guardar, avisar
  «También se quita su división: lo que te deben por este gasto deja de
  contar», como al eliminar.
- **Baja.** *Hoja «¿De dónde sale?» sin cuentas.* El título «Tus cuentas
  de uso diario» queda sin nada debajo. Propuesta: Decir «Aún no tienes
  cuentas de uso diario» con un enlace para agregar una.
- **Baja.** *Cierre de la quincena, «Una acción posible».* Propone llevar
  a una meta los $7.961 que quedan, aunque hay tareas pendientes y la
  cifra está casi en cero. Propuesta: Proponerlo solo cuando lo libre
  supere un mínimo, por ejemplo el 10 % del pago, y no haya tareas
  pendientes en Inicio.
- **Baja.** *Cierre de la quincena, «Qué cambió».* Los pagos mensuales
  hechos en la otra quincena encabezan la comparación («Arriendo $0
  −$1.650.000») y tapan los cambios reales del día a día. Propuesta:
  Marcar los pagos mensuales y compararlos mes contra mes, y dejar la
  comparación por quincena para el gasto del día a día.
- **Baja.** *Inicio, «¿Me alcanza para…?».* «Ver» sin precio abre una
  página vacía en vez de pedir el precio ahí mismo. Propuesta: Sin precio,
  que «Ver» se quede en Inicio y ponga el foco en el campo, o que no se
  pueda tocar.
- **Baja.** *¿Me alcanza? (página).* Arriba a la derecha aparece el ícono
  de «Cierre de la quincena», que nada tiene que ver con probar una
  compra. Propuesta: Mostrar ese ícono solo en «Próximos 30 días», no al
  probar una compra.
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
- **Baja.** *Cierre de la quincena.* Hay dos botones «Ver los próximos 30
  días» iguales en la misma pantalla. «Mira qué cobro podrías mover de
  fecha» lleva a una simulación que no cambia la fecha de verdad.
  Propuesta: Dejar un solo botón y, para los movimientos anotados a
  futuro, ofrecer «Cambiar la fecha» de verdad.
- **Baja.** *Movimientos, buscador.* No hay botón para borrar la búsqueda,
  ni cuenta de resultados, ni total. Tampoco hay total por día en la
  lista. Propuesta: Agregar una «x» en el campo, una línea «2 movimientos
  · −$33.300» al buscar y el total de cada día junto a su fecha.
- **Baja.** *Pregúntale a tu plata, respuesta fallida.* Dice «Prueba de
  nuevo», pero no tiene botón para reintentar: hay que volver a escribir o
  tocar la pregunta. Propuesta: Un botón «Reintentar» en la misma tarjeta
  del error que vuelva a hacer la pregunta.
- **Baja.** *Dividir un gasto.* Juan, desmarcado, queda como miembro del
  grupo nuevo aunque no tuvo parte. «Valor total» sigue diciendo «El del
  movimiento: no se cambia.», que se lee como si nunca pudiera cambiar.
  Propuesta: No crear miembros para los nombres desmarcados y decir «Sigue
  al monto del movimiento».
- **Baja.** *Formulario de movimiento, editar.* No dice de dónde vino el
  movimiento (a mano, notificación, extracto). Eso ayuda a decidir si es
  un repetido. Propuesta: Una línea pequeña bajo el título, como «Llegó
  por notificación de Bancolombia el 2 oct».
- **Baja.** *Cierre de la quincena, «Una acción posible» con meta.* Cuando
  propone que una parte vaya a la meta, no hay botón para hacerlo; las
  otras acciones sí traen el suyo («Ver los pagos», «Ver los próximos 30
  días»). (Nuevo.) Propuesta: Agregar un botón «Llevar a la meta» que abra
  «Reparte tu quincena» o la meta.
- **Baja.** *Tasas > «Escribir una tasa».* «Guardar» con el campo vacío o
  en cero cierra el diálogo sin guardar y sin decir nada. (Nuevo.)
  Propuesta: Desactivar «Guardar» mientras no haya una tasa mayor que
  cero, o avisar «Escribe una tasa».
- **Baja.** *Inicio, «¿Me alcanza para…?» y la página «¿Me alcanza?».* El
  campo del precio siempre muestra «$», aunque la moneda de los totales
  sea euros, libras o reales; el resto de la app usa el símbolo de esa
  moneda. (Nuevo.) Propuesta: Usar en los dos campos el símbolo de la
  moneda de los totales, como ya hace «Dividir un gasto».
- **Alta.** *Inicio: «Próximos días» y «¿Me alcanza?».* Dos cifras se
  contradicen: «Puedes gastar $7.961» y, justo debajo, «Tu saldo mínimo
  estimado será $157.961 el 12 de octubre». En 03-11 aparece «Te faltan
  $112.039» junto a un «saldo mínimo» de $37.961. La diferencia es la
  reserva y los sobres, pero la pantalla no lo explica. Hoy: «¿Me
  alcanza?» ya dice «usarías $X de tu reserva de ingresos variables». En
  Inicio, «Próximos días» sigue dando un saldo mínimo que incluye la
  reserva y los sobres, sin decirlo, junto a un «Puedes gastar» mucho
  menor. Propuesta: En «Próximos días» y «Próximos 30 días», agregar «de
  los cuales $X son tu reserva y tus sobres», o mostrar el mínimo de lo
  libre para gastar. (Anotar un pago que viene)
- **Media.** *Reparte tu quincena (desde «Repartir»).* Propone $150.000
  para la meta cuando hay $7.961 para repartir. Abajo dice «Te pasas por
  −$142.039», con un signo de sobra. Y «Para repartir» no menciona los
  $150.000 de reserva que explican la diferencia. Hoy: La primera
  propuesta no reparte más de lo que hay, la suma nombra la reserva y «Te
  pasas por» va sin signo. Desde la segunda quincena repite el reparto
  anterior tal cual, aunque ahora haya menos. Propuesta: Al repetir el
  reparto anterior, recortarlo a lo que hay para repartir y decir que se
  ajustó.
- **Baja.** *Tasas > «Escribir una tasa» (abierta desde Por hacer).* El
  diálogo no tiene «Cancelar» y el campo no dice la moneda (COP). Hoy: El
  diálogo dice «Cuánto vale 1 EUR en COP» y el campo muestra COP al
  escribir, pero sigue sin «Cancelar»: solo se cierra tocando afuera.
  Propuesta: Agregar «Cancelar» junto a «Guardar».
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

- **Media.** *Editar cuenta de una tarjeta.* Con saldo a favor, «¿Cuánto
  debes hoy?» muestra «-55.200»: una deuda negativa no se entiende.
  Propuesta: Cambiar el campo por un selector «Debes / A favor» con el
  monto siempre en positivo, y guardar según lo elegido; así tampoco se
  pierde el saldo a favor al corregirlo.
- **Media.** *Agregar cuenta.* Al elegir una cripto (ETH, BTC) como
  moneda, «Cuenta de uso diario» sigue encendida aunque su propia ayuda
  dice «Apágalo para … cripto»; hay que apagarla a mano. Propuesta: Apagar
  el interruptor solo al elegir una moneda cripto (también «Otra cripto»),
  salvo que la persona ya lo haya tocado, igual que pasa con Exchange y
  Ahorro.
- **Media.** *Binance (conectar).* «Conectar» con los campos vacíos o con
  solo la API Key no hace nada ni dice qué falta. Propuesta: Dejar
  «Conectar» apagado hasta que estén las dos llaves, o al tocarlo marcar
  en rojo el campo vacío: «Pega la Secret Key».
- **Media.** *Binance (conectar).* El botón para ver la Secret Key es un
  candado que cambia a un chulo, sin tooltip: un lector de pantalla no
  dice qué hace. Propuesta: Usar un ojo y un ojo tachado, con la etiqueta
  «Mostrar» / «Ocultar» para el lector de pantalla.
- **Media.** *Cuentas (resumen arriba).* El «Patrimonio» no cuadra con lo
  que se ve. En 04-21 dice $9.376.827, pero las filas visibles suman unos
  $13,4M: el préstamo, lo que se debe a otros y las cuotas solo aparecen
  dentro de «¿De dónde sale?». Propuesta: Cuando existan, agregar en
  Cuentas, bajo las cuentas, las filas «Te deben», «Les debes a otras
  personas» y «Compras a cuotas», como ya hace el detalle. (Ver lo que me
  deben y las cuotas en el patrimonio)
- **Media.** *Editar cuenta de una tarjeta con saldo a favor.* Al corregir
  «¿Cuánto debes hoy?» en una tarjeta con saldo a favor, el campo borra el
  signo menos y al guardar el saldo a favor queda como deuda: en el
  formulario no hay forma de escribir un saldo a favor. Lo mismo pasa con
  una cuenta en sobregiro, que no acepta un saldo negativo. (Nuevo.)
  Propuesta: Un selector «Debes / A favor» en las tarjetas (y una forma de
  poner saldo negativo en las demás cuentas), y guardar según lo elegido.
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
- **Baja.** *Escribir una tasa (cuadro).* Solo hay «Guardar» (sin
  «Cancelar»), y guardar 0 o vacío no hace nada ni avisa. Propuesta:
  Agregar «Cancelar» y, con 0 o vacío, no cerrar: mostrar «Escribe una
  tasa mayor que cero» bajo el campo.
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

- **Alta.** *Plan › Metas.* La fecha límite se pide pero no se usa. La
  Moto con fecha del 30 de abril dice «llega en julio de 2027» y el viaje
  con fecha del 20 de diciembre dice «llega en enero de 2027», sin ninguna
  advertencia. Propuesta: En la fila y en la hoja de la meta, decir «A
  este ritmo llegas en julio: para el 30 de abril necesitas $X al mes» y
  ofrecer «Usar $X al mes», como ya hace la conversación.
- **Alta.** *Compras a cuotas › Registrar un pago.* Registrar un pago no
  pregunta de qué cuenta salió la plata ni crea el movimiento: «Puedes
  gastar» sube por el pago aunque la plata salió de una cuenta, y solo
  cuadra si la persona también anota el gasto aparte. Propuesta: Preguntar
  «¿De qué cuenta salió?» (como «Le presté») y crear el gasto ligado; si
  no salió de una cuenta de Quincena, decir que hay que anotarlo aparte.
- **Alta.** *¿Y si…?* «Al 17 nov» sigue sumando cada pago sin restar el
  gasto del día a día, así que da cifras muy altas, y «Pago tarde» casi
  nunca mueve el saldo mínimo. Propuesta: Restar lo que suele gastarse por
  día (lo que una quincena suele llevar) o, al menos, decir junto a la
  cifra «sin contar el día a día».
- **Media.** *Gastos compartidos › Registrar pago / Me prestaron.* «Le
  pagaste a Camilo» y «Alguien me prestó plata» no preguntan cuenta: la
  plata sale o llega sin quedar en ninguna cuenta. Propuesta: Preguntar
  «¿De qué cuenta salió?» o «¿A qué cuenta llegó?», con la opción «No pasó
  por mis cuentas», y crear el movimiento ligado como ya hace «Le presté».
- **Media.** *Plan › Colchón en días y Ajustes › Colchón.* Dos cosas
  distintas se llaman «Colchón»: el fondo de emergencia medido en días,
  que no toca «Puedes gastar», y la plata guardada sin tocar de Ajustes,
  que sí lo baja. Elegir cuentas en «Colchón en días» no mueve nada en
  Inicio. Propuesta: Llamarla «Fondo de emergencia en días» (y la sección
  «Dónde está tu fondo») y agregar una línea: «La plata que no quieres
  contar en lo que puedes gastar se fija en Ajustes › Colchón».
- **Media.** *Viajes › página del viaje.* Todo gasto entre las fechas del
  viaje cuenta, aunque sea en Medellín y en pesos (Éxito, Metro de
  Medellín, gimnasio): hay que sacarlos uno por uno con «No es del viaje».
  Propuesta: En un viaje en otra moneda, contar por defecto los cobros en
  esa moneda o de la tarjeta usada afuera, y preguntar por el resto en
  bloque («Estos 6 gastos en pesos, ¿son del viaje?»).
- **Media.** *Plan › Metas y Reparte tu quincena.* No hay forma de abonar
  a una meta: hay que reescribir el total en «¿Cuánto llevas?» haciendo la
  suma de cabeza, y lo que el sobre de la meta aparta cada quincena nunca
  se suma a lo ahorrado. Propuesta: Botón «Abonar» que sume un monto, y al
  empezar una quincena nueva ofrecer «Pasar los $250.000 del sobre a la
  meta».
- **Media.** *Lo quiero, pero después.* No hay «Lo compré»: comprar un
  deseo es ir a Movimientos y luego borrarlo a mano. La caneca lo borra
  sin confirmar ni deshacer. Propuesta: «Lo compré» que abra el gasto ya
  lleno con el nombre y el precio y quite el deseo; al quitarlo, mostrar
  un aviso con «Deshacer».
- **Media.** *Ingresos variables › Cobro.* «Borrar cobro» borra de una
  vez, sin confirmar ni deshacer; y sin hoja de compartir el aviso de
  «Mensaje copiado» queda tapado por el formulario. Propuesta: Pedir
  confirmación o mostrar «Deshacer» al borrar, y mostrar el aviso de
  mensaje copiado dentro de la hoja (o cerrar la hoja antes).
- **Media.** *Compras a cuotas › hoja.* Con una tarjeta de Quincena dice
  «La compra ya está en esa cuenta», pero si la compra no se anotó en la
  tarjeta no cuenta en ningún lado. Propuesta: Buscar en la tarjeta un
  gasto parecido (valor y fecha); si no hay, decir «No encuentro esta
  compra en la Visa» y ofrecer anotarla desde la misma hoja.
- **Media.** *Plan › Reparte tu quincena.* Con poca plata, la propuesta le
  da todo a la meta y deja el día a día en $0, aunque falten 12 días para
  el pago. Propuesta: Cubrir primero el día a día (lo usual o un mínimo
  por día) y decir «Esta quincena tu meta recibe menos». (Repartir más de
  lo que hay)
- **Media.** *Plan › Reparte tu quincena.* Repartir una quincena nueva
  copia los montos de la anterior aunque haya menos plata, y abre diciendo
  «Te pasas por $X». Solo quita los sobres de metas borradas. Propuesta:
  Copiar metas y apartados, ajustar el día a día a lo que queda y decir
  qué cambió («El día a día bajó de $300.000 a $200.000»). (Repartir como
  la quincena pasada)
- **Media.** *Próximos 30 días e Inicio.* «Saldo mínimo estimado» sigue
  contando la reserva y lo apartado en sobres, mientras «Puedes gastar»
  los resta; ni Inicio ni «Próximos 30 días» explican la diferencia. Solo
  «¿Me alcanza?» avisa cuando una compra toca lo apartado. Propuesta:
  Agregar debajo «De eso, $150.000 son de la reserva y $140.000 están en
  sobres», o dibujar en la gráfica la línea de lo apartado. (Saber si me
  alcanza sin tocar la reserva; Repartir la quincena en sobres)
- **Media.** *Viajes › página del viaje.* «No es del viaje» saca el gasto
  de una vez, sin «Deshacer», y no hay dónde ver ni devolver lo que se
  sacó. Propuesta: Mostrar un aviso con «Deshacer» y una sección «Gastos
  que sacaste» para devolverlos. (Cuadrar los gastos de un viaje)
- **Media.** *Viajes › Dividir gastos del viaje con alguien.* Crea un
  grupo vacío ligado al viaje; los gastos del viaje hay que dividirlos uno
  por uno desde Movimientos. Propuesta: Al crear el grupo, ofrecer marcar
  los gastos del viaje que se dividen, o poner «Dividir» en cada línea del
  viaje. (Cuadrar los gastos de un viaje)
- **Media.** *Ingresos variables › Cobro.* La primera opción de «¿Con qué
  movimiento llegó?» sigue siendo «No, o no está en Quincena», y no
  propone el ingreso de $700.000 de Agencia Uno aunque coinciden nombre y
  valor. Propuesta: Decir «Ninguno, o no está en Quincena» y dejar elegido
  el ingreso que coincide. Mejor aún: cuando llegue ese ingreso, ofrecer
  marcar el cobro como cobrado. (Anotar lo que me deben mis clientes)
- **Media.** *Ingresos variables › Usé de la reserva.* Anota el uso de la
  reserva pero no crea ningún gasto: «Puedes gastar» sube 50.000 aunque la
  plata se fue en impuestos, salvo que se anote aparte. Propuesta:
  Preguntar de qué cuenta salió y crear el gasto ligado; si no, al menos
  decir «Anota también el pago en Movimientos». (Reservar una parte de
  cada cobro)
- **Media.** *Plan › Metas.* Una meta con la fecha vencida no avisa nada
  en la fila, y una vez puesta la fecha no se puede quitar; solo se puede
  mover. Propuesta: Avisar «La fecha ya pasó: ¿la mueves?» y agregar un
  botón para quitar la fecha, como el de la prueba gratis. (Poner al día
  una meta y una prueba gratis vencidas)
- **Media.** *Gastos compartidos › Agregar gasto.* Cuando pagaste tú, no
  pregunta la cuenta ni deja ligar un movimiento: los 100.000 del mercado
  no salen de ninguna cuenta y «Puedes gastar» no cambia. Propuesta:
  Preguntar de qué cuenta salió (y contar como gasto solo tu parte) o
  dejar elegir el movimiento ya anotado. (Dividir gastos en un grupo)
- **Baja.** *¿Y si…?* Después de «Aplicar», el escenario de Netflix sigue
  guardado y ahora se calcula sobre el precio nuevo, como si fuera a subir
  otra vez. Propuesta: Al aplicar, quitar el escenario de la lista (o
  marcarlo «Aplicado») y desactivar «Aplicar» para ese mismo cambio.
- **Baja.** *Formularios de Plan (meta, deseo, pago fijo, cuotas,
  préstamo, dividir).* El aviso rojo de datos faltantes sigue a la vista
  después de llenar los campos, hasta volver a guardar. Propuesta: Borrar
  el aviso en cuanto se escribe en un campo, como ya hace «Dividir un
  gasto».
- **Baja.** *Hoja de la meta.* «Para el 30 de abril» no dice el año, y el
  calendario abre seis meses adelante, en otro año. Propuesta: Mostrar el
  año cuando no es el actual: «Para el 30 de abril de 2027».
- **Baja.** *Cargos para revisar.* Para el pago visto dos veces dice
  «ábrelo y bórralo tú»: hay que tocar el movimiento, buscar «Eliminar» y
  confirmar. Propuesta: Botón «Borrar el repetido» en la tarjeta, que pida
  confirmar y deje deshacer. Si la app no debe borrar sola, al menos
  «Abrir el repetido», que lleve directo al movimiento que sobra.
- **Baja.** *Ajustes › Colchón.* El campo del diálogo no tiene etiqueta ni
  borde: sin el teclado arriba no se ve dónde escribir. Además acepta un
  colchón mayor que lo que hay y «Puedes gastar» pasa a «Te faltan» sin
  aviso. Propuesta: Poner una pista en el campo («Por ejemplo, 500.000»)
  y, antes de guardar, decir cómo queda: «Podrías gastar $X hasta el 15 de
  octubre» o «Te faltarían $X».
- **Baja.** *¿Y si…? › Pago tarde y Le presté.* Las flechas abajo/arriba
  significan menos/más días; en «Monto» de Le presté el signo va pegado
  («$80.000») y en las demás hojas con espacio («$ 80.000»). Propuesta:
  Usar − y + para los días, y un solo prefijo en todos los formularios
  tomado de la moneda de la cuenta (hoy tres pantallas ponen «$ » fijo).
- **Baja.** *Compras a cuotas › compra sin tasa.* Con valor financiado y
  cuota conocidos, la tasa sigue diciendo «No la sabes». Propuesta:
  Calcular la tasa que implica la cuota y mostrarla como estimado: «Unos
  1,9 % al mes, calculada con la cuota». (Pagar una compra a cuotas sin
  saber la tasa)
- **Baja.** *Ingresos variables › Reserva.* Cambiar el porcentaje lo
  aplica a todo lo cobrado desde que empezó la reserva: pasar de 15 % a 30
  % la duplica de una vez, sin decirlo. Propuesta: Decirlo junto al
  selector («Cuenta para todo lo cobrado desde el 1 de octubre») o
  preguntar si aplica desde hoy. (Reservar una parte de cada cobro)
- **Baja.** *Pagos fijos.* Un pago fijo en pausa sigue mostrando la
  campana aunque no tenga aviso programado. Propuesta: Ocultar o tachar la
  campana mientras está en pausa, y también cuando la prueba gratis ya
  terminó y no hay aviso. (Cambiar, pausar y borrar un pago fijo)
- **Baja.** *Pagos fijos › Se paga desde.* «Se paga desde» sigue
  ofreciendo todas las cuentas, Binance y Bitcoin incluidas. Propuesta:
  Ofrecer solo cuentas de uso diario y tarjetas, y dejar las demás bajo
  «Otra cuenta». (Cambiar, pausar y borrar un pago fijo)
- **Baja.** *Pagos fijos (lista).* Cuando la prueba gratis termina,
  desaparece de la fila sin decir nada y el próximo cobro se queda en la
  fecha vieja. Propuesta: Al terminar la prueba, preguntar en la fila «¿Ya
  te cobraron Max?» y mover el próximo cobro según la respuesta. (Poner al
  día una meta y una prueba gratis vencidas)
- **Baja.** *Gastos compartidos › Recordar.* Para un préstamo, el mensaje
  sigue diciendo «por los $50.000 de Pedro»: repite el nombre de la
  persona. Propuesta: En préstamos, decir «por los $50.000 que te presté».
  (Quedar a paz y salvo)
- **Baja.** *Gastos compartidos › Registrar pago.* «Registrar pago» no
  deja elegido «Pedro te envió · $50.000» aunque coinciden nombre y valor;
  hay que buscarlo en la lista. Propuesta: Dejar elegido el ingreso que
  coincide en nombre y valor. (Quedar a paz y salvo)
- **Baja.** *Movimientos › gasto dividido.* La fila del gasto dividido
  sigue diciendo «Dividido: tu…» y se corta antes del monto de tu parte.
  Propuesta: Poner «Tu parte $11.750» en una línea propia, o quitar la
  categoría de la fila cuando el gasto está dividido. (Dividir un gasto
  que ya anoté)
- **Baja.** *Dividir un gasto (desde Movimientos).* «Grupo» siempre
  empieza en «Un grupo nuevo» aunque ya exista el de siempre, y el grupo
  nuevo toma el nombre del comercio («Falabella»). Propuesta: Empezar en
  el último grupo usado y, para uno nuevo, dejar el nombre vacío o usar
  los nombres de las personas. (Dividir un gasto que ya anoté)
- **Baja.** *Viajes › Incluir un gasto de antes.* «Incluir un gasto de
  antes» sigue listando todos los gastos de 120 días, arriendo y
  suscripciones incluidos, sin buscador. Propuesta: Mostrar primero
  transporte, alojamiento y gastos grandes, y permitir buscar. (Cuadrar
  los gastos de un viaje)
- **Baja.** *Colchón en días.* Sigue ofreciendo la Visa con deuda y las
  cuentas de cripto como lugar para el fondo de emergencia. Propuesta:
  Dejar fuera las tarjetas de crédito y avisar que la cripto cambia de
  valor. (Medir el colchón en días)
- **Baja.** *Cargos para revisar.* El texto sigue diciendo «mira tus
  movimientos de los últimos 60 días», pero las subidas de precio usan
  seis meses de evidencia. Propuesta: Decir «60 días, y seis meses para
  las subidas de precio». (Revisar los cargos raros)
- **Baja.** *Cierre de la quincena (desde Próximos 30 días).* Con $7.961
  para 12 días sigue sugiriendo «una parte puede ir a tu meta». Propuesta:
  Sugerir la meta solo cuando sobre más de lo que suele gastarse en el día
  a día hasta el pago. (Ver los próximos 30 días)
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
- **Baja.** *Plan › Metas.* Una meta ya cumplida dice «llega en» el mes
  actual (por ejemplo «llega en octubre de 2026») en vez de decir que se
  cumplió; «Meta cumplida» solo aparece en la conversación. (Nuevo.)
  Propuesta: Cuando lo ahorrado llega al total, decir «Meta cumplida» en
  la fila.
- **Baja.** *Reparte tu quincena › Apartar para algo, e Ingresos variables
  › Usé de la reserva.* Con el campo vacío o en cero, «Guardar» cierra el
  diálogo sin decir nada: parece guardado, pero no se creó el sobre ni se
  anotó el uso. (Nuevo.) Propuesta: Dejar el diálogo abierto y decir qué
  falta («Ponle un nombre», «Escribe cuánto usaste»).
- **Baja.** *¿Y si…? › Ahorro más.* Solo «Sube un gasto» tiene «Aplicar».
  Si convence ahorrar 100.000 más por pago, hay que ir a la meta y
  calcular a mano el aporte al mes (200.000 si te pagan dos veces).
  (Nuevo.) Propuesta: Ofrecer «Aplicar» también aquí: elegir la meta y
  subirle el aporte al mes con la cuenta ya hecha.
- **Media.** *Próximos 30 días.* Cada día dice «con lo que pruebas, $X» y
  la leyenda «Con tu pago y lo que pruebas» aunque no se esté probando
  nada (es lo que esperas cobrar). Al mover Netflix en la simulación, el
  12 muestra «Netflix −26.900» y «Netflix +26.900» y el saldo mínimo de
  arriba no cambia. Hoy: Cada día ya dice «si llega lo que esperas, $X»
  cuando no se prueba nada. Pero la leyenda sigue diciendo «Con tu pago y
  lo que pruebas», Netflix movido sale dos veces el día 12 (−26.900 y
  +26.900) y el saldo mínimo de arriba no cambia con lo que se prueba.
  Propuesta: Decir «Con tu pago» en la leyenda cuando no hay simulación;
  mostrar el cobro movido una sola vez en su día nuevo («Netflix, movido
  del 12») y decir el saldo mínimo con lo que se prueba.
- **Baja.** *Plan y Gastos compartidos.* Cifras en cero que no dicen nada:
  «Te deben $0 · debes $170.000», «y $0 de colchón». Hoy: Ya no sale «$0
  de colchón» al repartir. Pero la fila de Gastos compartidos en Plan
  sigue diciendo «Te deben $0 · debes $170.000». Propuesta: Omitir la
  parte en cero en la fila de Plan: «Debes $170.000» o «Te deben $50.000»,
  y «A paz y salvo» si las dos son cero.

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
- **Baja.** *Importar extracto, resultado.* El resultado dice cómo quedó
  el saldo de la cuenta, pero no cómo cambió lo que se puede gastar: en
  08-03 Inicio pasó a «Te faltan $311.939» sin aviso. Propuesta: Agregar
  al resultado el cambio de lo que se puede gastar («Puedes gastar: $7.961
  → te faltan $311.939»). (Sumar al saldo lo que trae el extracto)
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
  escribir la pregunta otra vez. Propuesta: Poner «Volver a preguntar»
  dentro del aviso, que repita la misma pregunta; sin red, que se active
  solo cuando vuelva la conexión.
- **Media.** *Inicio con mis cuentas y Pregúntale a tu plata, sin
  preguntas del día.* Con las 30 usadas, Inicio y la página siguen
  ofreciendo las preguntas como activas; el límite solo aparece después de
  tocar, en rojo como si fuera un error. Propuesta: En el panel de Inicio
  decir «Ya no te quedan preguntas hoy; vuelven mañana», atenuar las
  preguntas y la barra con el cupo en cero, y mostrar el límite en tono
  neutro, no rojo.
- **Media.** *Conversación (demo y propia), al editar lo guardado.* Al
  corregir un gasto, un plan o una cancelación, la respuesta anterior se
  queda arriba con cifras viejas (por ejemplo «Ahora puedes gastar» del
  primer guardado), y confirmar otra vez repite la misma respuesta.
  Propuesta: Atenuar la respuesta anterior y ponerle «Corregido» con «Ver
  la nueva», como ya se hace con la revisión reemplazada («Reemplazada por
  tu nueva selección»).
- **Media.** *Ajustes de la demo, Idioma.* Cambiar el idioma borra la
  conversación sin aviso ni «Deshacer». Propuesta: Avisar antes de borrar
  u ofrecer el mismo «Deshacer» de «Nueva»; o dejar las respuestas viejas
  como están y responder las nuevas en el idioma nuevo.
- **Media.** *Respuesta del gasto guardado (BudgetMeter).* Compara el mes
  en curso (un día) contra todo septiembre: «Septiembre: $615.500 ·
  $570.500 menos» parece un ahorro. Propuesta: Comparar contra los mismos
  días de septiembre, o rotular «En lo que va de octubre» frente a
  «Septiembre completo» y no pintar la diferencia como ahorro.
- **Media.** *Pregúntale a tu plata, anotar un gasto.* Con tus cuentas,
  anotar un gasto usa dos preguntas (pedir el formulario y guardarlo) y
  cada corrección otra; con una sola, el formulario llega y «Guardar
  gasto» responde «Ya usaste las preguntas de hoy». En el ejemplo no se
  gastan preguntas. Propuesta: No descontar del día las acciones sobre una
  respuesta («Guardar gasto», «Guardar este plan», «Editar»), o avisar
  antes de guardar que usa una pregunta; con la última, no ofrecer un
  formulario que no se podrá guardar. (Anotar un gasto con la última
  pregunta del día)
- **Media.** *Pregúntale a tu plata, gasto guardado.* El gasto queda en la
  cuenta principal para gastar (en el ejemplo, «Cuenta de nómina») sin
  decirlo, y el formulario no deja escoger otra. Propuesta: Agregar la
  cuenta al formulario con la principal ya puesta, o decir en la respuesta
  «Quedó en Cuenta de nómina» con una forma de cambiarla.
- **Media.** *Pregúntale a tu plata con tus cuentas, al volver a Inicio.*
  Al tocar «Atrás», la conversación se pierde sin aviso: al volver empieza
  vacía, aunque esas respuestas ya gastaron preguntas del día. En el
  ejemplo, en cambio, la conversación se conserva entre visitas. (Nuevo.)
  Propuesta: Conservar la conversación mientras la app esté abierta, como
  en el ejemplo, o avisar antes de salir que se va a perder.
- **Baja.** *Inicio de la demo, pregunta propia.* «¿Cuánto gasté en el
  Éxito?» recibe el resumen de septiembre sin decir que la demo no busca
  por comercio. Propuesta: Si la pregunta nombra un comercio u otra cosa
  que el guion no responde, decirlo antes del resumen: «En el ejemplo no
  busco por comercio; esto es todo septiembre».
- **Baja.** *Barra de preguntas (demo y propia).* La pista de ejemplo se
  corta («Por ejemplo: ¿Llego a mi meta de Vi…»), así que no se alcanza a
  leer la pregunta que enseña. Propuesta: Permitir dos líneas en la pista
  o usar ejemplos más cortos que quepan en el ancho de un teléfono.
- **Baja.** *Pregúntale a tu plata, barra superior.* Con «Nueva» visible
  el título se corta en «Pregúntale a tu p…», y además repite el rótulo
  «PREGÚNTALE A TU PLATA» de debajo. Propuesta: Título más corto
  («Preguntar») o «Nueva» solo con ícono, y quitar el rótulo repetido bajo
  el título.
- **Baja.** *Inicio con mis cuentas y Pregúntale a tu plata.* Las mismas
  preguntas se ven con chevrón en Inicio y con flecha en la página, y en
  Inicio solo tres de las cinco. Propuesta: Un solo estilo de fila para
  las preguntas en las dos pantallas.
- **Baja.** *Hoja «Reportar esta respuesta».* Si se cierra «Reportar» sin
  enviar, aunque sea con un deslizamiento sin querer, se pierden el motivo
  y el comentario sin preguntar. Propuesta: Guardar el borrador de cada
  respuesta hasta enviarlo, o preguntar antes de descartar un comentario
  escrito.
- **Baja.** *Cómo se calculó, después de guardar un gasto.* Tras guardar
  un gasto, la respuesta dice «Ahora puedes gastar …», pero «Cómo se
  calculó» solo dice «El gasto que se registró» y no ofrece ver el
  cálculo. Propuesta: Ofrecer «Ver cómo se calcula lo que puedes gastar»
  siempre que la respuesta muestre esa cifra, también después de guardar
  un gasto.
- **Baja.** *Conversation, failed save.* Si guardar falla, la conversación
  muestra «Tocaste una acción» y el aviso del problema, sin decir que el
  gasto no se guardó. Propuesta: Usar una nota específica, como «No se
  guardó el gasto» (y su par para el plan y las cancelaciones), en español
  e inglés.
- **Baja.** *Pregúntale a tu plata, «Nueva» después de errores.* Tras
  intentos fallidos, «Nueva» ofrece «Deshacer», que solo trae de vuelta
  los avisos de error. Propuesta: Si ninguna pregunta tuvo respuesta,
  empezar de cero sin ofrecer «Deshacer».
- **Baja.** *Pregúntale a tu plata, guardar un gasto sin preguntas del
  día.* Con el cupo en cero, cada toque en «Guardar gasto» agrega otra
  línea «Tocaste una acción» con el aviso rojo del límite, y el formulario
  sigue ofreciendo guardar. (Nuevo.) Propuesta: Con el cupo en cero,
  apagar «Guardar gasto» con una nota «Podrás guardarlo mañana», en vez de
  sumar un aviso por cada toque.
- **Baja.** *Conversación del ejemplo, engranaje de Ajustes.* En el
  teléfono, esa hoja solo repite Idioma y Apariencia, que ya están en los
  Ajustes de la app, más un «Empezar de nuevo» que hace lo mismo que
  «Nueva» pero sin «Deshacer». Son dos «Ajustes» distintos para lo mismo.
  (Nuevo.) Propuesta: Quitar el engranaje de la conversación en el
  teléfono y dejar Idioma y Apariencia solo en los Ajustes de la app.
- **Media.** *Ajustes de la demo, «Empezar de nuevo».* «Empezar de nuevo»
  borra la conversación al instante, sin confirmar ni «Deshacer». Ya no
  deshace los gastos, que siguen en la cuenta de ejemplo, y ya no está
  bajo «Usar con mis cuentas». Hoy: «Empezar de nuevo» borra la
  conversación al instante, sin confirmar ni «Deshacer». Ya no deshace los
  gastos, que siguen en la cuenta de ejemplo, y ya no está bajo «Usar con
  mis cuentas». Propuesta: Que haga lo mismo que «Nueva», con su
  «Deshacer», o quitarlo de la hoja: hoy repite «Nueva» sin forma de
  volver. Si se queda, decir que los gastos siguen en el ejemplo.

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

Cada flujo trae su lista de lo que el simulador no puede probar: 68 puntos
en total, como avisos del banco con la app cerrada, el widget, compartir
un comprobante, los permisos de Android y sincronizar entre dos
dispositivos. Están en la página, flujo por flujo, en «Lo que hay que
probar en un teléfono de verdad».

## Notas de la corrida

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
