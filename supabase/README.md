# Sistema de gestión financiera — Somos Trufas SAC

Capa de gestión financiera sobre Supabase. **No reemplaza la contabilidad formal:** los libros
electrónicos y el PLE los sigue llevando el contador en su propio software. Esta capa existe para
responder lo que la contabilidad tributaria no responde: si un torneo dio pérdida, cuánto llegó
realmente a la causa, cuánto cuesta servir a un patrocinador, si el gasto se ajusta al presupuesto y
cuánta caja habrá en los próximos meses.

Implementa los pasos 3, 4 y 5 de la hoja de ruta del documento de traspaso v1.

## Proyecto

| | |
|---|---|
| Organización | **Somos Trufas** (`vevwiyhitzjoomksnclt`) — plan Free |
| Proyecto | **`Website`** · ref `tpcbzddxwqypvckvvbfa` |
| Región | us-east-2 · Postgres 17.6 |

Es el mismo proyecto que sirve **somostrufas.org**. Eso es deliberado y es la decisión que sostiene
todo el diseño: en Supabase cada proyecto es una instancia Postgres aislada y **no existen llaves
foráneas entre proyectos**. Separar finanzas convertiría `evento_id` en un número copiado a mano.
La relación `finanzas.reg_movimientos.evento_id → public.eventos.id` es una llave foránea real.

## Arquitectura

```
Website  (proyecto Supabase)
│
├── public       eventos (la landing) + dim_tiempo   ← dimensiones compartidas
├── finanzas     11 catálogos + 5 registros + 9 vistas
├── auditoria    log de cambios, append-only
├── metricas     redes y comunidad                   ← fase 2
└── desempeno    KPIs por cargo                      ← fase 3
```

## Cómo se relaciona finanzas con la tabla de la landing

**Esto es lo menos obvio del diseño. Leerlo antes de tocar nada.**

`public.eventos` **es de la landing y no se rediseñó.** Tiene 28 columnas con su propia semántica,
pensada y comentada: i18n (`titulo_en`, `descripcion_en`, `subtitulo_en`), `serie` para agrupar
ediciones recurrentes, `destacado`, `tipo` (sorteo / torneo / transmisión), y `home` y `esports` como
dos parrillas independientes. Imponerle las columnas de finanzas habría duplicado información que ya
existe con otro nombre y ensuciado la tabla que sirve el sitio.

**Finanzas se adapta a ella, no al revés.** Tres piezas:

**1 · `finanzas.cat_eventos` es el adaptador.** Una vista que traduce y deriva:

| La landing tiene | finanzas lee |
|---|---|
| `titulo` | `nombre` |
| `inicio` (timestamptz) | `fecha_inicio` — **convertido a hora de Lima** |
| `inicio + duracion_horas` | `fecha_fin` |
| `oculto` | `publicado` (invertido) |
| `inicio` y `duracion_horas` | `estado`: planificado / en_curso / finalizado |
| `url` o `enlace` | `url_publica` |

La hora de Lima no es un detalle estético. El comentario de la columna `inicio` dice que la portada
la pinta siempre en hora de Lima, y las fechas del P&L tienen que coincidir con las que ve la gente.
Un evento que arranca 02:00 UTC es del día anterior en Perú: el karaoke cuyo slug dice
`noche-de-karaoke-2026-08-26` arranca `2026-08-27 02:00+00`, y la vista lo reporta el **26**, que es
lo que dice su propio nombre.

El contrato de salida de la vista (18 columnas) es fijo, así que las vistas de reporte no dependen de
la forma real de la tabla. La definición del cuerpo sí: se crea desde un bloque que elige entre dos
formas, la de la landing y la de un proyecto vacío. La misma migración funciona en los dos casos.

**2 · `finanzas.eventos_atributos` guarda lo que finanzas necesita y la landing no tiene.** Nivel,
región, ciclo y modalidad. Extensión 1:1 con `evento_id` como clave primaria y llave foránea. Cada
schema dueño de lo suyo.

