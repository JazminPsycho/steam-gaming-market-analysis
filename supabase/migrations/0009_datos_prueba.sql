-- =====================================================================
-- 0009 · Datos de prueba · 100 filas de registro
--
--   reg_movimientos       55
--   reg_impacto           14
--   reg_acuerdos           8
--   reg_acuerdo_cuotas    13
--   reg_presupuesto       10
--                        ---
--                        100
--
-- Más los catálogos de apoyo que hacen falta para que existan: 8 eventos
-- y 20 contrapartes. Todo marcado con [PRUEBA] en descripcion o notas.
--
-- Los montos con comprobante incluyen IGV; la columna igv guarda la
-- parte que corresponde (monto / 1.18 * 0.18). Los recibos por
-- honorarios de cuarta categoría van sin IGV.
--
-- Cómo purgar: ver supabase/README.md. DELETE está revocado incluso para
-- service_role, así que la purga corre como owner postgres.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Eventos de apoyo
-- ---------------------------------------------------------------------
insert into public.eventos
  (id, nombre, slug, descripcion, juego, nivel, region, ciclo, modalidad,
   fecha_inicio, fecha_fin, estado, publicado) values
  ('EVT-2025-001', 'Copa Trufa Invierno',        'copa-trufa-invierno-2025',
   '[PRUEBA] Torneo comunitario de apertura del ciclo.',
   'League of Legends', 'comunidad',    'PE',    '2025-S2', 'online',
   '2025-07-12', '2025-07-13', 'finalizado', true),
  ('EVT-2025-002', 'Valorant Trufa Open',        'valorant-trufa-open-2025',
   '[PRUEBA] Open casual de Valorant para la comunidad.',
   'Valorant',          'casual',       'PE',    '2025-S2', 'online',
   '2025-08-23', '2025-08-24', 'finalizado', true),
  ('EVT-2025-003', 'Liga Trufa Clausura',        'liga-trufa-clausura-2025',
   '[PRUEBA] Liga competitiva de cierre de temporada.',
   'League of Legends', 'competitivo',  'LATAM', '2025-S2', 'online',
   '2025-10-04', '2025-11-15', 'finalizado', true),
  ('EVT-2025-004', 'Trufa Fest Lima',            'trufa-fest-lima-2025',
   '[PRUEBA] Festival presencial multi-título con venta de entradas.',
   'Multi-título',      'comunidad',    'PE',    '2025-S2', 'presencial',
   '2025-12-06', '2025-12-07', 'finalizado', true),
  ('EVT-2026-001', 'Copa Trufa Verano',          'copa-trufa-verano-2026',
   '[PRUEBA] Copa competitiva de Valorant.',
   'Valorant',          'competitivo',  'PE',    '2026-S1', 'online',
   '2026-02-14', '2026-02-15', 'finalizado', true),
  ('EVT-2026-002', 'Liga Trufa Apertura',        'liga-trufa-apertura-2026',
   '[PRUEBA] Liga competitiva regional, evento principal del ciclo.',
   'League of Legends', 'competitivo',  'LATAM', '2026-S1', 'online',
   '2026-04-11', '2026-06-20', 'finalizado', true),
  ('EVT-2026-003', 'Creadores Trufa Showmatch',  'creadores-trufa-showmatch-2026',
   '[PRUEBA] Showmatch con creadores de contenido, en curso.',
   'Multi-título',      'casual',       'PE',    '2026-S2', 'hibrido',
   '2026-09-05', '2026-09-26', 'en_curso', true),
  ('EVT-2026-004', 'Trufa Invitational',         'trufa-invitational-2026',
   '[PRUEBA] Invitational profesional presencial. Todavía en planificación.',
   'Valorant',          'profesional',  'LATAM', '2026-S2', 'presencial',
   '2026-11-21', '2026-11-22', 'planificado', false);

