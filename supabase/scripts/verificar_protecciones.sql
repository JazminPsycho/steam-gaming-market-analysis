-- =====================================================================
-- Verificación de las protecciones · Somos Trufas
--
-- 18 pruebas que confirman que RLS, REVOKE DELETE, los triggers de
-- negocio y la auditoría hacen lo que dicen hacer. Incluye controles
-- negativos (lo que debe bloquearse) y positivos (lo que debe permitirse:
-- una protección que bloquea a todos no es una protección, es un muro).
--
-- Ejecutar como owner (postgres) desde el SQL Editor del Studio.
-- Todo lo que crea lo limpia al final. Un veredicto distinto de PASA
-- significa que una protección se rompió: no desplegar así.
--
-- No necesita usuarios en Auth: usa el respaldo del claim
-- app_metadata.rol para simular cada rol de aplicación.
-- =====================================================================

create temp table if not exists _res(orden int, prueba text, esperado text, obtenido text);
truncate _res;

do $$
declare
  v_msg text; v_n int; v_log_antes bigint; v_log_despues bigint;
  v_canje text; v_mov text; v_pre_congelado text; v_pre_libre text;
  c_ops text := '{"sub":"00000000-0000-0000-0000-000000000001","app_metadata":{"rol":"operaciones"}}';
  c_con text := '{"sub":"00000000-0000-0000-0000-000000000002","app_metadata":{"rol":"contable"}}';
  c_fin text := '{"sub":"00000000-0000-0000-0000-000000000004","app_metadata":{"rol":"finanzas"}}';
  c_adm text := '{"sub":"00000000-0000-0000-0000-000000000005","app_metadata":{"rol":"admin"}}';
  c_sin text := '{"sub":"00000000-0000-0000-0000-000000000003","app_metadata":{}}';