**3 · `EVT-GENERAL` es una fila oculta en `public.eventos`.** Es la única escritura que el sistema
financiero hizo sobre la tabla de la landing, y va con `oculto = true`, `home = false` y
`esports = false`: no aparece en la portada ni en el portal de esports, y la política de lectura
pública (`oculto = false`) hace que `anon` no la vea siquiera. Tiene que existir porque la regla no
negociable del documento dice que toda fila lleva `evento_id`, aunque sea GENERAL — sin ella, el P&L
se queda sin la bolsa de lo estructural (contabilidad, hosting, tributos, comisiones).

## Migraciones

Llevan prefijo `finanzas_` para distinguirlas en el historial del proyecto, donde también están las
de la landing (`04_home_seccion_portada`, `05_subtitulo_tarjeta`).

| Archivo | Qué crea |
|---|---|
| `finanzas_0001_schemas_tipos_roles.sql` | schemas, 16 enums, `finanzas.usuarios`, helpers de rol, trigger de sello |
| `finanzas_0002_dimensiones_compartidas.sql` | `dim_tiempo` (2024-2030), la fila `EVT-GENERAL`, y **no toca** `public.eventos` |
| `finanzas_0003_finanzas_catalogos.sql` | 10 catálogos, `eventos_atributos` y la vista adaptadora `cat_eventos` |
| `finanzas_0004_finanzas_registros.sql` | `reg_movimientos`, `reg_impacto`, `reg_acuerdos`, `reg_acuerdo_cuotas`, `reg_presupuesto` |
| `finanzas_0005_auditoria.sql` | `auditoria.log_cambios` + triggers |
| `finanzas_0006_vistas_reporte.sql` | 9 vistas de reporte y control |
| `finanzas_0007_rls_grants_revoke_delete.sql` | RLS en 19 tablas, políticas por rol, `REVOKE DELETE` |
| `finanzas_0008_semilla_catalogos.sql` | árbol de categorías, plan PCGE borrador, cuentas, métodos, departamentos |
| `finanzas_0009_datos_prueba.sql` | 100 filas de registro de prueba, sobre los eventos reales |
| `finanzas_0010_afinado_indices_politicas.sql` | índice que cubre la FK compuesta y unificación de las políticas de UPDATE |

## Paso manual obligatorio

**El schema `finanzas` no está expuesto en la API REST.** Hasta que se exponga, el panel no puede
leer ni escribir nada por PostgREST, aunque los permisos de base de datos estén correctos.

> Dashboard → Project Settings → API → **Exposed schemas** → añadir `finanzas`

No añadir `auditoria`: el log se consulta desde el Studio.

## Arrancar el primer admin

La política de `INSERT` sobre `finanzas.usuarios` exige ser admin, así que la cadena no puede
arrancar desde la aplicación. Es deliberado. Como owner, desde el SQL Editor del Studio:

```sql
-- 1. Crear el usuario en Authentication → Users (un usuario por persona: es lo que
--    hace que el log de auditoría diga quién hizo el cambio).
-- 2. Darle su rol de aplicación:
insert into finanzas.usuarios (id, nombre, email, rol, depto_id)
values ('<uuid de auth.users>', 'Sergio', 'ceo@somostrufas.org', 'admin', 'DEP-DIRECCION');
```

Hoy hay **0 usuarios** en Auth. De ahí en adelante el admin gestiona los demás desde el panel.

Alternativa de respaldo: `finanzas.rol_actual()` también lee el claim `app_metadata.rol` del JWT, así
que un rol puede asignarse desde Auth sin fila en `finanzas.usuarios`. La fila es preferible porque
es auditable y editable sin tocar Auth.

## Roles y permisos

