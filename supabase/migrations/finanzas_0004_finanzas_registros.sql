-- =====================================================================
-- 0004 · Tablas de registro
--
-- REG_MOVIMIENTOS   P&L y flujo de caja
-- REG_IMPACTO       informe público de transparencia
-- REG_ACUERDOS      pactado frente a cobrado (+ cronograma)
-- REG_PRESUPUESTO   KPI de variación del Director de Finanzas
--
-- Reglas no negociables aplicadas:
--   · una fila es un movimiento, fechas ISO, nunca columnas por mes
--   · cero texto libre en campos que apunten a catálogo
--   · evento_id y depto_id nunca nulos, aunque sea GENERAL
--   · identificadores estables y legibles, nunca el número de fila
--   · nunca borrar: la columna estado distingue activo de anulado
--   · montos sin formato de moneda en el dato
-- =====================================================================

create sequence finanzas.seq_movimientos;
create sequence finanzas.seq_impacto;
create sequence finanzas.seq_acuerdos;
create sequence finanzas.seq_presupuesto;

-- ---------------------------------------------------------------------
-- REG_MOVIMIENTOS
-- ---------------------------------------------------------------------
create table finanzas.reg_movimientos (
  id                      text primary key
                            default 'MOV-' || to_char(now(), 'YYYY') || '-' ||
                                    lpad(nextval('finanzas.seq_movimientos')::text, 6, '0')
                            check (id ~ '^MOV-[0-9]{4}-[0-9]{6,}$'),

  -- Tres columnas de fecha, no una: sin ellas no hay flujo de caja proyectado.
  fecha_prevista          date not null,
  fecha_efectiva          date,
  estado_flujo            finanzas.estado_flujo not null default 'proyectado',

  tipo                    finanzas.tipo_movimiento not null,
  categoria_id            text not null,

  -- A quién le pagas / de quién cobras.
  contraparte_id          text references finanzas.cat_contrapartes (id)
                            on update cascade on delete restrict,
  -- Para quién es. Sin este campo el ROI por patrocinador es incalculable.
  atribuido_a_id          text references finanzas.cat_contrapartes (id)
                            on update cascade on delete restrict,

  evento_id               text not null default 'EVT-GENERAL'
                            references public.eventos (id)
                            on update cascade on delete restrict,
  depto_id                text not null default 'DEP-GENERAL'
                            references finanzas.cat_departamentos (id)
                            on update cascade on delete restrict,
  fondo_id                text not null default 'FND-OPERATIVO'
                            references finanzas.cat_fondos (id)
                            on update cascade on delete restrict,
  item_id                 text references finanzas.cat_items (id)
                            on update cascade on delete restrict,

  descripcion             text not null check (length(btrim(descripcion)) > 0),

  moneda                  finanzas.moneda not null default 'PEN',
  monto_original          numeric(14,2) not null check (monto_original > 0),
  tc                      numeric(12,6) not null default 1 check (tc > 0),
  monto_pen               numeric(14,2)
                            generated always as (round(monto_original * tc, 2)) stored,

  cuenta_id               text references finanzas.cat_cuentas (id)
                            on update cascade on delete restrict,
  -- Rastrea el puente Binance o PayPal hacia la cuenta bancaria.
  cuenta_destino_final_id text references finanzas.cat_cuentas (id)
                            on update cascade on delete restrict,
  metodo_id               text not null references finanzas.cat_metodos (id)
                            on update cascade on delete restrict,

  -- Canjes: un flag y un par vinculado, no una categoría.
  es_especie              boolean not null default false,
  contrapartida_id        text references finanzas.reg_movimientos (id)
                            on update cascade on delete restrict,
  es_activo_fijo          boolean not null default false,

  comprobante_tipo        finanzas.comprobante_tipo not null default 'ninguno',
  comprobante_nro         text,
  igv                     numeric(14,2) check (igv is null or igv >= 0),

  estado                  finanzas.estado_registro not null default 'activo',
  url_respaldo            text check (url_respaldo is null or url_respaldo ~* '^https?://'),

  creado_en               timestamptz not null default now(),
  creado_por              uuid,
  creado_por_email        text,
  actualizado_en          timestamptz not null default now(),
  actualizado_por         uuid,
  anulado_en              timestamptz,
  anulado_por             uuid,
  motivo_anulacion        text,

  -- Un ingreso no puede clasificarse en una categoría de egreso.
  constraint fk_mov_categoria foreign key (categoria_id, tipo)
    references finanzas.cat_categorias (id, tipo)
    on update cascade on delete restrict,

  constraint ck_mov_ejecutado_con_fecha
    check (estado_flujo <> 'ejecutado' or fecha_efectiva is not null),
  constraint ck_mov_proyectado_sin_fecha
    check (estado_flujo = 'ejecutado' or fecha_efectiva is null),
  constraint ck_mov_tc_pen
    check (moneda <> 'PEN' or tc = 1),
  constraint ck_mov_igv_razonable
    check (igv is null or igv <= round(monto_original * tc, 2)),
  -- Un canje no toca ninguna cuenta.
  constraint ck_mov_especie_sin_cuenta
    check (not es_especie or (cuenta_id is null and cuenta_destino_final_id is null)),
  -- Lo ejecutado en efectivo sí sabe de qué cuenta salió.
  constraint ck_mov_ejecutado_con_cuenta
    check (es_especie or estado_flujo <> 'ejecutado' or cuenta_id is not null),
  constraint ck_mov_contrapartida_solo_especie
    check (contrapartida_id is null or es_especie),
  constraint ck_mov_contrapartida_distinta
    check (contrapartida_id is null or contrapartida_id <> id),
  constraint uq_mov_contrapartida unique (contrapartida_id),
  constraint ck_mov_activo_fijo_es_egreso
    check (not es_activo_fijo or tipo = 'egreso'),
  constraint ck_mov_puente_requiere_origen
    check (cuenta_destino_final_id is null or cuenta_id is not null),
  constraint ck_mov_puente_distinto
    check (cuenta_destino_final_id is null or cuenta_destino_final_id <> cuenta_id),
  constraint ck_mov_comprobante_con_numero
    check (comprobante_tipo = 'ninguno' or comprobante_nro is not null),
  constraint ck_mov_anulacion_coherente
    check ((estado = 'activo'  and anulado_en is null and motivo_anulacion is null)
        or (estado = 'anulado' and anulado_en is not null and motivo_anulacion is not null))
);

