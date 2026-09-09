-- =====================================================================
-- 0002 · Dimensiones compartidas en public
--
-- public.eventos es la dimensión maestra de la que cuelgan finanzas,
-- metricas (fase 2) y desempeno (fase 3). La relación
-- finanzas.reg_movimientos.evento_id -> public.eventos.id es la razón
-- de fondo para no partir el proyecto en dos.
--
-- Esta migración reconoce DOS mundos y actúa distinto en cada uno:
--
--   A · Proyecto vacío
--       No hay public.eventos. La crea con la forma que finanzas espera.
--
--   B · Proyecto con la landing ya montada (el caso del proyecto Website)
--       public.eventos ya existe, con filas en producción y su propio
--       modelo: titulo, inicio + duracion_horas, oculto, serie, tipo,
--       home, esports, i18n. NO SE TOCA. Ni una columna.
--       finanzas se adapta a ella mediante la vista finanzas.cat_eventos
--       (ver 0003) y guarda lo que le falta en finanzas.eventos_atributos.
--
-- Imponerle a la tabla de la landing el esquema de finanzas duplicaría
-- información que ya existe con otro nombre y ensuciaría la tabla que
-- sirve el sitio. La adaptación va del lado de finanzas.
--
-- dim_tiempo se crea en los dos mundos, y la fila EVT-GENERAL también,
-- adaptada a la forma que encuentre.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Mundo A · crear la dimensión. En el mundo B esto no hace nada.
-- ---------------------------------------------------------------------
create table if not exists public.eventos (
  id              text primary key,
  nombre          text not null check (length(btrim(nombre)) > 0),
  slug            text unique,
  descripcion     text,
  juego           text,
  nivel           text check (nivel is null or nivel in ('casual','comunidad','competitivo','profesional','N/A')),
  region          text check (region is null or region in ('PE','LATAM','AR','CL','CO','MX','GLOBAL','N/A')),
  ciclo           text,
  modalidad       text check (modalidad is null or modalidad in ('online','presencial','hibrido')),
  fecha_inicio    date,
  fecha_fin       date,
  estado          text not null default 'planificado'
                    check (estado in ('planificado','en_curso','finalizado','cancelado')),
  publicado       boolean not null default false,
  url_publica     text,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  constraint ck_evento_rango_fechas
    check (fecha_fin is null or fecha_inicio is null or fecha_fin >= fecha_inicio)
);

comment on table public.eventos is
  'Dimensión maestra de eventos. Cada torneo es un proyecto. EVT-GENERAL absorbe lo no imputable a un evento concreto.';

-- Índices y trigger solo si la tabla es la de finanzas (mundo A).
-- En el mundo B la landing ya tiene los suyos y su propio trigger.
do $mundo_a$
begin
  if exists (
    select 1 from pg_attribute
     where attrelid = 'public.eventos'::regclass
       and attname = 'nombre' and attnum > 0 and not attisdropped
  ) then
    execute 'create index if not exists ix_eventos_ciclo   on public.eventos (ciclo)';
    execute 'create index if not exists ix_eventos_estado  on public.eventos (estado)';
    execute 'create index if not exists ix_eventos_publico on public.eventos (publicado) where publicado';

    if not exists (
      select 1 from pg_trigger
       where tgrelid = 'public.eventos'::regclass
         and tgname = 'tg_eventos_actualizado'
    ) then
      execute 'create trigger tg_eventos_actualizado
                 before update on public.eventos
                 for each row execute function finanzas.fn_toca_actualizado()';
    end if;
  else
    raise notice
      'public.eventos es la tabla de la landing: no se toca. finanzas se adapta vía finanzas.cat_eventos.';
  end if;
end;
$mundo_a$;

-- ---------------------------------------------------------------------
-- dim_tiempo · igual en los dos mundos.
-- Agrupar por trimestre debe ser trivial en los cuatro dashboards, y el
-- período mensual es el que cruza con la declaración del contador.
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

create index if not exists ix_dim_tiempo_periodo   on public.dim_tiempo (periodo_mensual);
create index if not exists ix_dim_tiempo_trimestre on public.dim_tiempo (anio, trimestre);

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

-- ---------------------------------------------------------------------
-- EVT-GENERAL · la fila que exige la regla no negociable:
-- toda fila de finanzas lleva evento_id, aunque sea GENERAL.
--
-- En el mundo B es la ÚNICA escritura sobre la tabla de la landing en
-- todo el sistema, y va oculta: oculto = true, home = false,
-- esports = false. No aparece en la portada ni en el portal de esports.
-- Se deshace con un DELETE.
-- ---------------------------------------------------------------------
do $general$
begin
  if exists (
    select 1 from pg_attribute
     where attrelid = 'public.eventos'::regclass
       and attname = 'nombre' and attnum > 0 and not attisdropped
  ) then
    -- Mundo A
    execute $ins_a$
      insert into public.eventos
        (id, nombre, slug, descripcion, juego, nivel, region, modalidad, estado, publicado)
      values ('EVT-GENERAL', 'General / no imputable a evento', 'general',
              'Absorbe ingresos y gastos estructurales que no pertenecen a un torneo concreto.',
              'N/A', 'N/A', 'N/A', 'online', 'en_curso', false)
      on conflict (id) do nothing
    $ins_a$;
  else
    -- Mundo B · adaptada a la tabla de la landing.
    -- titulo, inicio y duracion_horas son NOT NULL allí.
    execute $ins_b$
      insert into public.eventos
        (id, titulo, titulo_en, descripcion, inicio, duracion_horas,
         oculto, home, esports, destacado)
      values ('EVT-GENERAL',
              'General / no imputable a evento',
              'General / not attributable to an event',
              'Fila técnica del sistema de gestión financiera: absorbe ingresos y gastos estructurales que no pertenecen a un evento concreto. Oculta a propósito, no se muestra en el sitio.',
              timestamptz '2000-01-01 00:00:00+00', 1,
              true, false, false, false)
      on conflict (id) do nothing
    $ins_b$;
  end if;
end;
$general$;