| Rol | Quién | Puede |
|---|---|---|
| `admin` | Sergio · CEO | todo, y **único que anula** (`estado = 'anulado'`) y publica impacto |
| `finanzas` | Director de Finanzas | insertar, actualizar, aprobar presupuesto |
| `contable` | Contador General | insertar, actualizar, conciliar, leer el log de auditoría |
| `operaciones` | COO | insertar y lectura total; **no** actualiza |

Un JWT sin rol de aplicación no ve ninguna fila de `finanzas`. `anon` no tiene ni `USAGE` sobre el
schema.

## Las protecciones

Dos capas independientes, porque una política se puede añadir por error y un privilegio revocado no.

**Privilegios de tabla.** `DELETE` y `TRUNCATE` no se conceden a ningún rol, **ni a `service_role`**:
una clave de servicio filtrada no puede borrar historia financiera. El único camino de borrado que
queda es el owner `postgres` desde el Studio, que es exactamente el modelo del documento — nadie en
la organización de Supabase salvo el CEO. `ALTER DEFAULT PRIVILEGES` deja las tablas futuras igual.

**RLS** en 19 tablas, resuelta por `finanzas.rol_actual()`. La anulación es la única vía de baja, y
la política de UPDATE de los roles no-admin exige `estado = 'activo'` en `USING` y en `WITH CHECK`:
no pueden anular ni reactivar.

**Auditoría.** `auditoria.fn_registrar_cambio()` es `SECURITY DEFINER`, así que el log se escribe
aunque el rol que dispara el cambio no pueda insertar en él. Guarda la fila anterior y la nueva, los
campos que cambiaron, el usuario de Auth y el rol de base de datos efectivo — `db_user = postgres`
delata un cambio hecho desde el Studio, que pasa por encima de RLS. Un `UPDATE` que solo mueve
`actualizado_en` no genera fila.

**Reglas de negocio en la base**, no solo en la app:

- `monto_pen` es columna generada (`monto_original * tc`): no puede desincronizarse
- `estado_flujo = 'ejecutado'` exige `fecha_efectiva`; cualquier otro estado la prohíbe. Es lo que
  sostiene la separación entre proyección y real, y lo que hace imposible publicar una donación
  proyectada como confirmada
- los movimientos se clasifican en categorías de **nivel 2**, y un ingreso no puede caer en una
  categoría de egreso (llave foránea compuesta sobre `(categoria_id, tipo)`)
- un canje se valoriza **igual en ambos lados** y no toca ninguna cuenta
- `cuenta_destino_final_id` solo admite cuentas del sistema financiero
- un presupuesto con `congelado_en` puesto no admite edición de montos ni de llaves: los cambios
  entran como versiones nuevas

Para comprobar que todo esto sigue en pie: `scripts/verificar_protecciones.sql`. Son **18 pruebas** y
todas deben decir `PASA`. Incluye controles positivos, porque una protección que bloquea a todos no
es una protección sino un muro: verifica que el admin **sí** anula y que finanzas **sí** aprueba
presupuesto. Los ids se derivan de los datos, así que el script corre en cualquier proyecto donde
esté instalado el sistema.

## Vistas

| Vista | Responde |
|---|---|
| `v_movimientos_reales` | solo lo ejecutado y activo — la fuente del dashboard público |
| `v_pl_evento` | P&L por evento. `resultado_pen` incluye canjes, `efecto_caja_pen` los excluye |
| `v_roi_patrocinador` | ingresos por `contraparte_id` frente a costo por `atribuido_a_id` |
| `v_presupuesto_vs_real` | variación por departamento-trimestre y por evento, solo versión vigente |
| `v_flujo_proyectado` | flujo por período y `estado_flujo` |
| `v_impacto_publicable` | impacto con evidencia y publicado |
| `v_alertas_bancarizacion` | operaciones sobre el umbral del D. Leg. 1529 por medio no válido |
| `v_canjes_sin_pareja` | canjes sin movimiento espejo: IGV sin efectivo |
| `v_acuerdos_cobranza` | pactado frente a cobrado, con cuotas vencidas |

