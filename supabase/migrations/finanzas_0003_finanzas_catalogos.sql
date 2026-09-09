-- =====================================================================
-- 0003 · Catálogos de finanzas
--
-- Ocho catálogos del documento + dos piezas que la propia hoja de ruta
-- pide preparar ahora:
--   · cat_pcge     — hogar del plan de cuentas borrador, con flag de
--                    validación por el contador (cuenta_pcge es nullable)
--   · cat_campanas — puente entre gasto publicitario y alcance (fase 2)
-- CAT_EVENTOS se resuelve como vista sobre public.eventos: una sola
-- dimensión física, sin copias que se desincronicen.
-- =====================================================================

-- ---------------------------------------------------------------------
-- CAT_FONDOS · operativo frente a benéfico restringido
-- ---------------------------------------------------------------------
create table finanzas.cat_fondos (
  id              text primary key check (id ~ '^FND-[A-Z0-9-]{2,20}$'),
  nombre          text not null,
  tipo            finanzas.tipo_fondo not null,
  restringido     boolean not null default false,
  descripcion     text,
  activo          boolean not null default true,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  constraint ck_fondo_restringido
    check (restringido = (tipo = 'benefico_restringido'))
);
comment on table finanzas.cat_fondos is
  'Un fondo restringido no puede financiar gasto operativo: es la base del informe público de transparencia.';

-- ---------------------------------------------------------------------
-- CAT_CUENTAS · dónde vive la plata
-- ---------------------------------------------------------------------
create table finanzas.cat_cuentas (
  id                    text primary key check (id ~ '^CTA-[A-Z0-9-]{2,20}$'),
  nombre                text not null,
  tipo                  finanzas.tipo_cuenta not null,
  institucion           text,
  moneda                finanzas.moneda not null default 'PEN',
  referencia            text,
  es_sistema_financiero boolean not null default false,
  liquida_en_cuenta_id  text references finanzas.cat_cuentas (id)
                          on update cascade on delete restrict,
  notas                 text,
  activo                boolean not null default true,
  creado_en             timestamptz not null default now(),
  actualizado_en        timestamptz not null default now()
);
comment on column finanzas.cat_cuentas.es_sistema_financiero is
  'true solo para Empresas del Sistema Financiero supervisadas por la SBS. Binance y PayPal no lo son.';
comment on column finanzas.cat_cuentas.liquida_en_cuenta_id is
  'Cuenta bancaria a la que esta cuenta puente liquida. Documenta la operación frente a SUNAT.';

-- ---------------------------------------------------------------------
-- CAT_METODOS · cómo se movió
-- ---------------------------------------------------------------------
create table finanzas.cat_metodos (
  id                    text primary key check (id ~ '^MTD-[A-Z0-9-]{2,20}$'),
  nombre                text not null,
  es_medio_pago_valido  boolean not null,
  descripcion           text,
  activo                boolean not null default true,
  creado_en             timestamptz not null default now(),
  actualizado_en        timestamptz not null default now()
);
comment on column finanzas.cat_metodos.es_medio_pago_valido is
  'Medio de Pago del sistema financiero según D. Leg. 1529. false = riesgo de reparo sobre S/ 2 000 o US$ 500.';

-- ---------------------------------------------------------------------
-- CAT_DEPARTAMENTOS · centros de costo
-- ---------------------------------------------------------------------
create table finanzas.cat_departamentos (
  id              text primary key check (id ~ '^DEP-[A-Z0-9-]{2,20}$'),
  nombre          text not null,
  responsable     text,
  descripcion     text,
  activo          boolean not null default true,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now()
);
comment on table finanzas.cat_departamentos is
  'Centros de costo. Sirve igual para gasto que para el dashboard de desempeño (fase 3).';

alter table finanzas.usuarios
  add constraint fk_usuarios_depto foreign key (depto_id)
    references finanzas.cat_departamentos (id) on update cascade on delete restrict;