comment on table finanzas.reg_movimientos is
  'Una fila = un movimiento. Sin esta tabla no hay P&L ni flujo de caja. No admite DELETE: se anula.';
comment on column finanzas.reg_movimientos.atribuido_a_id is
  'Para quién es el gasto. contraparte_id dice a quién le pagas; esto dice a favor de quién.';
comment on column finanzas.reg_movimientos.es_especie is
  'Canje. Permite excluirlo del flujo de caja sin excluirlo del ROI del patrocinador.';
comment on column finanzas.reg_movimientos.contrapartida_id is
  'Par ingreso-egreso de un canje. Efecto neto en caja igual a cero.';
comment on column finanzas.reg_movimientos.es_activo_fijo is
  'Separa gasto corriente de activo depreciable. Corte práctico: un cuarto de la UIT vigente.';
comment on column finanzas.reg_movimientos.monto_pen is
  'Columna generada: monto_original * tc. Imposible que se desincronice.';

create index ix_mov_fecha_prevista on finanzas.reg_movimientos (fecha_prevista);
create index ix_mov_fecha_efectiva on finanzas.reg_movimientos (fecha_efectiva);
create index ix_mov_evento         on finanzas.reg_movimientos (evento_id);
create index ix_mov_depto          on finanzas.reg_movimientos (depto_id);
create index ix_mov_contraparte    on finanzas.reg_movimientos (contraparte_id);
create index ix_mov_atribuido      on finanzas.reg_movimientos (atribuido_a_id);
create index ix_mov_fondo          on finanzas.reg_movimientos (fondo_id);
create index ix_mov_cuenta         on finanzas.reg_movimientos (cuenta_id);
create index ix_mov_metodo         on finanzas.reg_movimientos (metodo_id);
create index ix_mov_item           on finanzas.reg_movimientos (item_id);
create index ix_mov_cuenta_destino on finanzas.reg_movimientos (cuenta_destino_final_id);
create index ix_mov_reales         on finanzas.reg_movimientos (fecha_efectiva, tipo)
                                      where estado = 'activo' and estado_flujo = 'ejecutado';
