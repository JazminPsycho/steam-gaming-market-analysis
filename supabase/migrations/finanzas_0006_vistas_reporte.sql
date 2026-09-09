-- =====================================================================
-- 0006 · Vistas de reporte
--
-- Los cinco reportes de la sección "Reportes y sus dependencias", más
-- tres controles que exigen las secciones de alerta del documento.
--
-- Todas con security_invoker = true: la vista se evalúa con los permisos
-- de quien consulta, así que la RLS de las tablas base sigue aplicando.
-- Una vista definer aquí sería una puerta lateral alrededor de la RLS.
--
-- No se crea vista pública para /transparencia: es el punto 11 de la
-- hoja de ruta y exponer datos a anon es una decisión de publicación.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Protección contra publicar una proyección como hecho.
-- El dashboard público lee solo de aquí.
-- ---------------------------------------------------------------------
create view finanzas.v_movimientos_reales with (security_invoker = true) as
select *
from finanzas.reg_movimientos
where estado = 'activo'
  and estado_flujo = 'ejecutado';

comment on view finanzas.v_movimientos_reales is
  'Solo lo ejecutado y activo. Así es imposible que una donación proyectada aparezca como confirmada.';

-- ---------------------------------------------------------------------
-- ¿Este torneo dio pérdida?
-- Depende de evento_id obligatorio en toda fila.
-- ---------------------------------------------------------------------
create view finanzas.v_pl_evento with (security_invoker = true) as
select
  e.id                as evento_id,
  e.nombre            as evento,
  e.juego,
  e.nivel,
  e.ciclo,
  e.estado            as estado_evento,
  e.tipo              as tipo_evento,
  coalesce(sum(case when m.tipo = 'ingreso' then m.monto_pen end), 0) as ingresos_pen,
  coalesce(sum(case when m.tipo = 'egreso'  then m.monto_pen end), 0) as egresos_pen,
  coalesce(sum(case when m.tipo = 'ingreso' then m.monto_pen
                    else -m.monto_pen end), 0)                       as resultado_pen,
  -- El canje no mueve caja: entra y sale por el mismo valor.
  coalesce(sum(case when m.es_especie then 0
                    when m.tipo = 'ingreso' then m.monto_pen
                    else -m.monto_pen end), 0)                       as efecto_caja_pen,
  coalesce(sum(case when m.es_especie then m.monto_pen end), 0)      as especie_pen,
  count(m.id)                                                        as movimientos
-- Lee el catálogo de finanzas, no la tabla cruda: cat_eventos ya traduce
-- los nombres reales de la landing y deriva fechas y estado.
from finanzas.cat_eventos e
left join finanzas.reg_movimientos m
  on m.evento_id = e.id
 and m.estado = 'activo'
 and m.estado_flujo = 'ejecutado'
group by e.id, e.nombre, e.juego, e.nivel, e.ciclo, e.estado, e.tipo;

comment on view finanzas.v_pl_evento is
  'P&L por evento sobre lo ejecutado. resultado_pen incluye canjes (refleja lo consumido); '
  'efecto_caja_pen los excluye (refleja la caja).';

-- ---------------------------------------------------------------------
-- ¿Cuánto cuesta servir a un patrocinador frente a lo que paga?
-- Depende de contraparte_id en el ingreso y atribuido_a_id en el egreso.
-- ---------------------------------------------------------------------
create view finanzas.v_roi_patrocinador with (security_invoker = true) as
with ingresos as (
  select
    contraparte_id                                        as patrocinador_id,
    sum(monto_pen)                                        as ingresos_pen,
    sum(case when es_especie then monto_pen else 0 end)   as ingresos_especie_pen,
    count(*)                                              as movimientos_ingreso
  from finanzas.reg_movimientos
  where estado = 'activo'
    and estado_flujo = 'ejecutado'
    and tipo = 'ingreso'
    and contraparte_id is not null
  group by contraparte_id
),
costos as (
  select
    atribuido_a_id  as patrocinador_id,
    sum(monto_pen)  as costo_servicio_pen,
    count(*)        as movimientos_costo
  from finanzas.reg_movimientos
  where estado = 'activo'
    and estado_flujo = 'ejecutado'
    and tipo = 'egreso'
    and atribuido_a_id is not null
  group by atribuido_a_id
)
select
  c.id            as patrocinador_id,
  c.nombre        as patrocinador,
  coalesce(i.ingresos_pen, 0)         as ingresos_pen,
  coalesce(i.ingresos_especie_pen, 0) as ingresos_especie_pen,
  coalesce(x.costo_servicio_pen, 0)   as costo_servicio_pen,
  coalesce(i.ingresos_pen, 0) - coalesce(x.costo_servicio_pen, 0) as margen_pen,
  case
    when coalesce(x.costo_servicio_pen, 0) = 0 then null
    else round((coalesce(i.ingresos_pen, 0) - x.costo_servicio_pen)
               / x.costo_servicio_pen, 4)
  end as roi,
  coalesce(i.movimientos_ingreso, 0) + coalesce(x.movimientos_costo, 0) as movimientos