Todas son `security_invoker`, así que la RLS de las tablas base sigue aplicando. **No hay vista
expuesta a `anon`:** el informe público de `/transparencia` es el punto 11 de la hoja de ruta y
exponer datos es una decisión de publicación, no de esquema.

## Datos de prueba

`finanzas_0009` carga 100 filas de registro (55 movimientos, 14 impacto, 8 acuerdos, 13 cuotas, 10
presupuesto) y 20 contrapartes ficticias. Todo marcado con `[PRUEBA]`.

**No inserta eventos**: usa los 13 reales de la landing, porque meter eventos ficticios los
publicaría en la portada del sitio. Los movimientos se reparten sobre el `circuito-trufas-2026-3`
(el torneo, con contratos comprometidos y premios proyectados), los cuatro sorteos y las ocho noches
de comunidad, más `EVT-GENERAL` para lo estructural.

Cubren los casos que rompen los reportes si están mal: canjes emparejados y uno suelto, puente
Binance a banco y tres operaciones sobre el umbral sin puente, activo fijo por encima y por debajo
del corte de la UIT, moneda extranjera con tipo de cambio, los tres estados de flujo, dos
movimientos anulados, impacto que no pasa por caja, e impacto sin evidencia que por eso no es
publicable.

Para purgarlos: `scripts/purgar_datos_prueba.sql`, como owner. **No borra eventos** — los eventos son
de la landing. Trae `rollback` al final: revisar los conteos y cambiarlo por `commit`.

## Respaldo

`respaldos/eventos_website_2026-09-09.sql` tiene las 13 filas de `public.eventos` tal como estaban
antes de instalar el sistema. El plan Free no incluye backups, así que ese archivo es el único
respaldo de esa tabla en ese momento. Se verificó fila por fila contra la tabla viva comparando una
huella md5 sobre 22 campos: las 13 coinciden. Los datos van como JSON y se reponen con
`jsonb_populate_recordset`, así que los tipos los resuelve la definición de la tabla y ningún literal
mal formateado puede corromper una fila.

## Hallazgos de seguridad, para tratar aparte

Encontrados al instalar. **Ninguno es del sistema financiero**: son de la landing, y quedan acá
documentados en lugar de arreglados de rondón, porque cambiar permisos de la tabla que sirve el sitio
merece su propia ventana.

**1 · `anon` tiene privilegios amplios sobre `public.eventos`.** `DELETE`, `INSERT`, `UPDATE` y
`TRUNCATE`, que son los grants por defecto del schema `public` de Supabase. Hoy la RLS contiene los
tres primeros, porque la única política es de `SELECT`. Pero **`TRUNCATE` pasa por encima de la
RLS**: no es alcanzable por la API REST, así que no es una urgencia, pero es un privilegio que nadie
usa sobre la tabla que sirve la portada.

```sql
-- Revisar primero que nada del sitio escriba con la clave anon.
revoke insert, update, delete, truncate on public.eventos from anon;
```

**2 · `public.rls_auto_enable()` figura como `SECURITY DEFINER` invocable por `anon`.** Es un falso
positivo en la práctica: devuelve `event_trigger`, y Postgres no permite llamar esas funciones como
RPC. Revocar el `EXECUTE` sobrante es higiene, no urgencia.

```sql
revoke execute on function public.rls_auto_enable() from anon, authenticated;
```

Vale la pena saber qué hace: activa RLS automáticamente en cualquier tabla nueva de `public`. Es una
buena pieza de quien montó la landing, y es la razón por la que las tablas de este sistema nacieron
protegidas.

**3 · `public.tocar_actualizado` tiene `search_path` mutable.** Cuerpo trivial
(`new.actualizado = now()`), riesgo bajo, arreglo de una línea:

```sql
alter function public.tocar_actualizado() set search_path = '';
```