create index ix_mov_especie        on finanzas.reg_movimientos (es_especie) where es_especie;

create or replace function finanzas.fn_valida_movimiento()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_cat     finanzas.cat_categorias;
  v_par     finanzas.reg_movimientos;
  v_metodo  finanzas.cat_metodos;
  v_destino finanzas.cat_cuentas;
begin
  select * into v_cat from finanzas.cat_categorias where id = new.categoria_id;
  if v_cat.nivel <> 2 then
    raise exception 'Los movimientos se clasifican en categorías de nivel 2; % es nivel %',
      new.categoria_id, v_cat.nivel;
  end if;
  if tg_op = 'INSERT' and not v_cat.activo then
    raise exception 'La categoría % está inactiva y no admite movimientos nuevos', new.categoria_id;
  end if;

  select * into v_metodo from finanzas.cat_metodos where id = new.metodo_id;
  if new.es_especie and v_metodo.es_medio_pago_valido then
    raise exception 'Un canje no se paga por un Medio de Pago del sistema financiero; revisa metodo_id = %',
      new.metodo_id;
  end if;

  if new.cuenta_destino_final_id is not null then
    select * into v_destino from finanzas.cat_cuentas where id = new.cuenta_destino_final_id;
    if not v_destino.es_sistema_financiero then
      raise exception 'cuenta_destino_final_id debe ser una cuenta del sistema financiero; % no lo es',
        new.cuenta_destino_final_id;
    end if;
  end if;

  if new.contrapartida_id is not null then
    select * into v_par from finanzas.reg_movimientos where id = new.contrapartida_id;
    if not v_par.es_especie then
      raise exception 'La contrapartida % no está marcada como canje', new.contrapartida_id;
    end if;
    if v_par.tipo = new.tipo then
      raise exception 'La contrapartida de un canje debe ser del tipo opuesto (ambos son %)', new.tipo;
    end if;
    if v_par.monto_pen <> round(new.monto_original * new.tc, 2) then
      raise exception 'El canje debe valorizarse igual en ambos lados: % frente a %',
        round(new.monto_original * new.tc, 2), v_par.monto_pen;
    end if;
  end if;

  return new;
end;
$$;

create trigger tg_mov_valida
  before insert or update on finanzas.reg_movimientos
  for each row execute function finanzas.fn_valida_movimiento();

create trigger tg_mov_sella
  before insert or update on finanzas.reg_movimientos
  for each row execute function finanzas.fn_sella_auditoria();

-- ---------------------------------------------------------------------
-- REG_IMPACTO
-- ---------------------------------------------------------------------
create table finanzas.reg_impacto (
  id              text primary key
                    default 'IMP-' || to_char(now(), 'YYYY') || '-' ||
                            lpad(nextval('finanzas.seq_impacto')::text, 5, '0')
                    check (id ~ '^IMP-[0-9]{4}-[0-9]{5,}$'),
  fecha           date not null,
  beneficiario_id text not null references finanzas.cat_contrapartes (id)
                    on update cascade on delete restrict,
  evento_id       text not null default 'EVT-GENERAL'
                    references public.eventos (id) on update cascade on delete restrict,
  tipo_aporte     finanzas.tipo_aporte not null,
  -- Separa lo recaudado por Trufas de lo facilitado por Trufas.
  pasa_por_caja   boolean not null,
  origen          finanzas.origen_aporte not null,
  monto           numeric(14,2) not null check (monto > 0),
  evidencia_url   text check (evidencia_url is null or evidencia_url ~* '^https?://'),
  publicado       boolean not null default false,
  descripcion     text,

  estado          finanzas.estado_registro not null default 'activo',
  creado_en       timestamptz not null default now(),
  creado_por      uuid,
  creado_por_email text,
  actualizado_en  timestamptz not null default now(),
  actualizado_por uuid,
  anulado_en      timestamptz,
  anulado_por     uuid,
  motivo_anulacion text,

  -- Ninguna cifra pública sin evidencia adjunta.
  constraint ck_imp_publicado_con_evidencia
    check (not publicado or evidencia_url is not null),
  -- Lo que no pasa por caja no lo recaudó Trufas.
  constraint ck_imp_origen_caja
    check (pasa_por_caja = false or origen in ('trufas','donante','comunidad')),
  constraint ck_imp_anulacion_coherente
    check ((estado = 'activo'  and anulado_en is null and motivo_anulacion is null)
        or (estado = 'anulado' and anulado_en is not null and motivo_anulacion is not null))
);