begin
  -- Ids derivados de los datos, no fijos: así el script sirve en
  -- cualquier proyecto donde esté instalado el sistema.
  select id into v_canje from finanzas.reg_movimientos
   where es_especie and contrapartida_id is not null and estado = 'activo'
   order by id limit 1;
  select id into v_mov from finanzas.reg_movimientos
   where estado_flujo = 'ejecutado' and estado = 'activo' and not es_especie
   order by id limit 1;
  select id into v_pre_congelado from finanzas.reg_presupuesto
   where congelado_en is not null and estado = 'activo' order by id limit 1;
  select id into v_pre_libre from finanzas.reg_presupuesto
   where congelado_en is null and estado = 'activo' order by id limit 1;

  if v_canje is null or v_mov is null or v_pre_congelado is null or v_pre_libre is null then
    raise exception 'Faltan datos para las pruebas: canje=% mov=% congelado=% libre=%',
      v_canje, v_mov, v_pre_congelado, v_pre_libre;
  end if;

  -- 1 · Los cuatro roles insertan movimientos
  perform set_config('request.jwt.claims', c_ops, true);
  perform set_config('role','authenticated',true);
  begin
    insert into finanzas.reg_movimientos (id, fecha_prevista, tipo, categoria_id, descripcion, monto_original, metodo_id)
    values ('MOV-2026-999001','2026-09-10','egreso','CAT-E-09-01','[PRUEBA-RLS] alta por operaciones', 50, 'MTD-EFECTIVO');
    v_msg := 'insertó';
  exception when others then v_msg := 'FALLÓ: ' || sqlerrm; end;
  perform set_config('role','postgres',true);
  insert into _res values (1,'operaciones inserta movimiento','insertó',v_msg);

  -- 2 · operaciones es "insertar y lectura total": no actualiza
  perform set_config('request.jwt.claims', c_ops, true);
  perform set_config('role','authenticated',true);
  begin
    update finanzas.reg_movimientos set descripcion = descripcion || ' (x)' where id = 'MOV-2026-999001';
    get diagnostics v_n = row_count; v_msg := v_n || ' filas';
  exception when others then v_msg := 'error: ' || sqlerrm; end;
  perform set_config('role','postgres',true);
  insert into _res values (2,'operaciones actualiza movimiento','0 filas',v_msg);

  -- 3 · contable actualiza filas activas
  perform set_config('request.jwt.claims', c_con, true);
  perform set_config('role','authenticated',true);
  begin
    update finanzas.reg_movimientos set descripcion = descripcion || ' · conciliado' where id = 'MOV-2026-999001';
    get diagnostics v_n = row_count; v_msg := v_n || ' filas';
  exception when others then v_msg := 'error: ' || sqlerrm; end;
  perform set_config('role','postgres',true);
  insert into _res values (3,'contable actualiza movimiento activo','1 filas',v_msg);

  -- 4 · Anular es exclusivo del admin
  perform set_config('request.jwt.claims', c_con, true);
  perform set_config('role','authenticated',true);
  begin
    update finanzas.reg_movimientos set estado='anulado', motivo_anulacion='[PRUEBA-RLS] intento' where id = 'MOV-2026-999001';
    get diagnostics v_n = row_count; v_msg := 'PERMITIÓ anular (' || v_n || ')';
  exception when others then v_msg := 'bloqueado'; end;
  perform set_config('role','postgres',true);
  insert into _res values (4,'contable anula movimiento','bloqueado',v_msg);

  -- 5 · CONTROL POSITIVO: el admin sí anula
  perform set_config('request.jwt.claims', c_adm, true);
  perform set_config('role','authenticated',true);
  begin
    update finanzas.reg_movimientos set estado='anulado', motivo_anulacion='[PRUEBA-RLS] anulado por admin' where id = 'MOV-2026-999001';
    get diagnostics v_n = row_count; v_msg := v_n || ' filas';
  exception when others then v_msg := 'FALLÓ: ' || sqlerrm; end;
  perform set_config('role','postgres',true);
  insert into _res values (5,'admin anula movimiento','1 filas',v_msg);

  -- 6 · Una fila anulada queda fuera del alcance de los demás roles
  perform set_config('request.jwt.claims', c_con, true);
  perform set_config('role','authenticated',true);
  begin
    update finanzas.reg_movimientos set descripcion = descripcion || ' (y)' where id = 'MOV-2026-999001';
    get diagnostics v_n = row_count; v_msg := v_n || ' filas';
  exception when others then v_msg := 'error'; end;
  perform set_config('role','postgres',true);
  insert into _res values (6,'contable actualiza fila anulada','0 filas',v_msg);

  -- 7 · El presupuesto lo aprueban admin y finanzas, no contable
  perform set_config('request.jwt.claims', c_con, true);
  perform set_config('role','authenticated',true);
  begin
    insert into finanzas.reg_presupuesto (id, alcance, depto_id, anio, trimestre, tipo, monto_pen)
    values ('PRE-99001','departamento_trimestre','DEP-ESPORTS',2027,1,'egreso',1000);
    v_msg := 'PERMITIÓ insertar';
  exception when others then v_msg := 'bloqueado'; end;
  perform set_config('role','postgres',true);
  insert into _res values (7,'contable inserta presupuesto','bloqueado',v_msg);

  -- 8 · CONTROL POSITIVO: finanzas sí aprueba presupuesto
  perform set_config('request.jwt.claims', c_fin, true);
  perform set_config('role','authenticated',true);
  begin
    insert into finanzas.reg_presupuesto (id, alcance, depto_id, anio, trimestre, tipo, monto_pen)
    values ('PRE-99002','departamento_trimestre','DEP-ESPORTS',2027,1,'egreso',1000);
    v_msg := 'insertó';
  exception when others then v_msg := 'FALLÓ: ' || sqlerrm; end;
  perform set_config('role','postgres',true);
  insert into _res values (8,'finanzas inserta presupuesto','insertó',v_msg);

  -- 9 · Sin rol de aplicación no se ve nada
  perform set_config('request.jwt.claims', c_sin, true);
  perform set_config('role','authenticated',true);
  begin
    select count(*) into v_n from finanzas.reg_movimientos; v_msg := v_n || ' filas visibles';
  exception when others then v_msg := 'error'; end;
  perform set_config('role','postgres',true);
  insert into _res values (9,'JWT sin rol lee movimientos','0 filas visibles',v_msg);

  -- 10 · Nadie borra, ni el admin. Falla por privilegio, no por política
  --      vacía: una política se puede añadir por error, un privilegio
  --      revocado no.
  perform set_config('request.jwt.claims', c_adm, true);
  perform set_config('role','authenticated',true);
  begin
    delete from finanzas.reg_movimientos where id = 'MOV-2026-999001'; v_msg := 'PERMITIÓ borrar';
  exception when insufficient_privilege then v_msg := 'privilegio denegado';
            when others then v_msg := 'otro error'; end;
  perform set_config('role','postgres',true);
  insert into _res values (10,'incluso admin borra movimiento','privilegio denegado',v_msg);

  -- 11 · TRUNCATE pasa por encima de DELETE y de RLS: también revocado
  perform set_config('role','authenticated',true);
  begin
    execute 'truncate finanzas.reg_movimientos'; v_msg := 'PERMITIÓ truncar';
  exception when insufficient_privilege then v_msg := 'privilegio denegado';
            when others then v_msg := 'otro error'; end;
  perform set_config('role','postgres',true);
  insert into _res values (11,'authenticated trunca tabla','privilegio denegado',v_msg);

  -- 12 · El presupuesto congelado es la línea base y no se reescribe
  begin
    update finanzas.reg_presupuesto set monto_pen = 9999 where id = v_pre_congelado; v_msg := 'PERMITIÓ editar';
  exception when others then v_msg := 'bloqueado'; end;
  insert into _res values (12,'editar presupuesto congelado','bloqueado',v_msg);

  -- 13 · CONTROL POSITIVO: sin congelar sí se edita.
  --      Una protección que bloquea a todos no es una protección, es un muro.
  begin
    update finanzas.reg_presupuesto set monto_pen = monto_pen + 1 where id = v_pre_libre;
    get diagnostics v_n = row_count; v_msg := v_n || ' filas';
  exception when others then v_msg := 'error: ' || split_part(sqlerrm, chr(10), 1); end;
  insert into _res values (13,'editar presupuesto sin congelar','1 filas',v_msg);

  -- 15 · Un canje se valoriza igual en ambos lados
  begin
    update finanzas.reg_movimientos set monto_original = monto_original + 500 where id = v_canje; v_msg := 'PERMITIÓ descuadrar';
  exception when others then v_msg := 'bloqueado'; end;
  insert into _res values (14,'descuadrar valorización de un canje','bloqueado',v_msg);

  -- 15 · Los movimientos se clasifican en nivel 2
  begin
    insert into finanzas.reg_movimientos (fecha_prevista, tipo, categoria_id, descripcion, monto_original, metodo_id)
    values ('2026-09-10','egreso','CAT-E-09','[PRUEBA-RLS] nivel 1', 10, 'MTD-EFECTIVO'); v_msg := 'PERMITIÓ nivel 1';
  exception when others then v_msg := 'bloqueado'; end;
  insert into _res values (15,'clasificar movimiento en nivel 1','bloqueado',v_msg);

  -- 16 · Un ingreso no cae en categoría de egreso (FK compuesta)
  begin
    insert into finanzas.reg_movimientos (fecha_prevista, tipo, categoria_id, descripcion, monto_original, metodo_id)
    values ('2026-09-10','ingreso','CAT-E-09-01','[PRUEBA-RLS] tipo cruzado', 10, 'MTD-EFECTIVO'); v_msg := 'PERMITIÓ tipo cruzado';
  exception when others then v_msg := 'bloqueado'; end;
  insert into _res values (16,'ingreso en categoría de egreso','bloqueado',v_msg);

  -- 17 · Un UPDATE que solo mueve el sello no ensucia el log
  select count(*) into v_log_antes from auditoria.log_cambios;
  update finanzas.reg_movimientos set descripcion = descripcion where id = v_mov;
  select count(*) into v_log_despues from auditoria.log_cambios;
  insert into _res values (17,'UPDATE sin cambio real deja log','0 filas nuevas',(v_log_despues - v_log_antes) || ' filas nuevas');

  -- 18 · Un UPDATE real deja una fila con los campos exactos
  select count(*) into v_log_antes from auditoria.log_cambios;
  update finanzas.reg_movimientos set igv = 400.00 where id = v_mov;
  select count(*) into v_log_despues from auditoria.log_cambios;
  select array_to_string(campos_cambiados, ',') into v_msg from auditoria.log_cambios
   where registro_id = v_mov and operacion = 'UPDATE' order by id desc limit 1;
  insert into _res values (18,'UPDATE real deja log con campos_cambiados','1 fila · igv',(v_log_despues - v_log_antes) || ' fila · ' || v_msg);

  -- Limpieza
  update finanzas.reg_movimientos set igv = null where id = v_mov;
  update finanzas.reg_presupuesto set monto_pen = monto_pen - 1 where id = v_pre_libre;
  delete from finanzas.reg_movimientos where id like 'MOV-2026-9990%';
  delete from finanzas.reg_presupuesto where id like 'PRE-9900%';
  delete from auditoria.log_cambios where registro_id like 'MOV-2026-9990%' or registro_id like 'PRE-9900%';
end;
$$;

select orden, prueba, esperado, obtenido,
       case when obtenido = esperado then 'PASA' else '*** REVISAR ***' end as veredicto
from _res order by orden;
