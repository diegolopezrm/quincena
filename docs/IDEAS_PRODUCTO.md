# Ideas de producto — Quincena

Registro de ideación del 2 de octubre de 2026. Las 15 propuestas se
construyeron en las fases 10 a 14 de [ROADMAP.md](ROADMAP.md), que es la
fuente principal para el orden, las dependencias y los criterios de terminado.
Este documento conserva la ideación original.

## Dirección de producto

Quincena no solo cuenta en qué se fue la plata: ayuda a decidir qué hacer antes
de gastarla. La conversación debe producir herramientas que se puedan tocar
(calendarios, simuladores, comparaciones), no solo párrafos.

## Primera prioridad: decisiones cotidianas

### 1. ¿Me alcanza sin quedar apretado?

Antes de una compra, escribir «¿puedo comprar unos audífonos de $350.000?».
Mostrar cuánto queda hasta el próximo pago, obligaciones próximas y colchón
elegido por la persona. Un deslizador permite cambiar el precio o la fecha de
compra y comparar escenarios.

- MVP: ingreso manual del precio y dos escenarios, comprar hoy o después del pago.
- Depende de: saldos, fechas de pago y obligaciones conocidas.
- Cuidado: separar dinero disponible de proyecciones; indicar datos faltantes.

### 2. Calendario de días apretados

Una línea de saldo proyectado con ingresos y pagos. Resaltar el día en que el
saldo podría caer por debajo del colchón y permitir mover fechas hipotéticas.

- MVP: calendario a 30 días con movimientos recurrentes confirmados.
- Valor: detectar el problema antes de llegar al día sin dinero.
- Cuidado: no presentar una proyección como saldo garantizado.

### 3. Modo «me llegó la quincena»

Al confirmar un ingreso, repartirlo visualmente entre compromisos, gastos
cotidianos, metas y dinero libre. La persona ajusta los montos y guarda el plan.

- MVP: sobres virtuales; no transferir dinero ni simular que se movió en el banco.
- Valor: convertir el día de pago en una decisión de dos minutos.
- Cuidado: evitar contar dos veces el mismo dinero entre sobres y cuentas.

### 4. ¿Y si…?

Simulador conversacional: «¿y si ahorro $100.000 más?», «¿y si mi arriendo
sube?», «¿y si me pagan una semana tarde?». Comparación antes/después con
controles interactivos y fecha estimada de la meta.

- MVP: cambiar una variable sin modificar datos reales.
- Cuidado: guardar el escenario solo tras confirmación explícita.

### 5. Cierre de quincena en tres tarjetas

Qué cambió, qué viene y una acción posible. Ejemplo: «Gastaste más en transporte;
el viernes vence internet; puedes ajustar tu sobre de salidas».

- MVP: resumen dentro de la app; notificación opcional y sin montos en pantalla bloqueada.
- Cuidado: comparar períodos equivalentes y no emitir juicios sobre los gastos.

## Segunda prioridad: recuperar control

### 6. Suscripciones con memoria

Calendario de renovaciones, fin de pruebas y cambios de precio. Preguntar si
todavía se usa una suscripción y mostrar el ahorro anual de pausarla.

- MVP: recurrencias confirmadas y recordatorio previo configurable.
- Cuidado: un cargo recurrente no demuestra que una suscripción esté sin usar;
  no prometer cancelación automática ni confundir cuotas con suscripciones.

### 7. Compras a cuotas, sin sorpresas

Cada compra muestra cuotas pendientes, total por pagar y carga mensual futura.
Un simulador compara pago de contado y cuotas con tasa y cargos conocidos.

- MVP: registro manual de compra, cuotas, tasa y comisiones.
- Cuidado: distinguir cuota, deuda, pago de tarjeta y gasto para no duplicarlos;
  no llamar «sin intereses» a una oferta sin verificar sus condiciones.

### 8. Plata que te deben y gastos compartidos

Registrar «pagué la cena y a Ana le corresponden $40.000». Separar tu gasto del
dinero por cobrar, liquidar grupos pequeños y redactar recordatorios amables.

- MVP: división manual y registro de devolución, sin requerir otra cuenta de usuario.
- Cuidado: compartir o enviar mensajes solo por decisión de la persona;
  una cuenta por cobrar no es dinero disponible.