-- ---------------------------------------------------------------------
-- Contrapartes de apoyo · los cinco tipos
-- Se asignan ids explícitos para que los movimientos sean legibles;
-- la secuencia se reposiciona al final.
-- ---------------------------------------------------------------------
insert into finanzas.cat_contrapartes
  (id, tipo, nombre, razon_social, tipo_documento, numero_documento, email, pais, notas) values
  ('CTP-0001', 'patrocinador', 'Aurora Tech Perú',        'Aurora Tech Perú S.A.C.',       'RUC', '20601234561', 'alianzas@aurora.test',   'PE', '[PRUEBA] Patrocinador principal del ciclo.'),
  ('CTP-0002', 'patrocinador', 'Cripto Andina',           'Cripto Andina S.A.C.',          'RUC', '20601234562', 'marketing@criptoandina.test', 'PE', '[PRUEBA] Paga en USDT. Requiere puente documentado al banco.'),
  ('CTP-0003', 'patrocinador', 'Energética Wayra',        'Energética Wayra S.A.',         'RUC', '20601234563', 'brand@wayra.test',       'PE', '[PRUEBA] Naming de torneo.'),
  ('CTP-0004', 'patrocinador', 'Periféricos Kuntur',      'Periféricos Kuntur S.A.C.',     'RUC', '20601234564', 'canjes@kuntur.test',     'PE', '[PRUEBA] Trabaja por canje y por referidos.'),
  ('CTP-0005', 'patrocinador', 'Café Tostado Quilla',     'Café Tostado Quilla E.I.R.L.',  'RUC', '20601234565', 'hola@quilla.test',       'PE', '[PRUEBA] Paquete de temporada.'),
  ('CTP-0006', 'patrocinador', 'Telecom Sierra Norte',    'Telecom Sierra Norte S.A.C.',   'RUC', '20601234566', 'patrocinios@tsn.test',   'PE', '[PRUEBA] Activaciones puntuales, cobra por PayPal.'),
  ('CTP-0007', 'proveedor',    'Estudio Ronda',           'Estudio Ronda S.A.C.',          'RUC', '20601234567', 'produccion@ronda.test',  'PE', '[PRUEBA] Producción audiovisual.'),
  ('CTP-0008', 'proveedor',    'Plataforma de torneos',   null,                            null,  null,          null,                     'US', '[PRUEBA] Suscripción a la plataforma de brackets.'),
  ('CTP-0009', 'proveedor',    'Salón Miraflores',        'Inversiones Salón Miraflores S.A.C.', 'RUC', '20601234569', 'reservas@salonmf.test', 'PE', '[PRUEBA] Alquiler de local para eventos presenciales.'),
  ('CTP-0010', 'proveedor',    'Nube Andina Hosting',     'Nube Andina S.A.C.',            'RUC', '20601234570', 'soporte@nubeandina.test','PE', '[PRUEBA] Hosting y dominios.'),
  ('CTP-0011', 'proveedor',    'Contadores Asociados',    'Contadores Asociados S.C.R.L.', 'RUC', '20601234571', 'estudio@contadores.test','PE', '[PRUEBA] Servicio contable. Sustituir por el contador que se contrate.'),
  ('CTP-0012', 'colaborador',  'Diego Salas',             null,                            'DNI', '45781234',    'diego@casters.test',     'PE', '[PRUEBA] Caster principal. Recibo por honorarios.'),
  ('CTP-0013', 'colaborador',  'Lucía Ferrer',            null,                            'DNI', '45781235',    'lucia@contenido.test',   'PE', '[PRUEBA] Community manager y producción de contenido.'),
  ('CTP-0014', 'colaborador',  'Renzo Ocampo',            null,                            'DNI', '45781236',    'renzo@diseno.test',      'PE', '[PRUEBA] Diseño y branding.'),
  ('CTP-0015', 'colaborador',  'Mateo Rivas',             null,                            'DNI', '45781237',    'mateo@observer.test',    'PE', '[PRUEBA] Observer de transmisión.'),
  ('CTP-0016', 'beneficiario', 'Albergue San Martín',     null,                            'RUC', '20601234576', 'contacto@albergue.test', 'PE', '[PRUEBA] Beneficiario del fondo benéfico.'),
  ('CTP-0017', 'beneficiario', 'Comedor Villa El Salvador', null,                          'RUC', '20601234577', 'comedor@villa.test',     'PE', '[PRUEBA] Beneficiario del fondo benéfico.'),
  ('CTP-0018', 'beneficiario', 'Biblioteca Comunitaria Ate', null,                         'RUC', '20601234578', 'biblioteca@ate.test',    'PE', '[PRUEBA] Beneficiario del fondo benéfico.'),
  ('CTP-0019', 'donante',      'Comunidad Somos Trufas',  null,                            'SIN_DOCUMENTO', null, null,                     'PE', '[PRUEBA] Agregado de tips y donaciones de la comunidad.'),
  ('CTP-0020', 'donante',      'Donante particular',      null,                            'DNI', '45781240',    null,                     'PE', '[PRUEBA] Donación puntual.');

select setval('finanzas.seq_contrapartes', 20);

-- =====================================================================
-- REG_MOVIMIENTOS · 55 filas
-- Ids explícitos para que el emparejamiento de canjes sea determinista.
-- =====================================================================
insert into finanzas.reg_movimientos
  (id, fecha_prevista, fecha_efectiva, estado_flujo, tipo, categoria_id,
   contraparte_id, atribuido_a_id, evento_id, depto_id, fondo_id, item_id,
   descripcion, moneda, monto_original, tc,
   cuenta_id, cuenta_destino_final_id, metodo_id,
   es_especie, es_activo_fijo, comprobante_tipo, comprobante_nro, igv, url_respaldo) values

