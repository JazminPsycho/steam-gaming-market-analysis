-- =====================================================================
-- Purga de los datos de prueba de finanzas_0009
--
-- DELETE está revocado para anon, authenticated y service_role, así que
-- esto SOLO corre como owner (postgres) desde el SQL Editor del Studio.
--
-- NO borra eventos: la migración no los creó. En el proyecto Website los
-- eventos son los reales de la landing, y tocarlos sería borrar la
-- portada. Lo único que se limpia del lado de eventos son sus atributos
-- de gestión, que sí son de finanzas.
--
-- EVT-GENERAL tampoco se borra: no es un dato de prueba, es la fila
-- técnica que exige la regla de que todo movimiento lleva evento_id.
-- Si de verdad se quiere sacar, hay que borrarla al final y solo cuando
-- no quede ninguna fila de registro apuntándole.
--
-- El orden respeta las llaves foráneas: las cuotas apuntan a los
-- movimientos, y los dos lados de un canje se apuntan entre sí, así que
-- primero hay que soltar contrapartida_id.
-- =====================================================================

begin;

-- Cronograma antes que los movimientos que liquidó
delete from finanzas.reg_acuerdo_cuotas where id like 'CUO-%';
delete from finanzas.reg_acuerdos       where descripcion like '[PRUEBA]%';

delete from finanzas.reg_impacto        where descripcion like '[PRUEBA]%';
delete from finanzas.reg_presupuesto    where notas       like '[PRUEBA]%';

-- Soltar el emparejamiento de canjes antes de borrar
update finanzas.reg_movimientos set contrapartida_id = null
 where contrapartida_id is not null;
delete from finanzas.reg_movimientos    where descripcion like '[PRUEBA]%';

delete from finanzas.cat_contrapartes   where notas       like '[PRUEBA]%';

-- Atributos de gestión de los eventos. Los eventos NO se tocan.
delete from finanzas.eventos_atributos  where notas       like '[PRUEBA]%';

-- El log de auditoría de esas filas. Omitir si se quiere conservar el
-- rastro de que los datos de prueba existieron.
delete from auditoria.log_cambios
 where (fila_nueva    ->> 'descripcion') like '[PRUEBA]%'
    or (fila_anterior ->> 'descripcion') like '[PRUEBA]%'
    or (fila_nueva    ->> 'notas')       like '[PRUEBA]%'
    or (fila_anterior ->> 'notas')       like '[PRUEBA]%';

-- Reposicionar las secuencias
select setval('finanzas.seq_movimientos',  coalesce((select max(right(id, 6)::bigint) from finanzas.reg_movimientos), 1));
select setval('finanzas.seq_impacto',      coalesce((select max(right(id, 5)::bigint) from finanzas.reg_impacto), 1));
select setval('finanzas.seq_acuerdos',     coalesce((select max(right(id, 4)::bigint) from finanzas.reg_acuerdos), 1));
select setval('finanzas.seq_presupuesto',  coalesce((select max(right(id, 5)::bigint) from finanzas.reg_presupuesto), 1));
select setval('finanzas.seq_contrapartes', coalesce((select max(right(id, 4)::bigint) from finanzas.cat_contrapartes), 1));

-- Debe devolver 0 en las cinco tablas de registro, y los eventos intactos
select 'reg_movimientos' t, count(*) n from finanzas.reg_movimientos
union all select 'reg_impacto',        count(*) from finanzas.reg_impacto
union all select 'reg_acuerdos',       count(*) from finanzas.reg_acuerdos
union all select 'reg_acuerdo_cuotas', count(*) from finanzas.reg_acuerdo_cuotas
union all select 'reg_presupuesto',    count(*) from finanzas.reg_presupuesto
union all select 'eventos_atributos',  count(*) from finanzas.eventos_atributos
union all select 'EVENTOS (no se tocan)', count(*) from public.eventos
union all select 'eventos visibles en la portada', count(*) from public.eventos where not oculto;

-- Revisar el resultado antes de confirmar.
-- Los eventos visibles deben seguir siendo los mismos que antes de purgar.
-- commit;
rollback;