comment on table finanzas.reg_impacto is
  'Impacto verificable. Los premios que el patrocinador entrega directo al ganador van solo aquí, '
  'con origen = patrocinador, para no inflar el P&L del torneo con gasto que Trufas no pagó.';
comment on column finanzas.reg_impacto.pasa_por_caja is
  'Corte entre lo recaudado por Trufas y lo facilitado por Trufas. Sin él ninguna cifra pública es defendible.';
comment on column finanzas.reg_impacto.monto is 'Valorizado en soles. Sin formato de moneda en el dato.';

create index ix_imp_fecha         on finanzas.reg_impacto (fecha);
create index ix_imp_beneficiario  on finanzas.reg_impacto (beneficiario_id);
create index ix_imp_evento        on finanzas.reg_impacto (evento_id);
create index ix_imp_publicable    on finanzas.reg_impacto (fecha)
                                     where publicado and estado = 'activo';

create or replace function finanzas.fn_valida_impacto()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_tipo finanzas.tipo_contraparte;
begin
  select tipo into v_tipo from finanzas.cat_contrapartes where id = new.beneficiario_id;
  if v_tipo <> 'beneficiario' then
    raise exception 'beneficiario_id debe apuntar a una contraparte de tipo beneficiario; % es %',
      new.beneficiario_id, v_tipo;
  end if;
  return new;
end;
$$;

create trigger tg_imp_valida
  before insert or update on finanzas.reg_impacto
  for each row execute function finanzas.fn_valida_impacto();

create trigger tg_imp_sella
  before insert or update on finanzas.reg_impacto
  for each row execute function finanzas.fn_sella_auditoria();

-- ---------------------------------------------------------------------
-- REG_ACUERDOS · el índice del contrato firmado, no el contrato
-- ---------------------------------------------------------------------
create table finanzas.reg_acuerdos (
  id              text primary key
                    default 'ACU-' || to_char(now(), 'YYYY') || '-' ||
                            lpad(nextval('finanzas.seq_acuerdos')::text, 4, '0')
                    check (id ~ '^ACU-[0-9]{4}-[0-9]{4,}$'),
  contraparte_id  text not null references finanzas.cat_contrapartes (id)
                    on update cascade on delete restrict,
  tipo            finanzas.tipo_acuerdo not null,
  evento_id       text not null default 'EVT-GENERAL'
                    references public.eventos (id) on update cascade on delete restrict,
  depto_id        text not null default 'DEP-GENERAL'
                    references finanzas.cat_departamentos (id) on update cascade on delete restrict,
  item_id         text references finanzas.cat_items (id) on update cascade on delete restrict,
  descripcion     text not null check (length(btrim(descripcion)) > 0),

  moneda          finanzas.moneda not null default 'PEN',
  monto_pactado   numeric(14,2) not null check (monto_pactado > 0),
  tc              numeric(12,6) not null default 1 check (tc > 0),
  monto_pactado_pen numeric(14,2)
                    generated always as (round(monto_pactado * tc, 2)) stored,
  incluye_especie boolean not null default false,

  fecha_firma     date,
  fecha_inicio    date not null,
  fecha_fin       date,
  estado_acuerdo  finanzas.estado_acuerdo not null default 'borrador',
  url_contrato    text check (url_contrato is null or url_contrato ~* '^https?://'),

  estado          finanzas.estado_registro not null default 'activo',
  creado_en       timestamptz not null default now(),
  creado_por      uuid,
  creado_por_email text,
  actualizado_en  timestamptz not null default now(),
  actualizado_por uuid,
  anulado_en      timestamptz,
  anulado_por     uuid,
  motivo_anulacion text,

  constraint ck_acu_moneda_tc  check (moneda <> 'PEN' or tc = 1),
  constraint ck_acu_fechas     check (fecha_fin is null or fecha_fin >= fecha_inicio),
  constraint ck_acu_vigente_firmado
    check (estado_acuerdo = 'borrador' or fecha_firma is not null),
  constraint ck_acu_anulacion_coherente
    check ((estado = 'activo'  and anulado_en is null and motivo_anulacion is null)
        or (estado = 'anulado' and anulado_en is not null and motivo_anulacion is not null))
);

