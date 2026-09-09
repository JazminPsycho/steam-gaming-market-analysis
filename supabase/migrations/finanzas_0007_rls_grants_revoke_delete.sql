-- =====================================================================
-- 0007 · RLS, grants y REVOKE DELETE
--
-- Cuatro personas registran movimientos. Ninguna puede borrar.
--
--   admin        CEO                  todo, y único que anula
--   finanzas     Dir. de Finanzas     insertar, actualizar, aprobar presupuesto
--   contable     Contador General     insertar, actualizar, conciliar
--   operaciones  COO                  insertar, lectura total
--
-- Dos capas independientes:
--   1. Privilegios de tabla — DELETE y TRUNCATE no se conceden a nadie,
--      ni a service_role. Una clave filtrada no puede borrar historia.
--   2. RLS — quién ve y modifica qué fila, resuelto por rol de aplicación.
--
-- Las políticas envuelven las funciones en (select ...) para que el
-- planificador las evalúe una vez por consulta y no una vez por fila.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1 · Activar RLS en todo
-- ---------------------------------------------------------------------
alter table public.eventos                  enable row level security;
alter table public.dim_tiempo               enable row level security;
alter table finanzas.usuarios               enable row level security;
alter table finanzas.cat_fondos             enable row level security;
alter table finanzas.cat_cuentas            enable row level security;
alter table finanzas.cat_metodos            enable row level security;
alter table finanzas.cat_departamentos      enable row level security;
alter table finanzas.cat_pcge               enable row level security;
alter table finanzas.cat_categorias         enable row level security;
alter table finanzas.cat_contrapartes       enable row level security;
alter table finanzas.cat_items              enable row level security;
alter table finanzas.cat_campanas           enable row level security;
alter table finanzas.eventos_atributos      enable row level security;
alter table finanzas.reg_movimientos        enable row level security;
alter table finanzas.reg_impacto            enable row level security;
alter table finanzas.reg_acuerdos           enable row level security;
alter table finanzas.reg_acuerdo_cuotas     enable row level security;
alter table finanzas.reg_presupuesto        enable row level security;
alter table auditoria.log_cambios           enable row level security;

-- ---------------------------------------------------------------------
-- 2 · Dimensiones compartidas en public
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- public.eventos · UNA SOLA política, y puramente aditiva.
--
-- Cuando la tabla es la de la landing en producción, sus políticas y sus
-- grants NO se tocan: lo que ya sirve el sitio se queda como está. Esta
-- migración solo AGREGA la política que el panel financiero necesita.
--
-- Hace falta porque finanzas.cat_eventos es security_invoker: sin ella,
-- el panel vería únicamente los eventos visibles y se perdería
-- EVT-GENERAL, que está oculta a propósito. Sin EVT-GENERAL el P&L se
-- queda sin la bolsa de lo estructural.
--
-- El acceso de anon no cambia en nada: esta política es solo para
-- authenticated con rol de finanzas.
--
-- Gestionar los eventos sigue siendo trabajo de la landing, no del panel
-- financiero: acá no se conceden INSERT ni UPDATE sobre la tabla.
-- ---------------------------------------------------------------------
create policy sel_eventos_finanzas on public.eventos
  for select to authenticated
  using ((select finanzas.rol_actual()) is not null);

comment on policy sel_eventos_finanzas on public.eventos is
  'Aditiva: deja al panel financiero ver todos los eventos, incluidos los ocultos como EVT-GENERAL. No altera el acceso público, que lo resuelve la política propia de la landing.';

-- El calendario es de solo lectura para todos; lo mantiene el owner.
create policy sel_dim_tiempo on public.dim_tiempo
  for select to anon, authenticated
  using (true);