from finanzas.cat_contrapartes c
left join ingresos i on i.patrocinador_id = c.id
left join costos   x on x.patrocinador_id = c.id
where c.tipo = 'patrocinador';

comment on view finanzas.v_roi_patrocinador is
  'ROI por patrocinador. roi nulo significa que no hay costo atribuido todavía, no que el ROI sea cero.';

-- ---------------------------------------------------------------------
-- ¿El gasto real se ajusta al presupuesto de cada departamento?
-- Solo contra la versión vigente del presupuesto.
-- ---------------------------------------------------------------------
create view finanzas.v_presupuesto_vs_real with (security_invoker = true) as
select
  p.id            as presupuesto_id,
  p.alcance,
  p.depto_id,
  p.anio,
  p.trimestre,
  p.evento_id,
  p.categoria_id,
  p.tipo,
  p.version,
  p.congelado_en,
  p.monto_pen                              as presupuesto_pen,
  coalesce(r.real_pen, 0)                  as real_pen,
  coalesce(r.real_pen, 0) - p.monto_pen    as variacion_pen,
  case
    when p.monto_pen = 0 then null
    else round((coalesce(r.real_pen, 0) - p.monto_pen) / p.monto_pen, 4)
  end as variacion_pct
from finanzas.reg_presupuesto p
left join lateral (
  select sum(m.monto_pen) as real_pen
  from finanzas.reg_movimientos m
  join public.dim_tiempo t on t.fecha = m.fecha_efectiva
  where m.estado = 'activo'
    and m.estado_flujo = 'ejecutado'
    and m.tipo = p.tipo
    and (p.categoria_id is null or m.categoria_id = p.categoria_id)
    and (
      (p.alcance = 'departamento_trimestre'
        and m.depto_id = p.depto_id
        and t.anio = p.anio
        and t.trimestre = p.trimestre)
      or
      (p.alcance = 'evento' and m.evento_id = p.evento_id)
    )
) r on true
where p.estado = 'activo'
  and p.vigente;

comment on view finanzas.v_presupuesto_vs_real is
  'KPI de variación del Director de Finanzas. Solo la versión vigente: el presupuesto congelado es '
  'la línea base y no se reescribe.';

-- ---------------------------------------------------------------------
-- ¿Cuánta caja habrá en los próximos meses?
-- Depende de fecha_prevista + estado_flujo. Excluye especie.
-- ---------------------------------------------------------------------
create view finanzas.v_flujo_proyectado with (security_invoker = true) as
select
  t.periodo_mensual,
  t.anio,
  t.mes,
  t.periodo_trimestral,
  m.estado_flujo,
  sum(case when m.tipo = 'ingreso' then m.monto_pen else 0 end)  as ingresos_pen,
  sum(case when m.tipo = 'egreso'  then m.monto_pen else 0 end)  as egresos_pen,
  sum(case when m.tipo = 'ingreso' then m.monto_pen
           else -m.monto_pen end)                                as flujo_neto_pen,
  count(*)                                                       as movimientos
from finanzas.reg_movimientos m
join public.dim_tiempo t
  on t.fecha = coalesce(m.fecha_efectiva, m.fecha_prevista)
where m.estado = 'activo'
  and not m.es_especie
group by t.periodo_mensual, t.anio, t.mes, t.periodo_trimestral, m.estado_flujo;

comment on view finanzas.v_flujo_proyectado is
  'Flujo por período y estado_flujo. Filtrar por estado_flujo = ejecutado da la caja real; sumar los '
  'tres da el flujo proyectado completo.';

-- ---------------------------------------------------------------------
-- Informe público de donaciones.
-- Depende de pasa_por_caja + evidencia_url + publicado.
-- ---------------------------------------------------------------------
create view finanzas.v_impacto_publicable with (security_invoker = true) as
select
  i.id,
  i.fecha,
  t.periodo_mensual,
  c.nombre        as beneficiario,
  i.evento_id,
  e.nombre        as evento,
  i.tipo_aporte,
  i.pasa_por_caja,
  i.origen,
  i.monto,
  i.evidencia_url,
  i.descripcion
from finanzas.reg_impacto i
join finanzas.cat_contrapartes c on c.id = i.beneficiario_id
join finanzas.cat_eventos e      on e.id = i.evento_id
left join public.dim_tiempo t     on t.fecha = i.fecha
where i.estado = 'activo'
  and i.publicado
  and i.evidencia_url is not null;