-- EVT-2025-001 Copa Trufa Invierno
('MOV-2026-000001','2025-07-01','2025-07-05','ejecutado','ingreso','CAT-I-01-01','CTP-0006',null,'EVT-2025-001','DEP-ESPORTS','FND-OPERATIVO','ITM-PAQ-BRONCE','[PRUEBA] Paquete Bronce Telecom Sierra Norte — Copa Invierno','PEN',2500,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F001-00008',381.36,'https://drive.test/trufas/F001-00008.pdf'),
('MOV-2026-000002','2025-07-14','2025-07-14','ejecutado','egreso','CAT-E-01-01',null,null,'EVT-2025-001','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Premio en efectivo campeón Copa Invierno','PEN',1500,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),

-- EVT-2025-002 Valorant Trufa Open
('MOV-2026-000003','2025-08-24','2025-08-24','ejecutado','ingreso','CAT-I-04-01','CTP-0019',null,'EVT-2025-002','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tips de la comunidad durante la transmisión del Open','PEN',380,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),
('MOV-2026-000004','2025-08-25','2025-08-25','ejecutado','egreso','CAT-E-02-01','CTP-0012',null,'EVT-2025-002','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Casteo del Valorant Trufa Open','PEN',900,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'recibo_honorarios','RH-0071',null,null),

-- EVT-2025-003 Liga Trufa Clausura
('MOV-2026-000005','2025-10-05','2025-10-08','ejecutado','ingreso','CAT-I-01-01','CTP-0001',null,'EVT-2025-003','DEP-ESPORTS','FND-OPERATIVO','ITM-PAQ-ORO','[PRUEBA] Paquete Oro Aurora Tech — primera cuota del acuerdo anual','PEN',12000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F001-00012',1830.51,'https://drive.test/trufas/F001-00012.pdf'),
('MOV-2026-000006','2025-10-10','2025-10-10','ejecutado','ingreso','CAT-I-01-03','CTP-0003',null,'EVT-2025-003','DEP-ESPORTS','FND-OPERATIVO','ITM-NAMING','[PRUEBA] Naming Energética Wayra — Liga Trufa Clausura','PEN',20000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F001-00013',3050.85,'https://drive.test/trufas/F001-00013.pdf'),
('MOV-2026-000007','2025-11-15','2025-11-15','ejecutado','ingreso','CAT-I-03-01',null,null,'EVT-2025-003','DEP-OPERACIONES','FND-OPERATIVO','ITM-ENT-GENERAL','[PRUEBA] Entradas generales de la final, agregado del día','PEN',3480,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'boleta','B001-00340',530.85,null),
('MOV-2026-000008','2025-11-16','2025-11-16','ejecutado','egreso','CAT-E-01-01',null,null,'EVT-2025-003','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Premios en efectivo Liga Clausura — primer y segundo puesto','PEN',6000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000009','2025-11-16','2025-11-16','ejecutado','egreso','CAT-E-02-01','CTP-0012',null,'EVT-2025-003','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Casteo de las seis jornadas de la Liga Clausura','PEN',2400,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'recibo_honorarios','RH-0087',null,null),
('MOV-2026-000010','2025-10-05','2025-10-05','ejecutado','egreso','CAT-E-02-02','CTP-0008',null,'EVT-2025-003','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Plataforma de brackets — temporada Clausura','PEN',950,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'factura','F-8891',144.92,null),
('MOV-2026-000011','2025-10-06','2025-10-06','ejecutado','egreso','CAT-E-03-03','CTP-0014','CTP-0003','EVT-2025-003','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Arte del naming Wayra: overlay, piezas y bumpers','PEN',1500,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'recibo_honorarios','RH-0083',null,null),
('MOV-2026-000012','2025-11-15','2025-11-15','ejecutado','egreso','CAT-E-07-01',null,null,'EVT-2025-003','DEP-FINANZAS','FND-OPERATIVO',null,'[PRUEBA] Comisión de pasarela sobre la venta de entradas de la final','PEN',104.40,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),
('MOV-2026-000013','2025-10-12','2025-10-12','ejecutado','egreso','CAT-E-03-01',null,'CTP-0001','EVT-2025-003','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Pauta de la Liga Clausura con activación de Aurora Tech','PEN',1200,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'factura','F-8770',183.05,null),

-- Canje 1 · Periféricos Kuntur entrega teclados a cambio de activación
('MOV-2026-000014','2025-10-15','2025-10-15','ejecutado','ingreso','CAT-I-01-02','CTP-0004',null,'EVT-2025-003','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Canje Kuntur — activación puntual valorizada, lado ingreso','PEN',3000,1,null,null,'MTD-ESPECIE',true,false,'factura','F001-00014',457.63,null),
('MOV-2026-000015','2025-10-15','2025-10-15','ejecutado','egreso','CAT-E-01-02','CTP-0004',null,'EVT-2025-003','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Canje Kuntur — teclados entregados como premio, lado egreso','PEN',3000,1,null,null,'MTD-ESPECIE',true,false,'factura','F-2210',457.63,null),

-- EVT-2025-004 Trufa Fest Lima
('MOV-2026-000016','2025-12-06','2025-12-06','ejecutado','ingreso','CAT-I-03-02',null,null,'EVT-2025-004','DEP-OPERACIONES','FND-OPERATIVO','ITM-ENT-PREF','[PRUEBA] Entradas preferenciales Trufa Fest, agregado del día 1','PEN',4050,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'boleta','B001-00512',617.80,null),
('MOV-2026-000017','2025-12-06','2025-12-06','ejecutado','ingreso','CAT-I-03-01',null,null,'EVT-2025-004','DEP-OPERACIONES','FND-OPERATIVO','ITM-ENT-GENERAL','[PRUEBA] Entradas generales Trufa Fest, agregado del día 1','PEN',5200,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'boleta','B001-00513',793.22,null),
('MOV-2026-000018','2025-11-25','2025-11-28','ejecutado','ingreso','CAT-I-01-01','CTP-0005',null,'EVT-2025-004','DEP-ESPORTS','FND-OPERATIVO','ITM-PAQ-PLATA','[PRUEBA] Paquete Plata Café Quilla — primera cuota','PEN',6000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F001-00015',915.25,'https://drive.test/trufas/F001-00015.pdf'),
('MOV-2026-000019','2025-11-20','2025-12-01','ejecutado','egreso','CAT-E-02-05','CTP-0009',null,'EVT-2025-004','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Alquiler del salón para el Trufa Fest, dos días','PEN',4500,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F-3345',686.44,null),
('MOV-2026-000020','2025-12-07','2025-12-07','ejecutado','egreso','CAT-E-07-01',null,null,'EVT-2025-004','DEP-FINANZAS','FND-OPERATIVO',null,'[PRUEBA] Comisión de pasarela sobre las entradas del Trufa Fest','PEN',277.50,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),

-- EVT-2026-001 Copa Trufa Verano
('MOV-2026-000021','2026-02-01','2026-02-05','ejecutado','ingreso','CAT-I-01-01','CTP-0001',null,'EVT-2026-001','DEP-ESPORTS','FND-OPERATIVO','ITM-PAQ-ORO','[PRUEBA] Paquete Oro Aurora Tech — segunda cuota del acuerdo anual','PEN',12000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F001-00021',1830.51,'https://drive.test/trufas/F001-00021.pdf'),
('MOV-2026-000022','2026-02-10','2026-02-10','ejecutado','ingreso','CAT-I-01-02','CTP-0006',null,'EVT-2026-001','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Activación Telecom Sierra Norte en la Copa Verano','PEN',1800,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F001-00022',274.58,null),
('MOV-2026-000023','2026-02-10','2026-02-12','ejecutado','ingreso','CAT-I-01-01','CTP-0002',null,'EVT-2026-001','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Patrocinio Cripto Andina cobrado en USDT, liquidado al banco','USDT',800,3.78,'CTA-BINANCE','CTA-BCP-USD','MTD-CRIPTO',false,false,'factura','F001-00023',461.29,'https://drive.test/trufas/F001-00023.pdf'),
('MOV-2026-000024','2026-02-13','2026-02-13','ejecutado','egreso','CAT-E-07-04',null,null,'EVT-2026-001','DEP-FINANZAS','FND-OPERATIVO',null,'[PRUEBA] Spread de la conversión USDT a PEN en la liquidación','PEN',45.36,1,'CTA-BINANCE',null,'MTD-CRIPTO',false,false,'ninguno',null,null,null),
('MOV-2026-000025','2026-02-16','2026-02-16','ejecutado','egreso','CAT-E-01-01',null,null,'EVT-2026-001','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Premios en efectivo Copa Trufa Verano','PEN',4000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000026','2026-02-15','2026-02-15','ejecutado','egreso','CAT-E-02-01','CTP-0012',null,'EVT-2026-001','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Casteo de la Copa Trufa Verano','PEN',1800,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'recibo_honorarios','RH-0104',null,null),
('MOV-2026-000027','2026-02-14','2026-02-14','ejecutado','egreso','CAT-E-03-02','CTP-0013','CTP-0001','EVT-2026-001','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Colaboración con creadores para la activación de Aurora Tech','PEN',2200,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'recibo_honorarios','RH-0105',null,null),

-- Riesgo de bancarización · D. Leg. 1529
('MOV-2026-000028','2026-03-14','2026-03-14','ejecutado','ingreso','CAT-I-04-01','CTP-0019',null,'EVT-GENERAL','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tips acumulados en USDT sin liquidar al banco — puente sin documentar','USDT',600,3.78,'CTA-BINANCE',null,'MTD-CRIPTO',false,false,'ninguno',null,null,null),
('MOV-2026-000029','2026-03-18','2026-03-20','ejecutado','ingreso','CAT-I-01-02','CTP-0006',null,'EVT-2026-002','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Activación cobrada por PayPal sobre US$ 500 sin liquidar al banco','USD',550,3.75,'CTA-PAYPAL',null,'MTD-PAYPAL',false,false,'factura','F001-00029',314.62,null),
('MOV-2026-000030','2026-04-01','2026-04-05','ejecutado','egreso','CAT-E-02-05','CTP-0009',null,'EVT-2026-002','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Adelanto del local pagado en efectivo — sobre el umbral, gasto reparable','PEN',2500,1,'CTA-CAJA',null,'MTD-EFECTIVO',false,false,'factura','F-3390',381.36,null),

-- EVT-2026-002 Liga Trufa Apertura
('MOV-2026-000031','2026-04-05','2026-04-08','ejecutado','ingreso','CAT-I-01-03','CTP-0003',null,'EVT-2026-002','DEP-ESPORTS','FND-OPERATIVO','ITM-NAMING','[PRUEBA] Naming Energética Wayra — Liga Trufa Apertura','PEN',20000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F001-00031',3050.85,'https://drive.test/trufas/F001-00031.pdf'),
('MOV-2026-000032','2026-04-10','2026-04-15','ejecutado','ingreso','CAT-I-01-01','CTP-0005',null,'EVT-2026-002','DEP-ESPORTS','FND-OPERATIVO','ITM-PAQ-PLATA','[PRUEBA] Paquete Plata Café Quilla — segunda cuota','PEN',6000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F001-00032',915.25,null),
('MOV-2026-000033','2026-05-01','2026-05-02','ejecutado','ingreso','CAT-I-02-01','CTP-0004',null,'EVT-2026-002','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Comisión por referidos Kuntur del primer trimestre','PEN',1450,1,'CTA-BCP-PEN',null,'MTD-DEPOSITO',false,false,'factura','F001-00033',221.19,null),
('MOV-2026-000034','2026-06-20','2026-06-20','ejecutado','ingreso','CAT-I-03-01',null,null,'EVT-2026-002','DEP-OPERACIONES','FND-OPERATIVO','ITM-ENT-GENERAL','[PRUEBA] Entradas de la final de la Liga Apertura, agregado del día','PEN',2860,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'boleta','B001-00701',436.27,null),
('MOV-2026-000035','2026-06-21','2026-06-21','ejecutado','egreso','CAT-E-01-01',null,null,'EVT-2026-002','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Bolsa de premios de la Liga Trufa Apertura','PEN',8000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000036','2026-06-21','2026-06-21','ejecutado','egreso','CAT-E-02-01','CTP-0012',null,'EVT-2026-002','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Casteo de las diez jornadas de la Liga Apertura','PEN',4800,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'recibo_honorarios','RH-0128',null,null),
('MOV-2026-000037','2026-05-10','2026-05-10','ejecutado','egreso','CAT-E-03-01',null,'CTP-0003','EVT-2026-002','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Pauta de la Liga Apertura atribuida al naming de Wayra','PEN',3200,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'factura','F-9912',488.14,null),
('MOV-2026-000038','2026-04-02','2026-04-02','ejecutado','egreso','CAT-E-02-02','CTP-0008',null,'EVT-2026-002','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Plataforma de brackets — temporada Apertura','PEN',1900,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'factura','F-9001',289.83,null),
('MOV-2026-000039','2026-06-25','2026-06-25','ejecutado','egreso','CAT-E-01-03','CTP-0016',null,'EVT-2026-002','DEP-DIRECCION','FND-BENEFICO',null,'[PRUEBA] Entrega al Albergue San Martín del fondo recaudado en la Liga','PEN',3000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,'https://drive.test/trufas/acta-albergue-2026-06.pdf'),

-- Canje 2 · Aurora Tech entrega equipos que Trufas usa: activo fijo
('MOV-2026-000040','2026-04-20','2026-04-20','ejecutado','ingreso','CAT-I-01-02','CTP-0001',null,'EVT-2026-002','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Canje Aurora Tech — activación valorizada, lado ingreso','PEN',4500,1,null,null,'MTD-ESPECIE',true,false,'factura','F001-00040',686.44,null),
('MOV-2026-000041','2026-04-20','2026-04-20','ejecutado','egreso','CAT-E-04-04','CTP-0001',null,'EVT-2026-002','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Canje Aurora Tech — PC de producción sobre el corte de la UIT, se activa','PEN',4500,1,null,null,'MTD-ESPECIE',true,true,'factura','F-1187',686.44,null),

-- Canje sin pareja · contingencia de IGV sin efectivo
('MOV-2026-000042','2026-07-02','2026-07-02','ejecutado','ingreso','CAT-I-01-02','CTP-0005',null,'EVT-2026-003','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Canje Café Quilla sin facturar ni emparejar — contingencia abierta','PEN',1200,1,null,null,'MTD-ESPECIE',true,false,'ninguno',null,null,null),

-- Estructural · EVT-GENERAL
('MOV-2026-000043','2026-01-15','2026-01-15','ejecutado','egreso','CAT-E-06-01','CTP-0011',null,'EVT-GENERAL','DEP-FINANZAS','FND-OPERATIVO',null,'[PRUEBA] Servicio contable de enero','PEN',800,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F-5501',122.03,null),
('MOV-2026-000044','2026-01-10','2026-01-10','ejecutado','egreso','CAT-E-04-01','CTP-0010',null,'EVT-GENERAL','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Hosting y dominio somostrufas.org, anual','PEN',420,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'factura','F-6601',64.07,null),
('MOV-2026-000045','2026-03-31','2026-03-31','ejecutado','egreso','CAT-E-07-03',null,null,'EVT-GENERAL','DEP-FINANZAS','FND-OPERATIVO',null,'[PRUEBA] ITF del primer trimestre','PEN',12.50,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000046','2026-04-14','2026-04-14','ejecutado','egreso','CAT-E-08-01',null,null,'EVT-GENERAL','DEP-FINANZAS','FND-OPERATIVO',null,'[PRUEBA] Pago a cuenta de renta — Régimen MYPE Tributario','PEN',1450,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000047','2026-05-06','2026-05-06','ejecutado','egreso','CAT-E-04-04',null,null,'EVT-GENERAL','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Estación de captura para transmisiones — sobre el corte, se activa','PEN',4200,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,true,'factura','F-7788',640.68,null),
('MOV-2026-000048','2026-05-05','2026-05-05','ejecutado','egreso','CAT-E-04-04',null,null,'EVT-GENERAL','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Teclado de repuesto — bajo un cuarto de la UIT, va a gasto','PEN',300,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'boleta','B-1102',45.76,null),

-- Se anulan más abajo, para ejercitar el borrado lógico y la auditoría
('MOV-2026-000049','2026-06-01','2026-06-01','ejecutado','egreso','CAT-E-03-01',null,null,'EVT-2026-002','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Pauta de refuerzo de la Liga Apertura','PEN',900,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),
('MOV-2026-000050','2026-06-02','2026-06-02','ejecutado','ingreso','CAT-I-04-02','CTP-0020',null,'EVT-GENERAL','DEP-DIRECCION','FND-BENEFICO',null,'[PRUEBA] Donación particular de junio','PEN',500,1,'CTA-BCP-PEN',null,'MTD-DEPOSITO',false,false,'ninguno',null,null,null),

-- Comprometido · EVT-2026-004 Trufa Invitational
('MOV-2026-000051','2026-10-05',null,'comprometido','ingreso','CAT-I-01-01','CTP-0001',null,'EVT-2026-004','DEP-ESPORTS','FND-OPERATIVO','ITM-PAQ-ORO','[PRUEBA] Paquete Oro Aurora Tech para el Invitational — contrato firmado','PEN',12000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000052','2026-10-12',null,'comprometido','ingreso','CAT-I-01-03','CTP-0003',null,'EVT-2026-004','DEP-ESPORTS','FND-OPERATIVO','ITM-NAMING','[PRUEBA] Naming del Invitational — contrato firmado','PEN',20000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000053','2026-11-10',null,'comprometido','egreso','CAT-E-02-05','CTP-0009',null,'EVT-2026-004','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Local del Invitational — reserva confirmada','PEN',7500,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),

-- Proyectado · EVT-2026-004
('MOV-2026-000054','2026-11-23',null,'proyectado','egreso','CAT-E-01-01',null,null,'EVT-2026-004','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Bolsa de premios estimada del Invitational','PEN',10000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000055','2026-11-21',null,'proyectado','ingreso','CAT-I-03-02',null,null,'EVT-2026-004','DEP-OPERACIONES','FND-OPERATIVO','ITM-ENT-PREF','[PRUEBA] Venta de entradas preferenciales estimada del Invitational','PEN',9000,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null);

select setval('finanzas.seq_movimientos', 55);

-- ---------------------------------------------------------------------
-- Emparejar los canjes. El trigger exige tipo opuesto e igual
-- valorización en ambos lados, así que esto también lo verifica.
-- ---------------------------------------------------------------------
update finanzas.reg_movimientos set contrapartida_id = 'MOV-2026-000015' where id = 'MOV-2026-000014';
update finanzas.reg_movimientos set contrapartida_id = 'MOV-2026-000014' where id = 'MOV-2026-000015';
update finanzas.reg_movimientos set contrapartida_id = 'MOV-2026-000041' where id = 'MOV-2026-000040';
update finanzas.reg_movimientos set contrapartida_id = 'MOV-2026-000040' where id = 'MOV-2026-000041';

-- ---------------------------------------------------------------------
-- Anular dos movimientos. Nunca se borran: la columna estado distingue
-- activo de anulado, y fn_sella_auditoria pone anulado_en.
-- ---------------------------------------------------------------------
update finanzas.reg_movimientos
   set estado = 'anulado',
       motivo_anulacion = '[PRUEBA] Cargo duplicado de la pasarela, revertido por el banco.'
 where id = 'MOV-2026-000049';

update finanzas.reg_movimientos
   set estado = 'anulado',
       motivo_anulacion = '[PRUEBA] Registrada dos veces en la conciliación de junio.'
 where id = 'MOV-2026-000050';

-- =====================================================================
-- REG_IMPACTO · 14 filas
-- pasa_por_caja separa lo recaudado por Trufas de lo facilitado.
-- Los premios que el patrocinador entrega directo al ganador van solo
-- aquí, con origen = patrocinador: así el P&L del torneo no infla gastos
-- que Trufas no pagó, pero el informe público mantiene el impacto total.
-- =====================================================================
insert into finanzas.reg_impacto
  (id, fecha, beneficiario_id, evento_id, tipo_aporte, pasa_por_caja, origen,
   monto, evidencia_url, publicado, descripcion) values
  ('IMP-2026-00001','2025-07-14','CTP-0016','EVT-2025-001','efectivo', true,  'trufas',       700,  'https://drive.test/trufas/acta-2025-07-14.pdf', true,  '[PRUEBA] Aporte al albergue del cierre de la Copa Invierno.'),
  ('IMP-2026-00002','2025-08-25','CTP-0017','EVT-2025-002','efectivo', true,  'comunidad',    450,  'https://drive.test/trufas/acta-2025-08-25.pdf', true,  '[PRUEBA] Recaudación de la comunidad durante el Open.'),
  ('IMP-2026-00003','2025-11-20','CTP-0016','EVT-2025-003','efectivo', true,  'trufas',       2500, 'https://drive.test/trufas/acta-2025-11-20.pdf', true,  '[PRUEBA] Aporte de la Liga Clausura.'),
  ('IMP-2026-00004','2025-12-10','CTP-0017','EVT-2025-004','especie',  false, 'patrocinador', 1800, 'https://drive.test/trufas/acta-2025-12-10.pdf', true,  '[PRUEBA] Kuntur entregó periféricos directo al comedor. Trufas facilitó, no recaudó.'),
  ('IMP-2026-00005','2026-02-20','CTP-0016','EVT-2026-001','efectivo', true,  'trufas',       1500, 'https://drive.test/trufas/acta-2026-02-20.pdf', true,  '[PRUEBA] Aporte de la Copa Verano.'),
  ('IMP-2026-00006','2026-02-22','CTP-0018','EVT-2026-001','servicio', false, 'comunidad',    900,  'https://drive.test/trufas/acta-2026-02-22.pdf', true,  '[PRUEBA] Jornada de voluntariado en la biblioteca. Valorizada, sin pasar por caja.'),
  ('IMP-2026-00007','2026-03-15','CTP-0017','EVT-GENERAL', 'efectivo', true,  'donante',      800,  'https://drive.test/trufas/acta-2026-03-15.pdf', true,  '[PRUEBA] Donación particular canalizada al comedor.'),
  ('IMP-2026-00008','2026-05-30','CTP-0017','EVT-2026-002','efectivo', true,  'donante',      950,  'https://drive.test/trufas/acta-2026-05-30.pdf', true,  '[PRUEBA] Donación de mitad de temporada.'),
  ('IMP-2026-00009','2026-06-25','CTP-0016','EVT-2026-002','efectivo', true,  'trufas',       3000, 'https://drive.test/trufas/acta-albergue-2026-06.pdf', true, '[PRUEBA] Entrega del fondo benéfico de la Liga Apertura. Corresponde a MOV-2026-000039.'),
  ('IMP-2026-00010','2026-06-28','CTP-0017','EVT-2026-002','especie',  false, 'patrocinador', 2400, 'https://drive.test/trufas/acta-2026-06-28.pdf', true,  '[PRUEBA] Aurora Tech entregó equipos directo al comedor.'),
  ('IMP-2026-00011','2026-07-05','CTP-0018','EVT-2026-003','efectivo', true,  'donante',      1200, 'https://drive.test/trufas/acta-2026-07-05.pdf', true,  '[PRUEBA] Aporte a la biblioteca comunitaria.'),
  ('IMP-2026-00012','2026-08-20','CTP-0016','EVT-2026-003','especie',  false, 'patrocinador', 1500, 'https://drive.test/trufas/acta-2026-08-20.pdf', false, '[PRUEBA] Pendiente de revisión antes de publicar.'),
  ('IMP-2026-00013','2026-08-22','CTP-0018','EVT-2026-003','efectivo', true,  'trufas',       600,  null,                                            false, '[PRUEBA] Sin evidencia adjunta todavía: no publicable.'),
  ('IMP-2026-00014','2026-09-02','CTP-0018','EVT-2026-003','servicio', false, 'comunidad',    1100, 'https://drive.test/trufas/acta-2026-09-02.pdf', true,  '[PRUEBA] Taller dictado por la comunidad en la biblioteca.');

select setval('finanzas.seq_impacto', 14);

-- =====================================================================
-- REG_ACUERDOS · 8 filas · el índice del contrato, no el contrato
-- =====================================================================
insert into finanzas.reg_acuerdos
  (id, contraparte_id, tipo, evento_id, depto_id, item_id, descripcion,
   moneda, monto_pactado, tc, incluye_especie,
   fecha_firma, fecha_inicio, fecha_fin, estado_acuerdo, url_contrato) values
  ('ACU-2026-0001','CTP-0001','patrocinio',            'EVT-GENERAL', 'DEP-ESPORTS','ITM-PAQ-ORO',  '[PRUEBA] Paquete Oro anual Aurora Tech, dos cuotas semestrales','PEN',24000,1,false,'2025-09-20','2025-10-01','2026-09-30','vigente', 'https://drive.test/trufas/contrato-aurora-2025.pdf'),
  ('ACU-2026-0002','CTP-0003','patrocinio',            'EVT-2026-002','DEP-ESPORTS','ITM-NAMING',   '[PRUEBA] Naming de la Liga Trufa Apertura','PEN',20000,1,false,'2026-03-20','2026-04-01','2026-06-30','cumplido','https://drive.test/trufas/contrato-wayra-apertura.pdf'),
  ('ACU-2026-0003','CTP-0005','patrocinio',            'EVT-GENERAL', 'DEP-ESPORTS','ITM-PAQ-PLATA','[PRUEBA] Paquete Plata anual Café Quilla, dos cuotas','PEN',12000,1,false,'2025-11-10','2025-11-15','2026-11-14','vigente', 'https://drive.test/trufas/contrato-quilla-2025.pdf'),
  ('ACU-2026-0004','CTP-0002','patrocinio',            'EVT-2026-001','DEP-ESPORTS',null,           '[PRUEBA] Patrocinio Cripto Andina pactado en dólares, cobrado en USDT','USD',800,3.75,false,'2026-01-28','2026-02-01','2026-02-28','cumplido','https://drive.test/trufas/contrato-cripto-verano.pdf'),
  ('ACU-2026-0005','CTP-0004','patrocinio',            'EVT-2025-003','DEP-ESPORTS',null,           '[PRUEBA] Canje Kuntur: periféricos a cambio de activación','PEN',3000,1,true, '2025-10-01','2025-10-01','2025-11-30','cumplido','https://drive.test/trufas/contrato-kuntur-canje.pdf'),
  ('ACU-2026-0006','CTP-0006','patrocinio',            'EVT-2026-004','DEP-ESPORTS','ITM-PAQ-BRONCE','[PRUEBA] Paquete Bronce Telecom Sierra Norte para el Invitational','PEN',2500,1,false,'2026-08-15','2026-09-01','2026-12-31','vigente','https://drive.test/trufas/contrato-tsn-invitational.pdf'),
  ('ACU-2026-0007','CTP-0004','afiliacion',            'EVT-GENERAL', 'DEP-MARKETING',null,         '[PRUEBA] Programa de referidos Kuntur, comisión trimestral','PEN',6000,1,false,'2026-01-05','2026-01-15','2026-12-31','vigente','https://drive.test/trufas/contrato-kuntur-afiliados.pdf'),
  ('ACU-2026-0008','CTP-0006','patrocinio',            'EVT-2026-004','DEP-ESPORTS',null,           '[PRUEBA] Propuesta de patrocinio principal del Invitational, sin firmar','PEN',30000,1,false,null,        '2026-11-01','2027-10-31','borrador',null);

select setval('finanzas.seq_acuerdos', 8);

-- =====================================================================
-- REG_ACUERDO_CUOTAS · 13 filas
-- El cronograma alimenta el flujo proyectado y las alertas de
-- vencimiento. movimiento_id nulo es una cuota que todavía no entró.
-- =====================================================================
insert into finanzas.reg_acuerdo_cuotas
  (id, acuerdo_id, nro_cuota, fecha_prevista, moneda, monto, tc, movimiento_id) values
  ('CUO-2026-0001','ACU-2026-0001',1,'2025-10-05','PEN',12000,1,   'MOV-2026-000005'),
  ('CUO-2026-0002','ACU-2026-0001',2,'2026-02-01','PEN',12000,1,   'MOV-2026-000021'),
  ('CUO-2026-0003','ACU-2026-0002',1,'2026-04-05','PEN',20000,1,   'MOV-2026-000031'),
  ('CUO-2026-0004','ACU-2026-0003',1,'2025-11-25','PEN',6000,1,    'MOV-2026-000018'),
  ('CUO-2026-0005','ACU-2026-0003',2,'2026-04-10','PEN',6000,1,    'MOV-2026-000032'),
  ('CUO-2026-0006','ACU-2026-0004',1,'2026-02-10','USD',800,3.78,  'MOV-2026-000023'),
  ('CUO-2026-0007','ACU-2026-0005',1,'2025-10-15','PEN',3000,1,    'MOV-2026-000014'),
  ('CUO-2026-0008','ACU-2026-0006',1,'2026-09-05','PEN',2500,1,    null),
  ('CUO-2026-0009','ACU-2026-0007',1,'2026-05-01','PEN',1450,1,    'MOV-2026-000033'),
  ('CUO-2026-0010','ACU-2026-0007',2,'2026-08-01','PEN',1500,1,    null),
  ('CUO-2026-0011','ACU-2026-0007',3,'2026-11-01','PEN',1500,1,    null),
  ('CUO-2026-0012','ACU-2026-0007',4,'2027-02-01','PEN',1500,1,    null),
  ('CUO-2026-0013','ACU-2026-0008',1,'2026-11-05','PEN',15000,1,   null);

-- =====================================================================
-- REG_PRESUPUESTO · 10 filas
-- Se congela al aprobarse y nunca se edita. Los cambios entran como
-- versiones nuevas: PRE-00006 es la v1 superada y PRE-00007 la v2 vigente.
-- =====================================================================
insert into finanzas.reg_presupuesto
  (id, alcance, depto_id, anio, trimestre, evento_id, categoria_id, tipo,
   monto_pen, version, vigente, congelado_en, aprobado_por, notas) values
  ('PRE-00001','departamento_trimestre','DEP-MARKETING',   2026,2,null,null,'egreso',  6000, 1,true, '2026-03-25 10:00:00-05','Dirección de Finanzas','[PRUEBA] Pauta y creadores del segundo trimestre.'),
  ('PRE-00002','departamento_trimestre','DEP-ESPORTS',     2026,2,null,null,'egreso', 15000, 1,true, '2026-03-25 10:00:00-05','Dirección de Finanzas','[PRUEBA] Premios y talento de la Liga Apertura.'),
  ('PRE-00003','departamento_trimestre','DEP-OPERACIONES', 2026,2,null,null,'egreso',  5000, 1,true, '2026-03-25 10:00:00-05','Dirección de Finanzas','[PRUEBA] Plataforma, local y logística.'),
  ('PRE-00004','departamento_trimestre','DEP-FINANZAS',    2026,2,null,null,'egreso',  2500, 1,true, '2026-03-25 10:00:00-05','Dirección de Finanzas','[PRUEBA] Contabilidad, comisiones y tributos.'),
  ('PRE-00005','departamento_trimestre','DEP-ESPORTS',     2026,2,null,null,'ingreso',30000, 1,true, '2026-03-25 10:00:00-05','Dirección de Finanzas','[PRUEBA] Meta de patrocinios del segundo trimestre.'),
  ('PRE-00006','departamento_trimestre','DEP-MARKETING',   2026,3,null,null,'egreso',  4000, 1,false,'2026-06-20 10:00:00-05','Dirección de Finanzas','[PRUEBA] Línea base del tercer trimestre. Superada por la versión 2; se conserva para el KPI de variación.'),
  ('PRE-00007','departamento_trimestre','DEP-MARKETING',   2026,3,null,null,'egreso',  5500, 2,true, '2026-07-01 10:00:00-05','Dirección de Finanzas','[PRUEBA] Versión 2 del tercer trimestre, aprobada al sumar el showmatch de creadores.'),
  ('PRE-00008','evento',                 null,            null,null,'EVT-2026-002',null,'egreso',25000,1,true,'2026-03-30 10:00:00-05','CEO','[PRUEBA] Presupuesto de egresos de la Liga Trufa Apertura.'),
  ('PRE-00009','evento',                 null,            null,null,'EVT-2026-002',null,'ingreso',32000,1,true,'2026-03-30 10:00:00-05','CEO','[PRUEBA] Meta de ingresos de la Liga Trufa Apertura.'),
  ('PRE-00010','evento',                 null,            null,null,'EVT-2026-004',null,'egreso',28000,1,true,null,                     null, '[PRUEBA] Borrador del Invitational: sin congelar todavía, así que aún admite edición.');

select setval('finanzas.seq_presupuesto', 10);
