-- =====================================================================
-- 0002 · Dimensiones compartidas en public
--
-- public.eventos es la dimensión maestra de la que cuelgan finanzas,
-- metricas (fase 2) y desempeno (fase 3). La relación
-- finanzas.reg_movimientos.evento_id -> public.eventos.id es la razón
-- de fondo para no partir el proyecto en dos.
--
-- dim_tiempo se crea ahora porque migrar dimensiones compartidas
-- después cuesta caro (sección "Dashboards futuros").
-- =====================================================================

-- ---------------------------------------------------------------------
-- GUARDA · esta migración asume que ella crea public.eventos.
--
-- Sobre un proyecto que ya tiene la tabla (la landing en producción),
-- "create table if not exists" NO falla: se saltea en silencio. Las
-- fallas aparecen después y dispersas — los índices, el trigger, la
-- vista finanzas.cat_eventos, las llaves foráneas de 0004 y los eventos
-- de 0009 — y para entonces ya hay objetos a medio crear.
--
-- Mejor parar acá con el diagnóstico en la mano. En un proyecto vacío
-- esto no hace nada.
-- ---------------------------------------------------------------------
do $guarda$
declare
  v_tipo   text;
  v_faltan text[];
begin
  if to_regclass('public.eventos') is null then
    return;   -- proyecto vacío: sigue el camino normal
  end if;

  select format_type(a.atttypid, a.atttypmod) into v_tipo
  from pg_attribute a
  where a.attrelid = 'public.eventos'::regclass
    and a.attname = 'id' and a.attnum > 0 and not a.attisdropped;

  select array_agg(c order by c) into v_faltan
  from unnest(array['nombre','slug','descripcion','juego','nivel','region','ciclo',
                    'modalidad','fecha_inicio','fecha_fin','estado','publicado',
                    'url_publica','creado_en','actualizado_en']) as c
  where not exists (
    select 1 from pg_attribute
     where attrelid = 'public.eventos'::regclass
       and attname = c and attnum > 0 and not attisdropped
  );

  if v_tipo is distinct from 'text' or v_faltan is not null then
    raise exception using
      message = 'public.eventos ya existe y no tiene la forma que espera el schema finanzas',
      detail  = format('id es de tipo %s (se espera text). Columnas faltantes: %s.',
                       coalesce(v_tipo, '?'),
                       coalesce(array_to_string(v_faltan, ', '), 'ninguna')),
      hint    = 'Correr supabase/scripts/inspeccionar_destino.sql y adaptar esta migración antes de continuar. No cambiar el tipo de la clave primaria de una tabla en producción: adaptar las llaves foráneas de finanzas al tipo nativo y agregar una columna codigo text unique para el identificador legible.';
  end if;
end;
$guarda$;

create table if not exists public.eventos (
  id              text primary key
                    check (id = 'EVT-GENERAL' or id ~ '^EVT-[0-9]{4}-[0-9]{3}$'),
  nombre          text not null check (length(btrim(nombre)) > 0),
  slug            text unique,
  descripcion     text,
  juego           text not null default 'N/A'
                    check (juego in ('League of Legends','Valorant','Multi-título','Otro','N/A')),
  nivel           text not null default 'comunidad'
                    check (nivel in ('casual','comunidad','competitivo','profesional','N/A')),
  region          text not null default 'PE'
                    check (region in ('PE','LATAM','AR','CL','CO','MX','GLOBAL','N/A')),
  ciclo           text,
  modalidad       text not null default 'online'
                    check (modalidad in ('online','presencial','hibrido')),
  fecha_inicio    date,
  fecha_fin       date,
  estado          text not null default 'planificado'
                    check (estado in ('planificado','en_curso','finalizado','cancelado')),
  publicado       boolean not null default false,
  url_publica     text check (url_publica is null or url_publica ~* '^https?://'),
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  constraint ck_evento_rango_fechas
    check (fecha_fin is null or fecha_inicio is null or fecha_fin >= fecha_inicio)
);