**4 · Dos políticas de SELECT en `public.eventos` — esto NO se debe "optimizar".** El linter de
rendimiento lo marca como WARN, pero es deliberado: `lectura publica de eventos visibles` (de la
landing) y `sel_eventos_finanzas` (aditiva, del panel) no se pueden unificar. La de la landing no
debe llamar a `finanzas.rol_actual()`, porque `anon` no tiene `USAGE` sobre el schema `finanzas` y
una política única rompería la portada con un error de permisos.

## Pendiente del documento

Lo que esta fase **no** cubre, en el orden de la hoja de ruta:

1. **Contratar contador** — prioridad cero. Sigue sin resolver, y las obligaciones mensuales del
   Régimen MYPE Tributario se acumulan como omisiones.
2. **Worker de backup** hacia R2 y **worker de keep-alive.** El plan free no trae respaldos y el
   proyecto se pausa a los siete días sin actividad. Con la landing en vivo la pausa es menos
   probable, pero el backup sigue faltando.
3. **Validación del plan de cuentas** y llenado de `cuenta_pcge`.
4. **Dashboards internos** en `admin.somostrufas.org`.
5. **Informe público de transparencia** en `/transparencia`.

### Para el contador, cuando se contrate

`finanzas.cat_pcge` tiene el plan de cuentas en borrador con `validado = false` en las 34 cuentas: el
nivel de tres dígitos es firme, pero las denominaciones de cuarto dígito deben verificarse contra el
[PDF oficial del MEF](https://www.mef.gob.pe/contenidos/conta_publ/pcge/PCGE_2019.pdf).

Las cuentas con `en_disputa = true` son los cuatro puntos que no se resuelven leyendo la norma:

```sql
select cuenta, denominacion, notas from finanzas.cat_pcge where en_disputa order by cuenta;
```

1. **Comisiones bancarias y de pasarela** — 6391 como servicio de terceros frente a 679 como gasto
   financiero
2. **Spread USDT → PEN** — diferencia en cambio (676/776) o comisión, según cómo se documente
3. **Umbral de activo fijo** — el corte de un cuarto de la UIT vigente decide entre 3361 y gasto
4. **Asiento del canje** — genera comprobante e IGV en ambas direcciones; un error acá sí tiene
   consecuencia tributaria

`cuenta_pcge` admite nulo a propósito: el panel funciona mientras esto se resuelve, y rellenarlo
después no obliga a migrar datos.

Dos temas fiscales adicionales para la primera reunión: el **cobro por Binance y PayPal** (ninguno es
Empresa del Sistema Financiero supervisada por la SBS, así que los gastos asociados podrían ser
reparados — `v_alertas_bancarizacion` lista los casos) y la **facturación de los canjes ya
realizados**, que en Perú son permutas y generan IGV sin generar efectivo — `v_canjes_sin_pareja`
lista los que están sin facturar.

Nada de este documento constituye asesoría tributaria.

## Cabos sueltos

**El schema `sistema_finanzas` existe y está vacío** (sin tablas, vistas, funciones ni tipos). No se
tocó. Si fue un intento previo del prototipo del panel contable, se puede borrar con
`drop schema sistema_finanzas;` — confirmar antes que nadie lo esté usando.

**Hubo una instalación previa en el proyecto equivocado.** El sistema se construyó primero en
`pesflecdjypuzdcotgxn`, un proyecto llamado «Somos Trufas» que vive en la organización **Jazruka**.
Esa base quedó con datos de prueba que parecen reales. Conviene pausarla o borrarla desde el
dashboard de esa organización para que nadie cargue movimientos ahí.

**Nombres de departamentos por confirmar.** Se sembraron con una propuesta, porque el documento dice
«los cinco del organigrama» sin listarlos: `DEP-DIRECCION`, `DEP-FINANZAS`, `DEP-OPERACIONES`,
`DEP-MARKETING`, `DEP-ESPORTS`, más `DEP-GENERAL`. Corregir los nombres es un `UPDATE`; cambiar los
identificadores cascadea por las llaves foráneas, así que conviene fijarlos antes de cargar datos
reales.