comment on table finanzas.reg_acuerdos is
  'Pactado frente a cobrado, y alertas de vencimiento. La fuente de verdad de lo prometido es el '
  'contrato firmado: esta tabla es el índice.';

create index ix_acu_contraparte on finanzas.reg_acuerdos (contraparte_id);
create index ix_acu_evento      on finanzas.reg_acuerdos (evento_id);
create index ix_acu_vigencia    on finanzas.reg_acuerdos (fecha_fin)
                                   where estado_acuerdo = 'vigente' and estado = 'activo';

create trigger tg_acu_sella
  before insert or update on finanzas.reg_acuerdos
  for each row execute function finanzas.fn_sella_auditoria();

-- Cronograma: el flujo de caja proyectado depende de él.
create table finanzas.reg_acuerdo_cuotas (
  id              text primary key,
  acuerdo_id      text not null references finanzas.reg_acuerdos (id)
                    on update cascade on delete restrict,
  nro_cuota       smallint not null check (nro_cuota > 0),
  fecha_prevista  date not null,
  moneda          finanzas.moneda not null default 'PEN',
  monto           numeric(14,2) not null check (monto > 0),
  tc              numeric(12,6) not null default 1 check (tc > 0),
  monto_pen       numeric(14,2) generated always as (round(monto * tc, 2)) stored,
  -- Movimiento que la liquidó. NULL = pendiente de cobro.
  movimiento_id   text references finanzas.reg_movimientos (id)
                    on update cascade on delete restrict,

  estado          finanzas.estado_registro not null default 'activo',
  creado_en       timestamptz not null default now(),
  creado_por      uuid,
  creado_por_email text,
  actualizado_en  timestamptz not null default now(),
  actualizado_por uuid,
  anulado_en      timestamptz,
  anulado_por     uuid,
  motivo_anulacion text,

  constraint uq_cuota_acuerdo unique (acuerdo_id, nro_cuota),
  constraint uq_cuota_movimiento unique (movimiento_id),
  constraint ck_cuota_moneda_tc check (moneda <> 'PEN' or tc = 1),
  constraint ck_cuota_anulacion_coherente
    check ((estado = 'activo'  and anulado_en is null and motivo_anulacion is null)
        or (estado = 'anulado' and anulado_en is not null and motivo_anulacion is not null))
);

comment on table finanzas.reg_acuerdo_cuotas is
  'Cronograma de cobro de cada acuerdo. Alimenta el flujo de caja proyectado y las alertas de '
  'vencimiento; movimiento_id nulo es una cuota que todavía no entró.';

create index ix_cuota_acuerdo on finanzas.reg_acuerdo_cuotas (acuerdo_id);
create index ix_cuota_pendiente on finanzas.reg_acuerdo_cuotas (fecha_prevista)
                                   where movimiento_id is null and estado = 'activo';

create trigger tg_cuota_sella
  before insert or update on finanzas.reg_acuerdo_cuotas
  for each row execute function finanzas.fn_sella_auditoria();