-- ---------------------------------------------------------------------
-- 3 · Catálogos con el patrón uniforme
--
--     leen  los cuatro roles
--     escriben  admin, finanzas y contable
--     borran  nadie: no existe política de DELETE
--
-- cat_categorias queda fuera: el nivel 1 solo lo modifica el CEO.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['cat_fondos','cat_cuentas','cat_metodos','cat_departamentos',
                           'cat_pcge','cat_contrapartes','cat_items','cat_campanas',
                           'eventos_atributos']
  loop
    execute format($f$
      create policy sel_%1$s on finanzas.%1$s
        for select to authenticated
        using ((select finanzas.rol_actual()) is not null)$f$, t);

    execute format($f$
      create policy ins_%1$s on finanzas.%1$s
        for insert to authenticated
        with check ((select finanzas.tiene_rol(
                       array['admin','finanzas','contable']::finanzas.rol_app[])))$f$, t);

    execute format($f$
      create policy upd_%1$s on finanzas.%1$s
        for update to authenticated
        using      ((select finanzas.tiene_rol(
                       array['admin','finanzas','contable']::finanzas.rol_app[])))
        with check ((select finanzas.tiene_rol(
                       array['admin','finanzas','contable']::finanzas.rol_app[])))$f$, t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- 4 · cat_categorias · el nivel 1 solo lo modifica el CEO
--
-- Cambiar el nivel 1 obliga a migrar datos ya clasificados. El nivel 2
-- puede crecer sin romper ningún reporte.
-- ---------------------------------------------------------------------
create policy sel_cat_categorias on finanzas.cat_categorias
  for select to authenticated
  using ((select finanzas.rol_actual()) is not null);

create policy ins_cat_categorias on finanzas.cat_categorias
  for insert to authenticated
  with check (
    (select finanzas.es_admin())
    or (nivel = 2 and (select finanzas.tiene_rol(
          array['finanzas','contable']::finanzas.rol_app[])))
  );

create policy upd_cat_categorias on finanzas.cat_categorias
  for update to authenticated
  using (
    (select finanzas.es_admin())
    or (nivel = 2 and (select finanzas.tiene_rol(
          array['finanzas','contable']::finanzas.rol_app[])))
  )
  with check (
    (select finanzas.es_admin())
    or (nivel = 2 and (select finanzas.tiene_rol(
          array['finanzas','contable']::finanzas.rol_app[])))
  );

-- ---------------------------------------------------------------------
-- 5 · finanzas.usuarios · cada uno se ve a sí mismo; el CEO ve a todos
--
-- El primer admin lo crea el owner de la base desde el Studio: no hay
-- forma de arrancar la cadena desde la aplicación, y así debe ser.
-- ---------------------------------------------------------------------
create policy sel_usuarios on finanzas.usuarios
  for select to authenticated
  using (id = (select auth.uid()) or (select finanzas.es_admin()));

create policy ins_usuarios on finanzas.usuarios
  for insert to authenticated
  with check ((select finanzas.es_admin()));

create policy upd_usuarios on finanzas.usuarios
  for update to authenticated
  using      ((select finanzas.es_admin()))
  with check ((select finanzas.es_admin()));

-- ---------------------------------------------------------------------
-- 6 · REG_MOVIMIENTOS
--
-- Los cuatro roles insertan. operaciones no actualiza (insertar y
-- lectura total). Solo admin toca filas anuladas o anula: la política de
-- no-admin exige estado = activo en USING y en WITH CHECK, así que no
-- puede anular ni reactivar.
-- ---------------------------------------------------------------------
create policy sel_reg_movimientos on finanzas.reg_movimientos
  for select to authenticated
  using ((select finanzas.rol_actual()) is not null);

create policy ins_reg_movimientos on finanzas.reg_movimientos
  for insert to authenticated
  with check ((select finanzas.rol_actual()) is not null);

create policy upd_reg_movimientos_admin on finanzas.reg_movimientos
  for update to authenticated
  using      ((select finanzas.es_admin()))
  with check ((select finanzas.es_admin()));

create policy upd_reg_movimientos_gestion on finanzas.reg_movimientos
  for update to authenticated
  using      ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
              and estado = 'activo')
  with check ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
              and estado = 'activo');

-- ---------------------------------------------------------------------
-- 7 · REG_IMPACTO · publicar es una decisión del CEO
--
-- Es el dato con riesgo reputacional. Marcar publicado = true queda
-- restringido a admin, y una fila ya publicada es inmutable para el resto.
-- ---------------------------------------------------------------------
create policy sel_reg_impacto on finanzas.reg_impacto
  for select to authenticated
  using ((select finanzas.rol_actual()) is not null);

create policy ins_reg_impacto on finanzas.reg_impacto
  for insert to authenticated
  with check (
    (select finanzas.tiene_rol(array['admin','finanzas','contable']::finanzas.rol_app[]))
    and (not publicado or (select finanzas.es_admin()))
  );

create policy upd_reg_impacto_admin on finanzas.reg_impacto
  for update to authenticated
  using      ((select finanzas.es_admin()))
  with check ((select finanzas.es_admin()));

create policy upd_reg_impacto_gestion on finanzas.reg_impacto
  for update to authenticated
  using      ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
              and estado = 'activo'
              and not publicado)
  with check ((select finanzas.tiene_rol(array['finanzas','contable']::finanzas.rol_app[]))
              and estado = 'activo'
              and not publicado);

