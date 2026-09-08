-- =====================================================================
-- 0005 · Schema de auditoría
--
-- "Un respaldo salva de un desastre. Estas medidas salvan del error
--  diario, que es el escenario probable."
--
-- El trigger guarda la fila anterior en cada cambio, con usuario y marca
-- de tiempo. Es lo que hace que los registros sean auditables — lo que
-- exige el manual del Contador General y lo que sostiene la promesa
-- pública de transparencia.
-- =====================================================================

create table auditoria.log_cambios (
  id                bigint generated always as identity primary key,
  ocurrido_en       timestamptz not null default now(),
  schema_nombre     text not null,
  tabla             text not null,
  registro_id       text,
  operacion         auditoria.operacion not null,
  -- Quién: usuario de Supabase Auth. NULL = cambio hecho fuera de la app.
  usuario_id        uuid,
  usuario_email     text,
  rol_app           text,
  -- Rol de base de datos efectivo. Delata cambios hechos desde el Studio.
  db_user           text not null default current_user,
  via               text,
  campos_cambiados  text[],
  fila_anterior     jsonb,
  fila_nueva        jsonb
);

comment on table auditoria.log_cambios is
  'Log append-only de cambios sobre las tablas de registro. Sin UPDATE ni DELETE para roles de '
  'aplicación: la única forma de alterarlo es como owner de la base.';
comment on column auditoria.log_cambios.db_user is
  'Rol de base de datos que ejecutó el cambio. "postgres" delata un cambio hecho desde el Studio, '
  'que pasa por encima de RLS.';
comment on column auditoria.log_cambios.via is
  'Método HTTP cuando el cambio entró por PostgREST. NULL = conexión SQL directa.';
comment on column auditoria.log_cambios.campos_cambiados is
  'Solo los campos con valor distinto. Excluye actualizado_en y actualizado_por, que cambian siempre.';

create index ix_log_tabla_registro on auditoria.log_cambios (schema_nombre, tabla, registro_id);
create index ix_log_ocurrido       on auditoria.log_cambios (ocurrido_en desc);
create index ix_log_usuario        on auditoria.log_cambios (usuario_id);
create index ix_log_operacion      on auditoria.log_cambios (operacion);

-- ---------------------------------------------------------------------
-- SECURITY DEFINER: el log se escribe aunque el rol que dispara el
-- cambio no tenga privilegio de INSERT sobre la tabla de log. Es lo que
-- hace que no se pueda registrar un cambio sin dejar rastro.
-- ---------------------------------------------------------------------
create or replace function auditoria.fn_registrar_cambio()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old    jsonb;
  v_new    jsonb;
  v_id     text;
  v_campos text[];
begin
  if tg_op = 'INSERT' then
    v_new := to_jsonb(new);

  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);

    select array_agg(k order by k) into v_campos
    from jsonb_object_keys(v_new) as k
    where v_new -> k is distinct from v_old -> k
      and k not in ('actualizado_en', 'actualizado_por');

    -- Un UPDATE que solo movió el sello no es un cambio que auditar.
    if v_campos is null then
      return null;
    end if;

  else
    v_old := to_jsonb(old);
  end if;

  v_id := coalesce(v_new ->> 'id', v_old ->> 'id');

  insert into auditoria.log_cambios (
    schema_nombre, tabla, registro_id, operacion,
    usuario_id, usuario_email, rol_app, via,
    campos_cambiados, fila_anterior, fila_nueva)
  values (
    tg_table_schema, tg_table_name, v_id, tg_op::auditoria.operacion,
    auth.uid(),
    nullif(auth.jwt() ->> 'email', ''),
    finanzas.rol_actual()::text,
    nullif(current_setting('request.method', true), ''),
    v_campos, v_old, v_new);

  return null;
end;
$$;

comment on function auditoria.fn_registrar_cambio() is
  'Trigger AFTER sobre las tablas de registro. SECURITY DEFINER para que el log se escriba siempre, '
  'incluso cuando el rol que dispara el cambio no puede insertar en él.';

-- ---------------------------------------------------------------------
-- Las cinco tablas de registro, más cat_categorias: el documento señala
-- el árbol de categorías como la única parte del modelo cuyo cambio
-- posterior obliga a migrar datos ya clasificados.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['reg_movimientos','reg_impacto','reg_acuerdos',
                           'reg_acuerdo_cuotas','reg_presupuesto','cat_categorias']
  loop
    execute format(
      'create trigger tg_%1$s_auditoria
         after insert or update or delete on finanzas.%1$s
         for each row execute function auditoria.fn_registrar_cambio()', t);
  end loop;
end;
$$;