comment on view finanzas.v_impacto_publicable is
  'Impacto con evidencia y marcado como publicado. pasa_por_caja separa lo recaudado por Trufas de '
  'lo facilitado por Trufas: sin ese corte ninguna cifra pública es defendible.';

-- ---------------------------------------------------------------------
-- CONTROL · Riesgo de reparo por medio de pago (D. Leg. 1529)
-- ---------------------------------------------------------------------
create view finanzas.v_alertas_bancarizacion with (security_invoker = true) as
select
  m.id,
  m.fecha_efectiva,
  m.tipo,
  m.descripcion,
  m.moneda,
  m.monto_original,
  m.monto_pen,
  cu.nombre                     as cuenta,
  cu.tipo                       as tipo_cuenta,
  me.nombre                     as metodo,
  m.cuenta_destino_final_id,
  m.comprobante_tipo,
  m.comprobante_nro,
  case
    when m.moneda = 'USD' and m.monto_original >= 500 then 'US$ 500'
    else 'S/ 2 000'
  end as umbral_superado,
  (m.cuenta_destino_final_id is not null) as puente_documentado
from finanzas.reg_movimientos m
join finanzas.cat_metodos me      on me.id = m.metodo_id
left join finanzas.cat_cuentas cu on cu.id = m.cuenta_id
where m.estado = 'activo'
  and m.estado_flujo = 'ejecutado'
  and not m.es_especie
  and not me.es_medio_pago_valido
  and (m.monto_pen >= 2000 or (m.moneda = 'USD' and m.monto_original >= 500));

comment on view finanzas.v_alertas_bancarizacion is
  'Operaciones ejecutadas sobre el umbral del D. Leg. 1529 por un medio que no es del sistema '
  'financiero. Cada fila es un gasto que SUNAT podría reparar. puente_documentado = false es lo grave.';

-- ---------------------------------------------------------------------
-- CONTROL · Canjes sin pareja: IGV sin efectivo
-- ---------------------------------------------------------------------
create view finanzas.v_canjes_sin_pareja with (security_invoker = true) as
select
  m.id,
  m.fecha_prevista,
  m.fecha_efectiva,
  m.estado_flujo,
  m.tipo,
  m.descripcion,
  m.monto_pen,
  m.evento_id,
  c.nombre as contraparte,
  m.comprobante_tipo,
  m.comprobante_nro
from finanzas.reg_movimientos m
left join finanzas.cat_contrapartes c on c.id = m.contraparte_id
where m.estado = 'activo'
  and m.es_especie
  and m.contrapartida_id is null;

comment on view finanzas.v_canjes_sin_pareja is
  'Canjes sin su movimiento espejo. En Perú el canje es una permuta: dos operaciones independientes, '
  'ambas con comprobante e IGV. Una fila aquí es contingencia acumulándose.';

-- ---------------------------------------------------------------------
-- CONTROL · Pactado frente a cobrado
-- ---------------------------------------------------------------------
create view finanzas.v_acuerdos_cobranza with (security_invoker = true) as
select
  a.id            as acuerdo_id,
  a.contraparte_id,
  c.nombre        as contraparte,
  a.tipo,
  a.evento_id,
  a.estado_acuerdo,
  a.fecha_inicio,
  a.fecha_fin,
  a.monto_pactado_pen,
  coalesce(sum(q.monto_pen), 0)                                             as cronograma_pen,
  coalesce(sum(case when q.movimiento_id is not null
                    then q.monto_pen end), 0)                               as cobrado_pen,
  coalesce(sum(case when q.movimiento_id is null
                    then q.monto_pen end), 0)                               as pendiente_pen,
  count(q.id) filter (where q.movimiento_id is null
                        and q.fecha_prevista < current_date)                as cuotas_vencidas,
  min(q.fecha_prevista) filter (where q.movimiento_id is null)              as proxima_cuota
from finanzas.reg_acuerdos a
join finanzas.cat_contrapartes c on c.id = a.contraparte_id
left join finanzas.reg_acuerdo_cuotas q
  on q.acuerdo_id = a.id
 and q.estado = 'activo'
where a.estado = 'activo'
group by a.id, a.contraparte_id, c.nombre, a.tipo, a.evento_id, a.estado_acuerdo,
         a.fecha_inicio, a.fecha_fin, a.monto_pactado_pen;

comment on view finanzas.v_acuerdos_cobranza is
  'Pactado frente a cobrado y alertas de vencimiento. cronograma_pen distinto de monto_pactado_pen '
  'significa que el cronograma está incompleto.';
