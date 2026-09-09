-- =====================================================================
-- Inspección del proyecto destino antes de trasladar finanzas
--
-- Read-only. No modifica nada. Ejecutar como owner en el proyecto
-- destino (Website, ref tpcbzddxwqypvckvvbfa) ANTES de aplicar ninguna
-- migración.
--
-- El riesgo de todo el traslado es public.eventos: ya existe, tiene
-- filas de producción que sirven la landing, y las migraciones asumen
-- que las crean ellas. Esto responde qué forma tiene realmente.
-- =====================================================================

-- 1 · ¿Existe la tabla, y cuántas filas tiene?
select 'eventos existe' pregunta,
       coalesce(to_regclass('public.eventos')::text, 'NO EXISTE') respuesta;

-- 2 · Tipo de la clave primaria. Es la decisión que define todo el resto:
--     si no es text, las llaves foráneas de finanzas hay que adaptarlas
--     en lugar de cambiar la PK de una tabla en producción.
select a.attname columna,
       format_type(a.atttypid, a.atttypmod) tipo,
       a.attnotnull as no_nulo,
       pg_get_expr(d.adbin, d.adrelid) as valor_por_defecto
from pg_attribute a
left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
where a.attrelid = 'public.eventos'::regclass
  and a.attnum > 0 and not a.attisdropped
order by a.attnum;

-- 3 · Qué columnas de las que finanzas necesita ya están y cuáles faltan
select c as columna,
       case when exists (
         select 1 from pg_attribute
          where attrelid = 'public.eventos'::regclass
            and attname = c and attnum > 0 and not attisdropped
       ) then 'presente' else 'FALTA' end as estado
from unnest(array['id','nombre','slug','descripcion','juego','nivel','region','ciclo',
                  'modalidad','fecha_inicio','fecha_fin','estado','publicado',
                  'url_publica','creado_en','actualizado_en']) as c;

-- 4 · Restricciones vigentes
select conname, contype, pg_get_constraintdef(oid) definicion
from pg_constraint
where conrelid = 'public.eventos'::regclass
order by contype, conname;

-- 5 · RLS y políticas. Hay que no romper lo que la landing ya usa.
select c.relrowsecurity as rls_activo, c.relforcerowsecurity as rls_forzado
from pg_class c where c.oid = 'public.eventos'::regclass;

select policyname, permissive, roles, cmd, qual as using_expr, with_check
from pg_policies where schemaname = 'public' and tablename = 'eventos'
order by cmd, policyname;

-- 6 · Grants vigentes: qué puede hacer anon hoy
select grantee, string_agg(distinct privilege_type, ',' order by privilege_type) privilegios
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'eventos'
group by grantee order by grantee;

-- 7 · Qué depende de la tabla (vistas, funciones, triggers).
--     Si la landing lee por una vista, alterar la tabla puede romperla.
select distinct dependiente.relname as objeto, dependiente.relkind as tipo
from pg_depend d
join pg_rewrite r on r.oid = d.objid
join pg_class dependiente on dependiente.oid = r.ev_class
where d.refobjid = 'public.eventos'::regclass
  and dependiente.relname <> 'eventos';

select tgname trigger_nombre, pg_get_triggerdef(oid) definicion
from pg_trigger where tgrelid = 'public.eventos'::regclass and not tgisinternal;

-- 8 · ¿Los schemas de finanzas ya existen ahí? No deberían.
select nspname schema_existente
from pg_namespace
where nspname in ('finanzas','auditoria','metricas','desempeno')
order by nspname;

-- 9 · Las filas reales. Esto es lo que hay que respaldar antes de tocar nada.
select * from public.eventos order by 1;
