-- =====================================================================
-- Purga de los datos de prueba de 0009
--
-- DELETE está revocado para anon, authenticated y service_role, así que
-- esto SOLO corre como owner (postgres) desde el SQL Editor del Studio.
--
-- El orden respeta las llaves foráneas: las cuotas apuntan a los
-- movimientos, y los movimientos de un canje se apuntan entre sí, así
-- que primero hay que soltar contrapartida_id.
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
delete from public.eventos              where descripcion like '[PRUEBA]%';

-- El log de auditoría de esas filas. Omitir estas dos líneas si se
-- quiere conservar el rastro de que los datos de prueba existieron.
delete from auditoria.log_cambios
 where (fila_nueva ->> 'descripcion') like '[PRUEBA]%'
    or (fila_anterior ->> 'descripcion') like '[PRUEBA]%';

-- Reposicionar las secuencias
select setval('finanzas.seq_movimientos',  coalesce((select max(right(id, 6)::bigint) from finanzas.reg_movimientos), 1));
select setval('finanzas.seq_impacto',      coalesce((select max(right(id, 5)::bigint) from finanzas.reg_impacto), 1));
select setval('finanzas.seq_acuerdos',     coalesce((select max(right(id, 4)::bigint) from finanzas.reg_acuerdos), 1));
select setval('finanzas.seq_presupuesto',  coalesce((select max(right(id, 5)::bigint) from finanzas.reg_presupuesto), 1));
select setval('finanzas.seq_contrapartes', coalesce((select max(right(id, 4)::bigint) from finanzas.cat_contrapartes), 1));

-- Debe devolver 0 en las cinco tablas de registro
select 'reg_movimientos' t, count(*) n from finanzas.reg_movimientos
union all select 'reg_impacto',        count(*) from finanzas.reg_impacto
union all select 'reg_acuerdos',       count(*) from finanzas.reg_acuerdos
union all select 'reg_acuerdo_cuotas', count(*) from finanzas.reg_acuerdo_cuotas
union all select 'reg_presupuesto',    count(*) from finanzas.reg_presupuesto;

-- Revisar el resultado antes de confirmar.
-- commit;
rollback;
