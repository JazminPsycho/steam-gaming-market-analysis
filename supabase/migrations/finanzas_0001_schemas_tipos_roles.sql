-- =====================================================================
-- Somos Trufas SAC — Sistema de gestión financiera
-- 0001 · Schemas, tipos enumerados, tabla de usuarios y helpers de rol
--
-- Referencia: "Sistema de Gestión Financiera — Somos Trufas", v1
--   · Arquitectura de schemas (CERRADO)
--   · Roles y permisos (CERRADO)
-- =====================================================================

create schema if not exists finanzas;
create schema if not exists auditoria;

comment on schema finanzas is
  'Capa de gestión financiera de Somos Trufas SAC: catálogos y registros. '
  'No reemplaza la contabilidad formal — los libros electrónicos y el PLE los lleva el contador.';
comment on schema auditoria is
  'Log de cambios de las tablas de registro. Append-only: sin UPDATE ni DELETE para roles de aplicación.';

-- ---------------------------------------------------------------------
-- Tipos enumerados. Solo se enumeran los conjuntos que el documento
-- declara cerrados; lo demás va como CHECK para poder crecer sin ALTER TYPE.
-- ---------------------------------------------------------------------
create type finanzas.rol_app            as enum ('admin','finanzas','contable','operaciones');
create type finanzas.tipo_movimiento    as enum ('ingreso','egreso');
create type finanzas.estado_flujo       as enum ('proyectado','comprometido','ejecutado');
create type finanzas.estado_registro    as enum ('activo','anulado');
create type finanzas.moneda             as enum ('PEN','USD','EUR','USDT');
create type finanzas.tipo_cuenta        as enum ('banco','pasarela','billetera','caja');
create type finanzas.tipo_contraparte   as enum ('patrocinador','proveedor','colaborador','beneficiario','donante');
create type finanzas.tipo_fondo         as enum ('operativo','benefico_restringido');
create type finanzas.tipo_item          as enum ('paquete_patrocinio','activacion','entrada','plan_discord','servicio','otro');
create type finanzas.tipo_aporte        as enum ('efectivo','especie','servicio');
create type finanzas.origen_aporte      as enum ('trufas','patrocinador','comunidad','donante');
create type finanzas.comprobante_tipo   as enum ('ninguno','factura','boleta','recibo_honorarios','nota_credito','nota_debito','voucher','otro');
create type finanzas.alcance_presupuesto as enum ('departamento_trimestre','evento');
create type finanzas.tipo_acuerdo       as enum ('patrocinio','afiliacion','servicio','donacion_comprometida','otro');
create type finanzas.estado_acuerdo     as enum ('borrador','vigente','cumplido','vencido','cancelado');

create type auditoria.operacion         as enum ('INSERT','UPDATE','DELETE','TRUNCATE');

comment on type finanzas.estado_flujo is
  'proyectado = mejor estimado de hoy · comprometido = pactado y con fecha · ejecutado = pagado o cobrado y conciliado.';

-- ---------------------------------------------------------------------
-- Usuarios de la aplicación. Un usuario por persona en Supabase Auth:
-- es lo que hace que el log de auditoría diga quién hizo el cambio.
-- ---------------------------------------------------------------------
create table finanzas.usuarios (
  id              uuid primary key
                    references auth.users (id) on update cascade on delete restrict,
  nombre          text not null check (length(btrim(nombre)) > 0),
  email           text,
  rol             finanzas.rol_app not null,
  depto_id        text,          -- FK a finanzas.cat_departamentos, agregada en 0003
  activo          boolean not null default true,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now()
);

comment on table finanzas.usuarios is
  'Mapa auth.users -> rol de aplicación. Alternativa de respaldo: claim app_metadata.rol en el JWT.';

-- ---------------------------------------------------------------------
-- Helpers de rol. SECURITY DEFINER para que las políticas RLS puedan
-- leer finanzas.usuarios sin recursión, con search_path fijo.
-- ---------------------------------------------------------------------
create or replace function finanzas.rol_actual()
returns finanzas.rol_app
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rol   finanzas.rol_app;
  v_claim text;
begin
  select u.rol into v_rol
  from finanzas.usuarios u
  where u.id = auth.uid()
    and u.activo;

  if v_rol is not null then
    return v_rol;
  end if;

  -- Respaldo: rol declarado en app_metadata del JWT.
  v_claim := nullif(auth.jwt() -> 'app_metadata' ->> 'rol', '');
  if v_claim is null then
    return null;
  end if;

  begin
    return v_claim::finanzas.rol_app;
  exception when invalid_text_representation then
    return null;
  end;
end;
$$;

comment on function finanzas.rol_actual() is
  'Rol de aplicación del usuario autenticado, o NULL si no tiene uno. NULL = sin acceso a finanzas.';

create or replace function finanzas.tiene_rol(p_roles finanzas.rol_app[])
returns boolean
language sql
stable
set search_path = ''
as $$
  select finanzas.rol_actual() = any (p_roles);
$$;

create or replace function finanzas.es_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select finanzas.rol_actual() = 'admin'::finanzas.rol_app;
$$;

-- ---------------------------------------------------------------------
-- Sello de auditoría en las tablas de registro (BEFORE INSERT/UPDATE).
-- ---------------------------------------------------------------------
create or replace function finanzas.fn_sella_auditoria()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.creado_en       := now();
    new.creado_por      := coalesce(new.creado_por, auth.uid());
    new.creado_por_email:= coalesce(new.creado_por_email,
                                    nullif(auth.jwt() ->> 'email', ''),
                                    current_user);
    new.actualizado_en  := now();
    new.actualizado_por := auth.uid();
  else
    -- El origen de una fila no se reescribe nunca.
    new.creado_en        := old.creado_en;
    new.creado_por       := old.creado_por;
    new.creado_por_email := old.creado_por_email;
    new.actualizado_en   := now();
    new.actualizado_por  := auth.uid();

    if new.estado = 'anulado' and old.estado = 'activo' then
      new.anulado_en  := now();
      new.anulado_por := coalesce(new.anulado_por, auth.uid());
    elsif new.estado = 'activo' and old.estado = 'anulado' then
      new.anulado_en       := null;
      new.anulado_por      := null;
      new.motivo_anulacion := null;
    end if;
  end if;
  return new;
end;
$$;

comment on function finanzas.fn_sella_auditoria() is
  'Mantiene creado_*/actualizado_*/anulado_* en las tablas de registro. El borrado es lógico: estado = anulado.';

-- Timestamp simple para los catálogos.
create or replace function finanzas.fn_toca_actualizado()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;