### 9. Modo independiente

Para ingresos variables: distinguir cobrado, pendiente y estimado; planificar
un mes flojo y crear reservas configurables para compromisos.

- MVP: fechas esperadas de cobro y un escenario conservador elegido por el usuario.
- Cuidado: no contar facturas pendientes como efectivo ni dar cálculos tributarios
  automáticos sin reglas locales verificadas.

### 10. Colchón en días de tranquilidad

Traducir el fondo de emergencia a días de gastos esenciales cubiertos, con una
meta que la persona ajuste y una visualización de progreso.

- MVP: categorías esenciales confirmadas y promedio de un período visible.
- Cuidado: mostrar el cálculo y no imponer una cifra universal de ahorro.

## Tercera prioridad: confianza y experiencias memorables

### 11. ¿De dónde salió este número?

Tocar cualquier cifra para ver movimientos, período, tasa de cambio y fórmula.
También en las respuestas de Gemini. Es una función central de confianza.

- MVP: desglose de «libre hasta el próximo pago» y de totales convertidos.
- Cuidado: cálculos deterministas en el dispositivo; la IA explica, no inventa cifras.

### 12. Detective de cargos

Señalar posibles cobros repetidos, variaciones de precio y movimientos atípicos,
explicando exactamente qué llamó la atención.

- MVP: reglas locales sobre importe, comercio, fecha y recurrencia.
- Cuidado: diferenciar una captura duplicada de dos cargos reales; nunca declarar
  fraude por una anomalía ni borrar automáticamente un cargo.

### 13. Lista «lo quiero, pero después»

Guardar compras deseadas con precio, prioridad y espera opcional. Mostrar cómo
encajan en el plan y dejar comparar «esto primero» frente a otra meta.

- MVP: texto y precio manual, sin scraping ni seguimiento de tiendas.
- Cuidado: evitar afiliados o incentivos que empujen a comprar.

### 14. Bolsillo de viaje

Presupuesto de viaje con moneda local y base, gastos diarios y saldo restante.
Registrar en grupo o individualmente y calcular el efecto de comisiones conocidas.

- MVP: etiqueta de viaje, presupuesto y conversión con tasa y fecha visibles.
- Cuidado: el tipo de cambio estimado puede diferir del cargo final del banco.

### 15. Captura que aprende contigo

Tras revisar un recibo, ofrecer una regla comprensible: «¿Guardar este comercio
como transporte en esta cuenta?». Permitir ver, editar y deshacer reglas.

- MVP: exponer el aprendizaje ya previsto en captura; reglas locales auditables.
- Cuidado: confirmar antes de automatizar y mantener una bandeja de excepciones.

## Orden sugerido para incorporar al roadmap

No sustituye las fases 5–9 ni exige meter todas las ideas antes del lanzamiento.

1. **Base de confianza:** trazabilidad de cifras (11), proyecciones con supuestos
   explícitos y reglas de captura visibles (15).
2. **Primera experiencia diferencial:** decisión de compra (1), calendario (2)
   y cierre de quincena (5).
3. **Planificación:** reparto de ingreso (3), escenarios (4) y colchón (10).
4. **Módulos a validar con usuarios:** suscripciones (6), cuotas (7), compartidos
   (8), independientes (9), anomalías (12), deseos (13) y viajes (14).

## Cómo decidir qué construir

- Probar primero con datos ficticios y prototipos; no conectar bancos para validar una idea.
- Medir si la persona entiende cuánto puede gastar y por qué, sin ayuda.
- Observar qué acciones repite voluntariamente durante dos quincenas.
- Priorizar exactitud, utilidad y confianza sobre cantidad de funciones o tiempo en pantalla.
- Sin transferencias, inversiones, cancelaciones ni mensajes automáticos sin autorización.
- No agregar rachas punitivas, rankings de riqueza ni lenguaje de culpa.
- No prometer predicciones exactas, recomendaciones de inversión o cobertura bancaria universal.

## Siguiente paso

Las 15 están construidas. Lo que sigue es validarlas con personas, como dice
«Cómo decidir qué construir»: si entienden cuánto pueden gastar y por qué, y
qué acciones repiten solas durante dos quincenas.