comment on table public.eventos is
  'Dimensión maestra de eventos. Cada torneo es un proyecto: nivel, juego, región, ciclo. '
  'Identificadores estables y legibles (EVT-2026-001). EVT-GENERAL absorbe lo no imputable a un evento.';
comment on column public.eventos.id is 'EVT-AAAA-NNN, o EVT-GENERAL para gasto y ingreso estructural.';
comment on column public.eventos.ciclo is 'Ciclo o temporada competitiva, alineado con public.dim_tiempo.ciclo.';

create index if not exists ix_eventos_ciclo   on public.eventos (ciclo);
create index if not exists ix_eventos_estado  on public.eventos (estado);
create index if not exists ix_eventos_publico on public.eventos (publicado) where publicado;

drop trigger if exists tg_eventos_actualizado on public.eventos;
create trigger tg_eventos_actualizado
  before update on public.eventos
  for each row execute function finanzas.fn_toca_actualizado();

-- ---------------------------------------------------------------------
-- dim_tiempo: agrupar por trimestre debe ser trivial en los cuatro
-- dashboards, y el período mensual es el que cruza con la declaración.
-- ---------------------------------------------------------------------
create table if not exists public.dim_tiempo (
  fecha               date primary key,
  anio                smallint not null,
  semestre            smallint not null check (semestre in (1,2)),
  trimestre           smallint not null check (trimestre between 1 and 4),
  mes                 smallint not null check (mes between 1 and 12),
  nombre_mes          text not null,
  dia                 smallint not null,
  dia_semana          smallint not null check (dia_semana between 1 and 7),
  nombre_dia          text not null,
  semana_iso          smallint not null,
  es_fin_semana       boolean not null,
  ciclo               text not null,
  periodo_mensual     text not null,
  periodo_trimestral  text not null
);

comment on table public.dim_tiempo is
  'Calendario 2024-2030. periodo_mensual (AAAA-MM) es la llave de cruce con la declaración mensual del contador.';

create index if not exists ix_dim_tiempo_periodo    on public.dim_tiempo (periodo_mensual);
create index if not exists ix_dim_tiempo_trimestre  on public.dim_tiempo (anio, trimestre);

insert into public.dim_tiempo (
  fecha, anio, semestre, trimestre, mes, nombre_mes, dia, dia_semana, nombre_dia,
  semana_iso, es_fin_semana, ciclo, periodo_mensual, periodo_trimestral)
select
  g.d::date,
  extract(year    from g.d)::smallint,
  (case when extract(month from g.d) <= 6 then 1 else 2 end)::smallint,
  extract(quarter from g.d)::smallint,
  extract(month   from g.d)::smallint,
  (array['Enero','Febrero','Marzo','Abril','Mayo','Junio',
         'Julio','Agosto','Setiembre','Octubre','Noviembre','Diciembre'])[extract(month from g.d)::int],
  extract(day     from g.d)::smallint,
  extract(isodow  from g.d)::smallint,
  (array['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'])[extract(isodow from g.d)::int],
  extract(week    from g.d)::smallint,
  extract(isodow  from g.d) >= 6,
  extract(year from g.d)::text || '-S' || (case when extract(month from g.d) <= 6 then 1 else 2 end)::text,
  to_char(g.d, 'YYYY-MM'),
  extract(year from g.d)::text || '-Q' || extract(quarter from g.d)::text
from generate_series(timestamp '2024-01-01', timestamp '2030-12-31', interval '1 day') as g(d)
on conflict (fecha) do nothing;

-- Fila estructural: toda fila de finanzas lleva evento_id, aunque sea GENERAL.
insert into public.eventos (id, nombre, slug, descripcion, juego, nivel, region, ciclo, modalidad, estado, publicado)
values ('EVT-GENERAL', 'General / no imputable a evento', 'general',
        'Absorbe ingresos y gastos estructurales que no pertenecen a un torneo concreto.',
        'N/A', 'N/A', 'N/A', null, 'online', 'en_curso', false)
on conflict (id) do nothing;