-- ---------------------------------------------------------------------
-- CAT_PCGE · plan de cuentas borrador (Res. CNC 002-2019-EF/30)
-- ---------------------------------------------------------------------
create table finanzas.cat_pcge (
  cuenta        text primary key check (cuenta ~ '^[0-9]{3,4}$'),
  denominacion  text not null,
  elemento      smallint generated always as (left(cuenta, 1)::smallint) stored,
  naturaleza    text not null check (naturaleza in ('activo','pasivo','patrimonio','ingreso','gasto','costo')),
  validado      boolean not null default false,
  en_disputa    boolean not null default false,
  notas         text,
  creado_en     timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
comment on table finanzas.cat_pcge is
  'BORRADOR POR VALIDAR. El nivel de tres dígitos es firme; las denominaciones de cuarto dígito deben '
  'verificarse contra el PDF oficial del MEF antes de producción. validado = confirmado por contador colegiado.';
comment on column finanzas.cat_pcge.en_disputa is
  'Marca los puntos que no se resuelven leyendo la norma y requieren criterio del contador.';

-- ---------------------------------------------------------------------
-- CAT_CATEGORIAS · árbol de ingresos y egresos a dos niveles
-- ---------------------------------------------------------------------
create table finanzas.cat_categorias (
  id              text primary key check (id ~ '^CAT-[IE]-[0-9]{2}(-[0-9]{2})?$'),
  tipo            finanzas.tipo_movimiento not null,
  nivel           smallint not null check (nivel in (1,2)),
  padre_id        text references finanzas.cat_categorias (id)
                    on update cascade on delete restrict,
  nombre          text not null check (length(btrim(nombre)) > 0),
  cuenta_pcge     text references finanzas.cat_pcge (cuenta)
                    on update cascade on delete restrict,
  orden           smallint not null default 0,
  activo          boolean not null default true,
  notas           text,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  constraint ck_categoria_nivel_padre
    check ((nivel = 1 and padre_id is null) or (nivel = 2 and padre_id is not null)),
  -- Permite la llave foránea compuesta desde reg_movimientos (categoria_id, tipo):
  -- un movimiento de ingreso no puede clasificarse en una categoría de egreso.
  constraint uq_categoria_id_tipo unique (id, tipo),
  constraint uq_categoria_nombre unique nulls not distinct (tipo, padre_id, nombre)
);
comment on table finanzas.cat_categorias is
  'Árbol a dos niveles. El nivel 1 solo lo modifica el CEO. El nivel 2 puede crecer sin romper reportes: '
  'todos agregan por nivel 1. Los movimientos se clasifican siempre en nivel 2.';
comment on column finanzas.cat_categorias.cuenta_pcge is
  'Puente hacia los libros del contador. NULLABLE a propósito: no hay contador contratado todavía, '
  'y se rellena después sin migrar datos.';

create index ix_categorias_padre on finanzas.cat_categorias (padre_id);
create index ix_categorias_tipo  on finanzas.cat_categorias (tipo, nivel);

create or replace function finanzas.fn_valida_categoria()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_padre finanzas.cat_categorias;
begin
  if new.padre_id is null then
    return new;
  end if;

  select * into v_padre from finanzas.cat_categorias where id = new.padre_id;

  if v_padre.nivel <> 1 then
    raise exception 'El árbol es de dos niveles: el padre % es nivel %, debe ser nivel 1',
      v_padre.id, v_padre.nivel;
  end if;

  if v_padre.tipo <> new.tipo then
    raise exception 'La categoría % (%) no puede colgar de % (%): el tipo debe coincidir',
      new.id, new.tipo, v_padre.id, v_padre.tipo;
  end if;

  return new;
end;
$$;

create trigger tg_categorias_valida
  before insert or update on finanzas.cat_categorias
  for each row execute function finanzas.fn_valida_categoria();

create trigger tg_categorias_actualizado
  before update on finanzas.cat_categorias
  for each row execute function finanzas.fn_toca_actualizado();

-- ---------------------------------------------------------------------
-- CAT_CONTRAPARTES · tabla única con campo tipo
-- ---------------------------------------------------------------------
create sequence finanzas.seq_contrapartes;

create table finanzas.cat_contrapartes (
  id              text primary key default 'CTP-' || lpad(nextval('finanzas.seq_contrapartes')::text, 4, '0')
                    check (id ~ '^CTP-[0-9]{4,}$'),
  tipo            finanzas.tipo_contraparte not null,
  nombre          text not null check (length(btrim(nombre)) > 0),
  razon_social    text,
  tipo_documento  text check (tipo_documento in ('RUC','DNI','CE','PASAPORTE','SIN_DOCUMENTO')),
  numero_documento text,
  email           text,
  telefono        text,
  pais            text default 'PE',
  notas           text,
  activo          boolean not null default true,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  constraint ck_contraparte_ruc
    check (tipo_documento is distinct from 'RUC' or numero_documento ~ '^[0-9]{11}$'),
  constraint ck_contraparte_email
    check (email is null or email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$'),
  constraint uq_contraparte_documento
    unique nulls not distinct (tipo_documento, numero_documento)
);
comment on table finanzas.cat_contrapartes is
  'Patrocinadores, proveedores, colaboradores, beneficiarios y donantes en una sola tabla. '
  'El patrocinador es el mismo en finanzas y en métricas de campaña, así que la dimensión es compartida.';

create index ix_contrapartes_tipo on finanzas.cat_contrapartes (tipo) where activo;

-- ---------------------------------------------------------------------
-- CAT_ITEMS · lo vendible
-- ---------------------------------------------------------------------
create table finanzas.cat_items (
  id              text primary key check (id ~ '^ITM-[A-Z0-9-]{2,24}$'),
  nombre          text not null,
  tipo            finanzas.tipo_item not null,
  categoria_id    text references finanzas.cat_categorias (id)
                    on update cascade on delete restrict,
  precio_lista    numeric(14,2) check (precio_lista is null or precio_lista >= 0),
  moneda          finanzas.moneda not null default 'PEN',
  descripcion     text,
  activo          boolean not null default true,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now()
);
comment on table finanzas.cat_items is
  'Paquetes de patrocinio, activaciones, entradas y planes de Discord. Precio de lista, no precio pactado: '
  'lo pactado vive en reg_acuerdos.';

-- ---------------------------------------------------------------------
-- CAT_CAMPANAS · fase 2, puente gasto publicitario <-> alcance
-- ---------------------------------------------------------------------
create table finanzas.cat_campanas (
  id              text primary key check (id ~ '^CMP-[0-9]{4}-[0-9]{3}$'),
  nombre          text not null,
  plataforma      text check (plataforma in ('Meta','TikTok','YouTube','Twitch','Discord','X','Google','Mixta','Otra')),
  evento_id       text references public.eventos (id) on update cascade on delete restrict,
  depto_id        text references finanzas.cat_departamentos (id) on update cascade on delete restrict,
  fecha_inicio    date,
  fecha_fin       date,
  activo          boolean not null default true,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  constraint ck_campana_fechas
    check (fecha_fin is null or fecha_inicio is null or fecha_fin >= fecha_inicio)
);
comment on table finanzas.cat_campanas is
  'Dimensión compartida preparada para la fase de métricas. La columna puente en reg_movimientos se '
  'agrega en esa fase: el listado de campos de REG_MOVIMIENTOS está cerrado en el documento v1.';

-- ---------------------------------------------------------------------
-- EVENTOS_ATRIBUTOS · lo que finanzas necesita de un evento y la tabla
-- de la landing no tiene.
--
-- Extensión 1:1 de public.eventos. Existe para no agregarle columnas de
-- finanzas a la tabla que sirve el sitio: cada schema dueño de lo suyo,
-- y la llave foránea real intacta.
-- ---------------------------------------------------------------------
create table finanzas.eventos_atributos (
  evento_id       text primary key
                    references public.eventos (id) on update cascade on delete restrict,
  nivel           text check (nivel is null or nivel in ('casual','comunidad','competitivo','profesional','N/A')),
  region          text check (region is null or region in ('PE','LATAM','AR','CL','CO','MX','GLOBAL','N/A')),
  ciclo           text,
  modalidad       text check (modalidad is null or modalidad in ('online','presencial','hibrido')),
  notas           text,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now()
);
comment on table finanzas.eventos_atributos is
  'Atributos de gestión de un evento: nivel, región, ciclo y modalidad. La landing no los necesita, así que viven acá. Se leen a través de finanzas.cat_eventos.';
comment on column finanzas.eventos_atributos.ciclo is
  'Ciclo o temporada competitiva, alineado con public.dim_tiempo.ciclo.';

-- Timestamps de catálogo
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['cat_fondos','cat_cuentas','cat_metodos','cat_departamentos',
                           'cat_pcge','cat_contrapartes','cat_items','cat_campanas',
                           'eventos_atributos','usuarios']
  loop
    execute format(
      'create trigger tg_%1$s_actualizado before update on finanzas.%1$s
         for each row execute function finanzas.fn_toca_actualizado()', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- CAT_EVENTOS · la vista es el adaptador.
--
-- Contrato de salida fijo (18 columnas) sea cual sea la forma real de
-- public.eventos, así que las vistas de reporte de 0006 no se enteran de
-- en qué mundo están.
--
-- En el mundo de la landing hay que traducir y derivar:
--     titulo                      -> nombre
--     inicio                      -> fecha_inicio
--     inicio + duracion_horas     -> fecha_fin
--     not oculto                  -> publicado
--     coalesce(url, enlace)       -> url_publica
--     inicio y duracion_horas     -> estado
--
-- Las fechas se convierten a hora de Lima a propósito: el comentario de
-- la columna `inicio` dice que la portada la pinta siempre en hora de
-- Lima, y las fechas del P&L tienen que coincidir con las que ve la
-- gente. Un evento que arranca 02:00 UTC es del día anterior en Perú.
--
-- security_invoker = true: la RLS de public.eventos sigue aplicando. Por
-- eso 0007 agrega una política aditiva que deja al panel financiero ver
-- también los eventos ocultos (EVT-GENERAL es uno).
-- ---------------------------------------------------------------------
do $vista$
begin
  if exists (
    select 1 from pg_attribute
     where attrelid = 'public.eventos'::regclass
       and attname = 'nombre' and attnum > 0 and not attisdropped
  ) then
    -- Mundo A · la tabla ya tiene la forma de finanzas
    execute $va$
      create view finanzas.cat_eventos with (security_invoker = true) as
      select e.id,
             e.nombre,
             e.descripcion,
             e.juego,
             coalesce(a.nivel,     e.nivel)     as nivel,
             coalesce(a.region,    e.region)    as region,
             coalesce(a.ciclo,     e.ciclo)     as ciclo,
             coalesce(a.modalidad, e.modalidad) as modalidad,
             e.fecha_inicio,
             e.fecha_fin,
             e.estado,
             e.publicado,
             e.url_publica,
             null::text    as serie,
             null::text    as tipo,
             null::text    as subtitulo,
             false         as destacado,
             false         as esports
      from public.eventos e
      left join finanzas.eventos_atributos a on a.evento_id = e.id
    $va$;
  else
    -- Mundo B · la tabla de la landing
    execute $vb$
      create view finanzas.cat_eventos with (security_invoker = true) as
      select e.id,
             e.titulo                                   as nombre,
             e.descripcion,
             e.juego,
             a.nivel,
             a.region,
             a.ciclo,
             a.modalidad,
             (e.inicio at time zone 'America/Lima')::date                             as fecha_inicio,
             ((e.inicio + make_interval(hours => e.duracion_horas))
                at time zone 'America/Lima')::date                                    as fecha_fin,
             case
               when now() <  e.inicio then 'planificado'
               when now() <  e.inicio + make_interval(hours => e.duracion_horas) then 'en_curso'
               else 'finalizado'
             end                                        as estado,
             not e.oculto                               as publicado,
             coalesce(e.url, e.enlace)                  as url_publica,
             e.serie,
             e.tipo,
             e.subtitulo,
             e.destacado,
             e.esports
      from public.eventos e
      left join finanzas.eventos_atributos a on a.evento_id = e.id
    $vb$;
  end if;
end;
$vista$;

comment on view finanzas.cat_eventos is
  'CAT_EVENTOS del modelo de datos. Adaptador sobre public.eventos: traduce los nombres reales de la tabla y junta los atributos de gestión de finanzas.eventos_atributos. No duplica la dimensión maestra, así que las llaves foráneas siguen apuntando a public.eventos.id.';