-- ---------------------------------------------------------------------
-- REG_PRESUPUESTO · se congela al aprobarse y nunca se edita
-- ---------------------------------------------------------------------
create table finanzas.reg_presupuesto (
  id              text primary key
                    default 'PRE-' || lpad(nextval('finanzas.seq_presupuesto')::text, 5, '0')
                    check (id ~ '^PRE-[0-9]{5,}$'),
  alcance         finanzas.alcance_presupuesto not null,
  depto_id        text references finanzas.cat_departamentos (id)
                    on update cascade on delete restrict,
  anio            smallint check (anio between 2024 and 2100),
  trimestre       smallint check (trimestre between 1 and 4),
  evento_id       text references public.eventos (id) on update cascade on delete restrict,
  categoria_id    text references finanzas.cat_categorias (id)
                    on update cascade on delete restrict,
  tipo            finanzas.tipo_movimiento not null,
  monto_pen       numeric(14,2) not null check (monto_pen >= 0),
  version         smallint not null default 1 check (version > 0),
  vigente         boolean not null default true,
  congelado_en    timestamptz,
  aprobado_por    text,
  notas           text,

  estado          finanzas.estado_registro not null default 'activo',
  creado_en       timestamptz not null default now(),
  creado_por      uuid,
  creado_por_email text,
  actualizado_en  timestamptz not null default now(),
  actualizado_por uuid,
  anulado_en      timestamptz,
  anulado_por     uuid,
  motivo_anulacion text,

  constraint ck_pre_alcance_departamento
    check (alcance <> 'departamento_trimestre'
        or (depto_id is not null and anio is not null and trimestre is not null and evento_id is null)),
  constraint ck_pre_alcance_evento
    check (alcance <> 'evento'
        or (evento_id is not null and depto_id is null and anio is null and trimestre is null)),
  constraint ck_pre_anulacion_coherente
    check ((estado = 'activo'  and anulado_en is null and motivo_anulacion is null)
        or (estado = 'anulado' and anulado_en is not null and motivo_anulacion is not null))
);

comment on table finanzas.reg_presupuesto is
  'Meta aprobada antes de arrancar. Se congela y nunca se edita: si se ajustara cuando la realidad '
  'cambia, el KPI de variación siempre daría cerca de cero. Los cambios entran como versiones nuevas.';
comment on column finanzas.reg_presupuesto.categoria_id is
  'NULL = presupuesto total del alcance. Con valor = presupuesto de esa categoría de nivel 2.';
comment on column finanzas.reg_presupuesto.congelado_en is
  'Marca de aprobación. Una vez puesta, los montos y las llaves del alcance dejan de ser editables.';

create unique index uq_pre_depto_vigente
  on finanzas.reg_presupuesto (depto_id, anio, trimestre, tipo, coalesce(categoria_id, '*'))
  where alcance = 'departamento_trimestre' and vigente and estado = 'activo';

create unique index uq_pre_evento_vigente
  on finanzas.reg_presupuesto (evento_id, tipo, coalesce(categoria_id, '*'))
  where alcance = 'evento' and vigente and estado = 'activo';

create index ix_pre_depto_periodo on finanzas.reg_presupuesto (depto_id, anio, trimestre);
create index ix_pre_evento        on finanzas.reg_presupuesto (evento_id);

create or replace function finanzas.fn_presupuesto_congelado()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.congelado_en is null then
    return new;
  end if;

  if new.monto_pen                       is distinct from old.monto_pen
     or new.alcance                      is distinct from old.alcance
     or new.depto_id                     is distinct from old.depto_id
     or new.evento_id                    is distinct from old.evento_id
     or new.categoria_id                 is distinct from old.categoria_id
     or new.anio                         is distinct from old.anio
     or new.trimestre                    is distinct from old.trimestre
     or new.tipo                         is distinct from old.tipo
     or new.version                      is distinct from old.version
     or new.congelado_en                 is distinct from old.congelado_en then
    raise exception
      'El presupuesto % está congelado desde %. Registra una versión nueva en lugar de editarlo.',
      old.id, old.congelado_en;
  end if;

  return new;
end;
$$;

create trigger tg_pre_congelado
  before update on finanzas.reg_presupuesto
  for each row execute function finanzas.fn_presupuesto_congelado();

create trigger tg_pre_sella
  before insert or update on finanzas.reg_presupuesto
  for each row execute function finanzas.fn_sella_auditoria();