-- ---------------------------------------------------------------------
-- 8 · REG_ACUERDOS y su cronograma
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['reg_acuerdos','reg_acuerdo_cuotas']
  loop
    execute format($f$
      create policy sel_%1$s on finanzas.%1$s
        for select to authenticated
        using ((select finanzas.rol_actual()) is not null)$f$, t);

    execute format($f$
      create policy ins_%1$s on finanzas.%1$s
        for insert to authenticated
        with check ((select finanzas.tiene_rol(
                       array['admin','finanzas','contable']::finanzas.rol_app[])))$f$, t);

    execute format($f$
      create policy upd_%1$s_admin on finanzas.%1$s
        for update to authenticated
        using      ((select finanzas.es_admin()))
        with check ((select finanzas.es_admin()))$f$, t);

    execute format($f$
      create policy upd_%1$s_gestion on finanzas.%1$s
        for update to authenticated
        using      ((select finanzas.tiene_rol(
                       array['finanzas','contable']::finanzas.rol_app[]))
                    and estado = 'activo')
        with check ((select finanzas.tiene_rol(
                       array['finanzas','contable']::finanzas.rol_app[]))
                    and estado = 'activo')$f$, t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- 9 · REG_PRESUPUESTO · lo aprueba finanzas, no contable ni operaciones
--
-- Además del RLS, fn_presupuesto_congelado() impide editar montos y
-- llaves de una fila con congelado_en puesto, sea quien sea el rol.
-- ---------------------------------------------------------------------
create policy sel_reg_presupuesto on finanzas.reg_presupuesto
  for select to authenticated
  using ((select finanzas.rol_actual()) is not null);

create policy ins_reg_presupuesto on finanzas.reg_presupuesto
  for insert to authenticated
  with check ((select finanzas.tiene_rol(array['admin','finanzas']::finanzas.rol_app[])));

create policy upd_reg_presupuesto_admin on finanzas.reg_presupuesto
  for update to authenticated
  using      ((select finanzas.es_admin()))
  with check ((select finanzas.es_admin()));

create policy upd_reg_presupuesto_finanzas on finanzas.reg_presupuesto
  for update to authenticated
  using      ((select finanzas.rol_actual()) = 'finanzas' and estado = 'activo')
  with check ((select finanzas.rol_actual()) = 'finanzas' and estado = 'activo');

-- ---------------------------------------------------------------------
-- 10 · Log de auditoría · se lee, no se escribe
--
-- Sin política de INSERT: la única vía de escritura es
-- auditoria.fn_registrar_cambio(), que es SECURITY DEFINER.
-- ---------------------------------------------------------------------
create policy sel_log_cambios on auditoria.log_cambios
  for select to authenticated
  using ((select finanzas.tiene_rol(array['admin','contable']::finanzas.rol_app[])));

-- =====================================================================
-- 11 · Privilegios de tabla
-- =====================================================================

-- anon no entra a finanzas ni a auditoria. Ni USAGE del schema.
revoke all on schema finanzas  from anon;
revoke all on schema auditoria from anon;

grant usage on schema finanzas  to authenticated, service_role;
grant usage on schema auditoria to authenticated, service_role;

grant select, insert, update on all tables in schema finanzas
  to authenticated, service_role;
grant select on all tables in schema auditoria
  to authenticated, service_role;
grant usage, select on all sequences in schema finanzas
  to authenticated, service_role;

-- ---------------------------------------------------------------------
-- Anti-borrado. Esto es lo que importa más que el backup.
--
-- DELETE y TRUNCATE no se conceden a ningún rol de aplicación, ni a
-- service_role: una clave de servicio filtrada no puede borrar historia
-- financiera. El único camino que queda es el owner de la base desde el
-- Studio, que es exactamente el modelo del documento — nadie en la
-- organización de Supabase salvo el CEO.
--
-- TRUNCATE va incluido a propósito: pasa por encima de DELETE y de RLS.
-- ---------------------------------------------------------------------
revoke delete, truncate on all tables in schema finanzas
  from anon, authenticated, service_role;
revoke delete, truncate on all tables in schema auditoria
  from anon, authenticated, service_role;

-- El log no se altera ni se completa a mano.
revoke insert, update on auditoria.log_cambios
  from anon, authenticated, service_role;

-- Las tablas futuras del schema nacen con el mismo régimen: nunca se
-- concede DELETE, así que basta con conceder lo demás.
alter default privileges in schema finanzas
  grant select, insert, update on tables to authenticated, service_role;
alter default privileges in schema finanzas
  grant usage, select on sequences to authenticated, service_role;
alter default privileges in schema auditoria
  grant select on tables to authenticated, service_role;

-- ---------------------------------------------------------------------
-- Limpieza de los grants por defecto del schema public.
--
-- Supabase concede ALL a anon, authenticated y service_role sobre todo
-- lo que nace en public. Sin esto, la clave anon podría borrar eventos
-- de la landing.
-- ---------------------------------------------------------------------
-- Los grants de public.eventos se dejan EXACTAMENTE como están: son los
-- de la landing y cambiarlos es un movimiento en vivo sobre el sitio.
-- Ver el hallazgo sobre los privilegios de anon en supabase/README.md:
-- se trata aparte, en su propia ventana, no escondido acá.
--
-- dim_tiempo sí es nuestra: solo lectura para todos, la mantiene el owner.
revoke all on public.dim_tiempo from anon, authenticated, service_role;
grant select on public.dim_tiempo to anon, authenticated, service_role;

-- La vista cat_eventos hereda la RLS de public.eventos (security_invoker).
-- Solo lectura: ahora es un join con eventos_atributos, así que no es
-- auto-actualizable, y escribir en la tabla de la landing no es tarea
-- del panel financiero.
grant select on finanzas.cat_eventos to authenticated, service_role;
