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
| Proyecto Supabase | **Somos Trufas** · ref `pesflecdjypuzdcotgxn` |
| Región | us-west-2 |
| Motor | Postgres 17.6 |

> El documento de traspaso apunta a un proyecto distinto (`Website`, ref `tpcbzddxwqypvckvvbfa`,
> us-east-2, con `public.eventos` ya poblado). Ese proyecto no está en esta cuenta, así que el
> sistema se construyó aquí y `public.eventos` se creó desde cero. Si la landing termina viviendo en
> otro proyecto, los eventos existentes se traen con un `INSERT`: la estructura no cambia.

## Arquitectura

```
Somos Trufas  (proyecto Supabase)
│
├── public       eventos, dim_tiempo        ← dimensiones compartidas
├── finanzas     10 catálogos + 5 registros ← esta fase
├── auditoria    log de cambios             ← esta fase
├── metricas     redes y comunidad          ← fase 2
└── desempeno    KPIs por cargo             ← fase 3
```

Un solo proyecto, separación por schemas. En Supabase cada proyecto es una instancia Postgres
aislada y **no existen llaves foráneas entre proyectos**: separar finanzas convertiría `evento_id` en
un número copiado a mano. La relación `finanzas.reg_movimientos.evento_id → public.eventos.id` es una
llave foránea real, y esa es la razón de fondo para no partir el proyecto en dos.

## Migraciones

Se aplican en orden. Cada una es idempotente solo respecto de sí misma: no reejecutar sobre una base
que ya las tiene.

| Archivo | Qué crea |
|---|---|
| `0001_schemas_tipos_roles.sql` | schemas, 16 enums, `finanzas.usuarios`, helpers de rol, trigger de sello |
| `0002_dimensiones_compartidas.sql` | `public.eventos`, `public.dim_tiempo` (2024-2030), fila `EVT-GENERAL` |
| `0003_finanzas_catalogos.sql` | 9 catálogos + vista `cat_eventos` |
| `0004_finanzas_registros.sql` | `reg_movimientos`, `reg_impacto`, `reg_acuerdos`, `reg_acuerdo_cuotas`, `reg_presupuesto` |
| `0005_auditoria.sql` | `auditoria.log_cambios` + triggers |
| `0006_vistas_reporte.sql` | 9 vistas de reporte y control |
| `0007_rls_grants_revoke_delete.sql` | RLS en 18 tablas, políticas por rol, `REVOKE DELETE` |
| `0008_semilla_catalogos.sql` | árbol de categorías, plan PCGE borrador, cuentas, métodos, departamentos |
| `0009_datos_prueba.sql` | 100 filas de registro de prueba |
| `0010_afinado_indices_politicas.sql` | índice que cubre la FK compuesta y unificación de las políticas de UPDATE |

## Paso manual obligatorio

**El schema `finanzas` no está expuesto en la API REST.** Hasta que se exponga, el panel no puede
leer ni escribir nada por PostgREST, aunque los permisos de base de datos estén correctos.

> Dashboard → Project Settings → API → **Exposed schemas** → añadir `finanzas`

No añadir `auditoria`: el log se consulta desde el Studio o por una vista específica si hace falta.

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

De ahí en adelante el admin gestiona los demás usuarios desde el panel.

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

**RLS.** 51 políticas resueltas por `finanzas.rol_actual()`. La anulación es la única vía de baja, y
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

Para comprobar que todo esto sigue en pie: `scripts/verificar_protecciones.sql`. Son 17 pruebas y
todas deben decir `PASA`.

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

`0009` carga 100 filas de registro (55 movimientos, 14 impacto, 8 acuerdos, 13 cuotas, 10
presupuesto) más 8 eventos y 20 contrapartes de apoyo. Todo marcado con `[PRUEBA]` en `descripcion`
o `notas`.

Cubren los casos que rompen los reportes si están mal: canjes emparejados y uno suelto, puente
Binance a banco y dos operaciones sobre el umbral sin puente, activo fijo por encima y por debajo del
corte de la UIT, moneda extranjera con tipo de cambio, los tres estados de flujo, dos movimientos
anulados, impacto que no pasa por caja, e impacto sin evidencia que por eso no es publicable.

Para purgarlos: `scripts/purgar_datos_prueba.sql`, como owner. Trae `rollback` al final: revisar los
conteos y cambiarlo por `commit`.

## Pendiente del documento

Lo que esta fase **no** cubre, en el orden de la hoja de ruta:

1. **Contratar contador** — prioridad cero. Sigue sin resolver, y las obligaciones mensuales del
   Régimen MYPE Tributario se acumulan como omisiones.
2. **Worker de backup** hacia R2 y **worker de keep-alive.** El plan free no trae respaldos y el
   proyecto se pausa a los siete días sin actividad.
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

Dos temas fiscales adicionales que el documento deja abiertos y que conviene llevar a la primera
reunión: el **cobro por Binance y PayPal** (ninguno es Empresa del Sistema Financiero supervisada por
la SBS, así que los gastos asociados podrían ser reparados — `v_alertas_bancarizacion` lista los
casos) y la **facturación de los canjes ya realizados**, que en Perú son permutas y generan IGV sin
generar efectivo.

Nada de este documento constituye asesoría tributaria.

## Nombres por confirmar

Los departamentos se sembraron con una propuesta, porque el documento dice «los cinco del
organigrama» sin listarlos: `DEP-DIRECCION`, `DEP-FINANZAS`, `DEP-OPERACIONES`, `DEP-MARKETING`,
`DEP-ESPORTS`, más `DEP-GENERAL` para lo no imputable. Corregir los nombres es un `UPDATE`; cambiar
los identificadores cascadea por las llaves foráneas, así que conviene fijarlos antes de cargar datos
reales.
