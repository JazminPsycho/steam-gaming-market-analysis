-- =====================================================================
-- 0010 · Afinado a partir del linter de rendimiento
--
-- Dos correcciones reales:
--
-- 1. La llave foránea compuesta (categoria_id, tipo) de reg_movimientos
--    no tenía índice que la cubriera: ix_mov_categoria era solo sobre
--    categoria_id. El índice compuesto también sirve las búsquedas por
--    categoria_id sola, porque es el prefijo izquierdo.
--
-- 2. Cada tabla de registro tenía dos políticas permisivas de UPDATE
--    (admin y gestión). Postgres evalúa todas las políticas permisivas
--    en cada consulta, así que se unifican en una sola con un OR. La
--    semántica es idéntica: admin puede todo, y finanzas y contable solo
--    filas activas — no pueden anular ni reactivar.
--
-- No se indexan las llaves foráneas de los catálogos (cat_campanas,
-- cat_items, cat_cuentas, cat_categorias.cuenta_pcge, usuarios.depto_id).
-- Son tablas de 6 a 34 filas: un recorrido secuencial le gana al índice,
-- y el índice solo añadiría costo de escritura.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1 · Índices que cubren llaves foráneas en las tablas que crecen
-- ---------------------------------------------------------------------
drop index if exists finanzas.ix_mov_categoria;
create index ix_mov_categoria_tipo
  on finanzas.reg_movimientos (categoria_id, tipo);
comment on index finanzas.ix_mov_categoria_tipo is
  'Cubre fk_mov_categoria. El prefijo izquierdo sirve también las consultas por categoria_id sola.';

create index ix_acu_depto on finanzas.reg_acuerdos (depto_id);
create index ix_acu_item  on finanzas.reg_acuerdos (item_id);
create index ix_pre_categoria on finanzas.reg_presupuesto (categoria_id);

-- ---------------------------------------------------------------------
-- 2 · Una sola política permisiva de UPDATE por tabla de registro
-- ---------------------------------------------------------------------

-- reg_movimientos · operaciones no actualiza; anular es solo del admin
drop policy upd_reg_movimientos_admin   on finanzas.reg_movimientos;
drop policy upd_reg_movimientos_gestion on finanzas.reg_movimientos;

create policy upd_reg_movimientos on finanzas.reg_movimientos
  for update to authenticated
  using (
    (select finanzas.es_admin())
    or ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
        and estado = 'activo')
  )
  with check (
    (select finanzas.es_admin())
    or ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
        and estado = 'activo')
  );

-- reg_impacto · publicar es decisión del CEO, y lo publicado queda inmutable
drop policy upd_reg_impacto_admin   on finanzas.reg_impacto;
drop policy upd_reg_impacto_gestion on finanzas.reg_impacto;

create policy upd_reg_impacto on finanzas.reg_impacto
  for update to authenticated
  using (
    (select finanzas.es_admin())
    or ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
        and estado = 'activo' and not publicado)
  )
  with check (
    (select finanzas.es_admin())
    or ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
        and estado = 'activo' and not publicado)
  );

-- reg_acuerdos y su cronograma
drop policy upd_reg_acuerdos_admin   on finanzas.reg_acuerdos;
drop policy upd_reg_acuerdos_gestion on finanzas.reg_acuerdos;

create policy upd_reg_acuerdos on finanzas.reg_acuerdos
  for update to authenticated
  using (
    (select finanzas.es_admin())
    or ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
        and estado = 'activo')
  )
  with check (
    (select finanzas.es_admin())
    or ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
        and estado = 'activo')
  );

drop policy upd_reg_acuerdo_cuotas_admin   on finanzas.reg_acuerdo_cuotas;
drop policy upd_reg_acuerdo_cuotas_gestion on finanzas.reg_acuerdo_cuotas;

create policy upd_reg_acuerdo_cuotas on finanzas.reg_acuerdo_cuotas
  for update to authenticated
  using (
    (select finanzas.es_admin())
    or ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
        and estado = 'activo')
  )
  with check (
    (select finanzas.es_admin())
    or ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
        and estado = 'activo')
  );

-- reg_presupuesto · lo aprueba finanzas, no contable ni operaciones
drop policy upd_reg_presupuesto_admin    on finanzas.reg_presupuesto;
drop policy upd_reg_presupuesto_finanzas on finanzas.reg_presupuesto;

create policy upd_reg_presupuesto on finanzas.reg_presupuesto
  for update to authenticated
  using (
    (select finanzas.es_admin())
    or ((select finanzas.rol_actual()) = 'finanzas' and estado = 'activo')
  )
  with check (
    (select finanzas.es_admin())
    or ((select finanzas.rol_actual()) = 'finanzas' and estado = 'activo')
  );

-- ---------------------------------------------------------------------
-- public.eventos conserva sus dos políticas de SELECT a propósito.
--
-- No se pueden unificar: anon no tiene USAGE sobre el schema finanzas,
-- así que no puede resolver finanzas.rol_actual(). Una política única
-- "to anon, authenticated" que llamara a esa función rompería la landing
-- con un error de permisos. La política de anon se queda sin llamadas a
-- funciones, y la interna es solo "to authenticated".
-- ---------------------------------------------------------------------
comment on policy sel_eventos_publicados on public.eventos is
  'Solo lo publicado, sin llamar a ninguna función: anon no puede resolver nada del schema finanzas.';
comment on policy sel_eventos_internos on public.eventos is
  'Visión completa para quien tiene rol de aplicación. Separada de la anterior por el límite de anon.';
