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
-- NO se insertan eventos: se usan los que ya existen en public.eventos.
-- En el proyecto Website son los eventos reales que sirve la portada, y
-- meter eventos ficticios ahí los publicaría en el sitio. Lo único que
-- se agrega del lado de eventos son sus atributos de gestión, que viven
-- en finanzas.eventos_atributos.
--
-- Sí se crean 20 contrapartes de apoyo, ficticias y marcadas.
--
-- Todo lo de prueba lleva el prefijo [PRUEBA] en descripcion o notas.
-- Los montos con comprobante incluyen IGV; la columna igv guarda la
-- parte que corresponde (monto / 1.18 * 0.18). Los recibos por
-- honorarios de cuarta categoría van sin IGV.
--
-- Cómo purgar: ver supabase/README.md. DELETE está revocado incluso para
-- service_role, así que la purga corre como owner postgres.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Atributos de gestión de los eventos que ya existen.
-- Se resuelven por lo que la landing ya dice de cada uno, así que si un
-- evento no está en este proyecto simplemente no se inserta su fila.
-- ---------------------------------------------------------------------
insert into finanzas.eventos_atributos (evento_id, nivel, region, ciclo, modalidad, notas)
select v.evento_id, v.nivel, v.region, v.ciclo, v.modalidad, v.notas
from (values
  ('EVT-GENERAL',                       'N/A',          'N/A',   null,       'online', '[PRUEBA] Fila técnica: lo estructural no pertenece a un evento.'),
  ('circuito-trufas-2026-3',            'competitivo',  'LATAM', '2026-3',   'online', '[PRUEBA] Torneo principal del ciclo. Inscripciones abren el 25 de noviembre.'),
  ('sorteo-nitro-2026-08-31',           'comunidad',    'LATAM', '2026-S2',  'online', '[PRUEBA] Sorteo mensual de Discord.'),
  ('sorteo-nitro-2026-09-30',           'comunidad',    'LATAM', '2026-S2',  'online', '[PRUEBA] Sorteo mensual de Discord.'),
  ('sorteo-juego-eleccion',             'comunidad',    'LATAM', '2026-S2',  'online', '[PRUEBA] Sorteo por afiliación con tienda externa.'),
  ('sorteo-valorant-points-2026-09-20', 'comunidad',    'LATAM', '2026-S2',  'online', '[PRUEBA] Sorteo patrocinado.'),
  ('noche-de-karaoke-2026-08-26',       'casual',       'PE',    '2026-S2',  'online', '[PRUEBA] Stream de comunidad.'),
  ('noche-de-karaoke-2026-09-02',       'casual',       'PE',    '2026-S2',  'online', '[PRUEBA] Stream de comunidad.'),
  ('noche-de-impostores-2026-08-28',    'casual',       'PE',    '2026-S2',  'online', '[PRUEBA] Stream de comunidad.'),
  ('noche-de-impostores-2026-09-11',    'casual',       'PE',    '2026-S2',  'online', '[PRUEBA] Stream de comunidad.'),
  ('roblox-insano-2026-08-30',          'casual',       'PE',    '2026-S2',  'online', '[PRUEBA] Stream de comunidad.'),
  ('roblox-insano-2026-09-13',          'casual',       'PE',    '2026-S2',  'online', '[PRUEBA] Stream de comunidad.'),
  ('noche-de-camaleones-2026-09-03',    'casual',       'PE',    '2026-S2',  'online', '[PRUEBA] Stream de comunidad.'),
  ('escaladas-alocadas-2026-09-04',     'casual',       'PE',    '2026-S2',  'online', '[PRUEBA] Stream de comunidad.')
) as v(evento_id, nivel, region, ciclo, modalidad, notas)
join public.eventos e on e.id = v.evento_id
on conflict (evento_id) do nothing;

-- ---------------------------------------------------------------------
-- Contrapartes de apoyo · los cinco tipos. Ficticias.
-- ---------------------------------------------------------------------
insert into finanzas.cat_contrapartes
  (id, tipo, nombre, razon_social, tipo_documento, numero_documento, email, pais, notas) values
  ('CTP-0001', 'patrocinador', 'Aurora Tech Perú',        'Aurora Tech Perú S.A.C.',       'RUC', '20601234561', 'alianzas@aurora.test',   'PE', '[PRUEBA] Patrocinador principal del ciclo. Trabaja también por canje.'),
  ('CTP-0002', 'patrocinador', 'Cripto Andina',           'Cripto Andina S.A.C.',          'RUC', '20601234562', 'marketing@criptoandina.test', 'PE', '[PRUEBA] Paga en USDT. Requiere puente documentado al banco.'),
  ('CTP-0003', 'patrocinador', 'Energética Wayra',        'Energética Wayra S.A.',         'RUC', '20601234563', 'brand@wayra.test',       'PE', '[PRUEBA] Naming del torneo.'),
  ('CTP-0004', 'patrocinador', 'Periféricos Kuntur',      'Periféricos Kuntur S.A.C.',     'RUC', '20601234564', 'canjes@kuntur.test',     'PE', '[PRUEBA] Trabaja por canje y por programa de referidos.'),
  ('CTP-0005', 'patrocinador', 'Café Tostado Quilla',     'Café Tostado Quilla E.I.R.L.',  'RUC', '20601234565', 'hola@quilla.test',       'PE', '[PRUEBA] Paquete de temporada.'),
  ('CTP-0006', 'patrocinador', 'Telecom Sierra Norte',    'Telecom Sierra Norte S.A.C.',   'RUC', '20601234566', 'patrocinios@tsn.test',   'PE', '[PRUEBA] Activaciones puntuales, cobra por PayPal.'),
  ('CTP-0007', 'proveedor',    'Estudio Ronda',           'Estudio Ronda S.A.C.',          'RUC', '20601234567', 'produccion@ronda.test',  'PE', '[PRUEBA] Producción audiovisual.'),
  ('CTP-0008', 'proveedor',    'Plataforma de torneos',   null,                            null,  null,          null,                     'US', '[PRUEBA] Suscripción a la plataforma de brackets.'),
  ('CTP-0009', 'proveedor',    'Salón Miraflores',        'Inversiones Salón Miraflores S.A.C.', 'RUC', '20601234569', 'reservas@salonmf.test', 'PE', '[PRUEBA] Alquiler de local para la final presencial.'),
  ('CTP-0010', 'proveedor',    'Nube Andina Hosting',     'Nube Andina S.A.C.',            'RUC', '20601234570', 'soporte@nubeandina.test','PE', '[PRUEBA] Hosting y dominios.'),
  ('CTP-0011', 'proveedor',    'Contadores Asociados',    'Contadores Asociados S.C.R.L.', 'RUC', '20601234571', 'estudio@contadores.test','PE', '[PRUEBA] Servicio contable. Sustituir por el contador que se contrate.'),
  ('CTP-0012', 'colaborador',  'Diego Salas',             null,                            'DNI', '45781234',    'diego@casters.test',     'PE', '[PRUEBA] Caster y anfitrión de streams.'),
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
-- REG_MOVIMIENTOS · 55 filas sobre los eventos reales
-- Ids explícitos para que el emparejamiento de canjes sea determinista.
-- =====================================================================
insert into finanzas.reg_movimientos
  (id, fecha_prevista, fecha_efectiva, estado_flujo, tipo, categoria_id,
   contraparte_id, atribuido_a_id, evento_id, depto_id, fondo_id, item_id,
   descripcion, moneda, monto_original, tc,
   cuenta_id, cuenta_destino_final_id, metodo_id,
   es_especie, es_activo_fijo, comprobante_tipo, comprobante_nro, igv, url_respaldo) values

-- ── Circuito Trufas 2026-3 · el torneo. Contratos firmados y proyección ──
('MOV-2026-000001','2026-11-30',null,'comprometido','ingreso','CAT-I-01-01','CTP-0001',null,'circuito-trufas-2026-3','DEP-ESPORTS','FND-OPERATIVO','ITM-PAQ-ORO','[PRUEBA] Paquete Oro Aurora Tech — Circuito 2026-3, contrato firmado','PEN',12000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000002','2026-12-05',null,'comprometido','ingreso','CAT-I-01-03','CTP-0003',null,'circuito-trufas-2026-3','DEP-ESPORTS','FND-OPERATIVO','ITM-NAMING','[PRUEBA] Naming Energética Wayra — Circuito 2026-3, contrato firmado','PEN',20000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000003','2026-12-10',null,'comprometido','ingreso','CAT-I-01-01','CTP-0005',null,'circuito-trufas-2026-3','DEP-ESPORTS','FND-OPERATIVO','ITM-PAQ-PLATA','[PRUEBA] Paquete Plata Café Quilla — Circuito 2026-3','PEN',6000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000004','2026-12-12',null,'comprometido','ingreso','CAT-I-01-02','CTP-0006',null,'circuito-trufas-2026-3','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Activación Telecom Sierra Norte en la gran final','PEN',1800,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000005','2026-12-01',null,'comprometido','egreso','CAT-E-02-02','CTP-0008',null,'circuito-trufas-2026-3','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Plataforma de brackets para todo el Circuito','PEN',2400,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),
('MOV-2026-000006','2026-12-28',null,'comprometido','egreso','CAT-E-02-01','CTP-0012',null,'circuito-trufas-2026-3','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Casteo del Circuito: fase de grupos y playoffs','PEN',5200,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000007','2026-12-30',null,'proyectado','ingreso','CAT-I-03-02',null,null,'circuito-trufas-2026-3','DEP-OPERACIONES','FND-OPERATIVO','ITM-ENT-PREF','[PRUEBA] Entradas preferenciales estimadas de la gran final','PEN',9000,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),
('MOV-2026-000008','2026-12-30',null,'proyectado','ingreso','CAT-I-03-01',null,null,'circuito-trufas-2026-3','DEP-OPERACIONES','FND-OPERATIVO','ITM-ENT-GENERAL','[PRUEBA] Entradas generales estimadas de la gran final','PEN',4200,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),
('MOV-2026-000009','2027-01-02',null,'proyectado','egreso','CAT-E-01-01',null,null,'circuito-trufas-2026-3','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Bolsa de premios del Circuito 2026-3','PEN',15000,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000010','2026-12-15',null,'proyectado','egreso','CAT-E-03-01',null,'CTP-0003','circuito-trufas-2026-3','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Pauta del Circuito, atribuida al naming de Wayra','PEN',4000,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),
('MOV-2026-000011','2026-11-28',null,'proyectado','egreso','CAT-E-03-03','CTP-0014','CTP-0003','circuito-trufas-2026-3','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Identidad visual del Circuito: overlay, piezas y bumpers','PEN',2200,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000012','2026-12-20',null,'proyectado','egreso','CAT-E-02-04','CTP-0014',null,'circuito-trufas-2026-3','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Arte de la transmisión de la gran final','PEN',1500,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),

-- ── Sorteo: 1 Juego a Elección · afiliación con tienda externa ──
('MOV-2026-000013','2026-08-31','2026-09-01','ejecutado','ingreso','CAT-I-02-01','CTP-0004',null,'sorteo-juego-eleccion','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Comisión por referidos del sorteo de agosto','PEN',850,1,'CTA-BCP-PEN',null,'MTD-DEPOSITO',false,false,'factura','F001-00013',129.66,'https://drive.test/trufas/F001-00013.pdf'),
('MOV-2026-000014','2026-08-28','2026-08-28','ejecutado','egreso','CAT-E-03-01',null,null,'sorteo-juego-eleccion','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Pauta para difundir el sorteo','PEN',400,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),
('MOV-2026-000015','2026-09-05','2026-09-05','ejecutado','ingreso','CAT-I-04-01','CTP-0019',null,'sorteo-juego-eleccion','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tips durante el anuncio de ganadores','PEN',120,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),

-- ── Sorteo de Nitro de agosto ──
('MOV-2026-000016','2026-08-26','2026-08-26','ejecutado','egreso','CAT-E-01-02',null,null,'sorteo-nitro-2026-08-31','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tres meses de Nitro como premio del sorteo','PEN',45,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'boleta','B-2201',6.86,null),
('MOV-2026-000017','2026-09-01','2026-09-01','ejecutado','ingreso','CAT-I-04-01','CTP-0019',null,'sorteo-nitro-2026-08-31','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tips durante el sorteo de Nitro','PEN',85,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),
('MOV-2026-000018','2026-08-24','2026-08-24','ejecutado','egreso','CAT-E-03-01',null,null,'sorteo-nitro-2026-08-31','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Pauta del sorteo mensual de Discord','PEN',250,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),

-- ── Sorteo de Valorant Points · patrocinado ──
('MOV-2026-000019','2026-08-31','2026-08-31','ejecutado','egreso','CAT-E-01-02',null,null,'sorteo-valorant-points-2026-09-20','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Valorant Points como premio del sorteo','PEN',180,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'boleta','B-2214',27.46,null),
('MOV-2026-000020','2026-09-01','2026-09-02','ejecutado','ingreso','CAT-I-01-02','CTP-0006',null,'sorteo-valorant-points-2026-09-20','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Telecom Sierra Norte patrocina el sorteo de VP','PEN',1200,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F001-00020',183.05,'https://drive.test/trufas/F001-00020.pdf'),

-- ── Sorteo de Nitro de setiembre ──
('MOV-2026-000021','2026-09-04','2026-09-04','ejecutado','egreso','CAT-E-01-02',null,null,'sorteo-nitro-2026-09-30','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tres meses de Nitro como premio del sorteo','PEN',45,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'boleta','B-2230',6.86,null),

-- ── Noche de Karaoke del 26 de agosto ──
('MOV-2026-000022','2026-08-27','2026-08-27','ejecutado','egreso','CAT-E-02-01','CTP-0012',null,'noche-de-karaoke-2026-08-26','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Anfitrión de la Noche de Karaoke','PEN',150,1,'CTA-BCP-PEN',null,'MTD-YAPE',false,false,'recibo_honorarios','RH-0301',null,null),
('MOV-2026-000023','2026-08-27','2026-08-27','ejecutado','ingreso','CAT-I-04-01','CTP-0019',null,'noche-de-karaoke-2026-08-26','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tips de la comunidad en el karaoke','PEN',65,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),

-- ── Noche de Impostores del 28 de agosto ──
('MOV-2026-000024','2026-08-29','2026-08-29','ejecutado','egreso','CAT-E-02-01','CTP-0015',null,'noche-de-impostores-2026-08-28','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Observer de la Noche de Impostores','PEN',120,1,'CTA-BCP-PEN',null,'MTD-YAPE',false,false,'recibo_honorarios','RH-0302',null,null),
('MOV-2026-000025','2026-08-29','2026-08-29','ejecutado','ingreso','CAT-I-04-01','CTP-0019',null,'noche-de-impostores-2026-08-28','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tips de la comunidad en Among Us','PEN',40,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),

-- ── Roblox Insano del 30 de agosto ──
('MOV-2026-000026','2026-08-31','2026-08-31','ejecutado','egreso','CAT-E-02-01','CTP-0012',null,'roblox-insano-2026-08-30','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Anfitrión del Roblox Insano','PEN',150,1,'CTA-BCP-PEN',null,'MTD-YAPE',false,false,'recibo_honorarios','RH-0303',null,null),
('MOV-2026-000027','2026-08-31','2026-08-31','ejecutado','ingreso','CAT-I-04-02','CTP-0020',null,'roblox-insano-2026-08-30','DEP-DIRECCION','FND-BENEFICO',null,'[PRUEBA] Donación de un espectador durante el stream','PEN',200,1,'CTA-BCP-PEN',null,'MTD-DEPOSITO',false,false,'ninguno',null,null,null),

-- ── Noche de Karaoke del 2 de setiembre ──
('MOV-2026-000028','2026-09-03','2026-09-03','ejecutado','egreso','CAT-E-02-01','CTP-0012',null,'noche-de-karaoke-2026-09-02','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Anfitrión de la Noche de Karaoke','PEN',150,1,'CTA-BCP-PEN',null,'MTD-YAPE',false,false,'recibo_honorarios','RH-0304',null,null),
('MOV-2026-000029','2026-09-03','2026-09-03','ejecutado','ingreso','CAT-I-04-01','CTP-0019',null,'noche-de-karaoke-2026-09-02','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tips de la comunidad en el karaoke','PEN',55,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),

-- ── Noche de Camaleones ──
('MOV-2026-000030','2026-09-04','2026-09-04','ejecutado','egreso','CAT-E-02-01','CTP-0013',null,'noche-de-camaleones-2026-09-03','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Conducción de la Noche de Camaleones','PEN',130,1,'CTA-BCP-PEN',null,'MTD-YAPE',false,false,'recibo_honorarios','RH-0305',null,null),
('MOV-2026-000031','2026-09-02','2026-09-02','ejecutado','egreso','CAT-E-02-04','CTP-0014',null,'noche-de-camaleones-2026-09-03','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Miniatura y overlay del stream','PEN',180,1,'CTA-BCP-PEN',null,'MTD-YAPE',false,false,'recibo_honorarios','RH-0306',null,null),

-- ── Escaladas Alocadas ──
('MOV-2026-000032','2026-09-05','2026-09-05','ejecutado','egreso','CAT-E-02-01','CTP-0012',null,'escaladas-alocadas-2026-09-04','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Anfitrión de Escaladas Alocadas','PEN',150,1,'CTA-BCP-PEN',null,'MTD-YAPE',false,false,'recibo_honorarios','RH-0307',null,null),
('MOV-2026-000033','2026-09-05','2026-09-05','ejecutado','ingreso','CAT-I-04-01','CTP-0019',null,'escaladas-alocadas-2026-09-04','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tips de la comunidad en PEAK','PEN',75,1,'CTA-MERCADOPAGO',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),

-- ── Streams que todavía no ocurrieron: comprometido ──
('MOV-2026-000034','2026-09-12',null,'comprometido','egreso','CAT-E-02-01','CTP-0015',null,'noche-de-impostores-2026-09-11','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Observer de la Noche de Impostores del 11','PEN',120,1,'CTA-BCP-PEN',null,'MTD-YAPE',false,false,'ninguno',null,null,null),
('MOV-2026-000035','2026-09-14',null,'comprometido','egreso','CAT-E-02-01','CTP-0012',null,'roblox-insano-2026-09-13','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Anfitrión del Roblox Insano del 13','PEN',150,1,'CTA-BCP-PEN',null,'MTD-YAPE',false,false,'ninguno',null,null,null),

-- ── Canje 1 · Kuntur entrega periféricos a cambio de activación ──
('MOV-2026-000036','2026-09-05','2026-09-05','ejecutado','ingreso','CAT-I-01-02','CTP-0004',null,'circuito-trufas-2026-3','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Canje Kuntur — activación valorizada, lado ingreso','PEN',3000,1,null,null,'MTD-ESPECIE',true,false,'factura','F001-00036',457.63,null),
('MOV-2026-000037','2026-09-05','2026-09-05','ejecutado','egreso','CAT-E-01-02','CTP-0004',null,'circuito-trufas-2026-3','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Canje Kuntur — periféricos para premiar, lado egreso','PEN',3000,1,null,null,'MTD-ESPECIE',true,false,'factura','F-2210',457.63,null),

-- ── Canje 2 · Aurora Tech entrega una PC que Trufas usa: activo fijo ──
('MOV-2026-000038','2026-08-28','2026-08-28','ejecutado','ingreso','CAT-I-01-02','CTP-0001',null,'EVT-GENERAL','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Canje Aurora Tech — activación anual valorizada, lado ingreso','PEN',4500,1,null,null,'MTD-ESPECIE',true,false,'factura','F001-00038',686.44,null),
('MOV-2026-000039','2026-08-28','2026-08-28','ejecutado','egreso','CAT-E-04-04','CTP-0001',null,'EVT-GENERAL','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Canje Aurora Tech — PC de producción sobre el corte de la UIT, se activa','PEN',4500,1,null,null,'MTD-ESPECIE',true,true,'factura','F-1187',686.44,null),

-- ── Canje sin pareja · contingencia de IGV sin efectivo ──
('MOV-2026-000040','2026-09-07','2026-09-07','ejecutado','ingreso','CAT-I-01-02','CTP-0005',null,'sorteo-nitro-2026-09-30','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Canje Café Quilla sin facturar ni emparejar — contingencia abierta','PEN',1200,1,null,null,'MTD-ESPECIE',true,false,'ninguno',null,null,null),

-- ── Riesgo de bancarización · D. Leg. 1529 ──
('MOV-2026-000041','2026-09-01','2026-09-01','ejecutado','ingreso','CAT-I-01-01','CTP-0002',null,'circuito-trufas-2026-3','DEP-ESPORTS','FND-OPERATIVO',null,'[PRUEBA] Patrocinio Cripto Andina en USDT, liquidado al banco el mismo día','USDT',800,3.78,'CTA-BINANCE','CTA-BCP-USD','MTD-CRIPTO',false,false,'factura','F001-00041',461.29,'https://drive.test/trufas/F001-00041.pdf'),
('MOV-2026-000042','2026-09-06','2026-09-06','ejecutado','ingreso','CAT-I-04-01','CTP-0019',null,'EVT-GENERAL','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Tips acumulados en USDT sin liquidar al banco — puente sin documentar','USDT',600,3.78,'CTA-BINANCE',null,'MTD-CRIPTO',false,false,'ninguno',null,null,null),
('MOV-2026-000043','2026-09-03','2026-09-03','ejecutado','ingreso','CAT-I-01-02','CTP-0006',null,'circuito-trufas-2026-3','DEP-ESPORTS','FND-OPERATIVO','ITM-ACT-PUNTUAL','[PRUEBA] Activación cobrada por PayPal sobre US$ 500 sin liquidar al banco','USD',550,3.75,'CTA-PAYPAL',null,'MTD-PAYPAL',false,false,'factura','F001-00043',314.62,null),
('MOV-2026-000044','2026-09-05','2026-09-08','ejecutado','egreso','CAT-E-02-05','CTP-0009',null,'circuito-trufas-2026-3','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Adelanto del local pagado en efectivo — sobre el umbral, gasto reparable','PEN',2500,1,'CTA-CAJA',null,'MTD-EFECTIVO',false,false,'factura','F-3390',381.36,null),

-- ── Spread de la conversión ──
('MOV-2026-000045','2026-09-02','2026-09-02','ejecutado','egreso','CAT-E-07-04',null,null,'EVT-GENERAL','DEP-FINANZAS','FND-OPERATIVO',null,'[PRUEBA] Spread de la conversión USDT a PEN en la liquidación','PEN',45.36,1,'CTA-BINANCE',null,'MTD-CRIPTO',false,false,'ninguno',null,null,null),

-- ── Estructural · no imputable a un evento ──
('MOV-2026-000046','2026-08-25','2026-08-25','ejecutado','egreso','CAT-E-06-01','CTP-0011',null,'EVT-GENERAL','DEP-FINANZAS','FND-OPERATIVO',null,'[PRUEBA] Servicio contable de agosto','PEN',800,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'factura','F-5501',122.03,null),
('MOV-2026-000047','2026-08-25','2026-08-25','ejecutado','egreso','CAT-E-04-01','CTP-0010',null,'EVT-GENERAL','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Hosting y dominio somostrufas.org, anual','PEN',420,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'factura','F-6601',64.07,null),
('MOV-2026-000048','2026-09-01','2026-09-01','ejecutado','egreso','CAT-E-04-02',null,null,'EVT-GENERAL','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Suscripciones de trabajo del mes','PEN',189,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'boleta','B-1901',28.83,null),
('MOV-2026-000049','2026-09-01','2026-09-01','ejecutado','egreso','CAT-E-02-03',null,null,'EVT-GENERAL','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Software de streaming, licencia mensual','PEN',320,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'factura','F-7101',48.81,null),
('MOV-2026-000050','2026-08-31','2026-08-31','ejecutado','egreso','CAT-E-07-03',null,null,'EVT-GENERAL','DEP-FINANZAS','FND-OPERATIVO',null,'[PRUEBA] ITF de agosto','PEN',8.40,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000051','2026-08-31','2026-08-31','ejecutado','egreso','CAT-E-07-02',null,null,'EVT-GENERAL','DEP-FINANZAS','FND-OPERATIVO',null,'[PRUEBA] Mantenimiento de cuenta y comisiones del mes','PEN',35,1,'CTA-BCP-PEN',null,'MTD-TRANSFERENCIA',false,false,'ninguno',null,null,null),
('MOV-2026-000052','2026-09-02','2026-09-02','ejecutado','egreso','CAT-E-04-04',null,null,'EVT-GENERAL','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Teclado de repuesto — bajo un cuarto de la UIT, va a gasto','PEN',300,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'boleta','B-1902',45.76,null),
('MOV-2026-000053','2026-09-01','2026-09-01','ejecutado','egreso','CAT-E-09-02',null,null,'EVT-GENERAL','DEP-OPERACIONES','FND-OPERATIVO',null,'[PRUEBA] Internet y telefonía del mes','PEN',120,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'boleta','B-1903',18.31,null),

-- ── Se anulan más abajo, para ejercitar el borrado lógico y la auditoría ──
('MOV-2026-000054','2026-09-06','2026-09-06','ejecutado','egreso','CAT-E-03-01',null,null,'circuito-trufas-2026-3','DEP-MARKETING','FND-OPERATIVO',null,'[PRUEBA] Pauta de refuerzo del anuncio del Circuito','PEN',900,1,'CTA-BCP-PEN',null,'MTD-TARJETA',false,false,'ninguno',null,null,null),
('MOV-2026-000055','2026-09-07','2026-09-07','ejecutado','ingreso','CAT-I-04-02','CTP-0020',null,'EVT-GENERAL','DEP-DIRECCION','FND-BENEFICO',null,'[PRUEBA] Donación particular de setiembre','PEN',500,1,'CTA-BCP-PEN',null,'MTD-DEPOSITO',false,false,'ninguno',null,null,null);

select setval('finanzas.seq_movimientos', 55);

-- ---------------------------------------------------------------------
-- Emparejar los canjes. El trigger exige tipo opuesto e igual
-- valorización en ambos lados, así que esto también lo verifica.
-- ---------------------------------------------------------------------
update finanzas.reg_movimientos set contrapartida_id = 'MOV-2026-000037' where id = 'MOV-2026-000036';
update finanzas.reg_movimientos set contrapartida_id = 'MOV-2026-000036' where id = 'MOV-2026-000037';
update finanzas.reg_movimientos set contrapartida_id = 'MOV-2026-000039' where id = 'MOV-2026-000038';
update finanzas.reg_movimientos set contrapartida_id = 'MOV-2026-000038' where id = 'MOV-2026-000039';

-- ---------------------------------------------------------------------
-- Anular dos movimientos. Nunca se borran: la columna estado distingue
-- activo de anulado, y fn_sella_auditoria pone anulado_en.
-- ---------------------------------------------------------------------
update finanzas.reg_movimientos
   set estado = 'anulado',
       motivo_anulacion = '[PRUEBA] Cargo duplicado de la pasarela, revertido por el banco.'
 where id = 'MOV-2026-000054';

update finanzas.reg_movimientos
   set estado = 'anulado',
       motivo_anulacion = '[PRUEBA] Registrada dos veces en la conciliación de setiembre.'
 where id = 'MOV-2026-000055';

-- =====================================================================
-- REG_IMPACTO · 14 filas
-- pasa_por_caja separa lo recaudado por Trufas de lo facilitado.
-- Lo que el patrocinador entrega directo al beneficiario va solo aquí,
-- con origen = patrocinador: así el P&L no infla gastos que Trufas no
-- pagó, pero el informe público mantiene el impacto total.
-- =====================================================================
insert into finanzas.reg_impacto
  (id, fecha, beneficiario_id, evento_id, tipo_aporte, pasa_por_caja, origen,
   monto, evidencia_url, publicado, descripcion) values
  ('IMP-2026-00001','2026-08-27','CTP-0016','noche-de-karaoke-2026-08-26',      'efectivo', true,  'comunidad',     65, 'https://drive.test/trufas/acta-2026-08-27.pdf', true,  '[PRUEBA] Tips del karaoke destinados al albergue.'),
  ('IMP-2026-00002','2026-08-29','CTP-0017','noche-de-impostores-2026-08-28',   'efectivo', true,  'comunidad',     40, 'https://drive.test/trufas/acta-2026-08-29.pdf', true,  '[PRUEBA] Tips del stream destinados al comedor.'),
  ('IMP-2026-00003','2026-08-31','CTP-0016','roblox-insano-2026-08-30',         'efectivo', true,  'donante',      200, 'https://drive.test/trufas/acta-2026-08-31.pdf', true,  '[PRUEBA] Donación de un espectador canalizada al albergue.'),
  ('IMP-2026-00004','2026-09-01','CTP-0017','sorteo-nitro-2026-08-31',          'efectivo', true,  'comunidad',     85, 'https://drive.test/trufas/acta-2026-09-01.pdf', true,  '[PRUEBA] Tips del sorteo destinados al comedor.'),
  ('IMP-2026-00005','2026-09-02','CTP-0018','sorteo-juego-eleccion',            'especie',  false, 'patrocinador', 320, 'https://drive.test/trufas/acta-2026-09-02.pdf', true,  '[PRUEBA] La tienda entregó el juego directo al ganador. Trufas facilitó, no recaudó.'),
  ('IMP-2026-00006','2026-09-03','CTP-0016','noche-de-karaoke-2026-09-02',      'efectivo', true,  'comunidad',     55, 'https://drive.test/trufas/acta-2026-09-03.pdf', true,  '[PRUEBA] Tips del karaoke destinados al albergue.'),
  ('IMP-2026-00007','2026-09-05','CTP-0017','escaladas-alocadas-2026-09-04',    'efectivo', true,  'comunidad',     75, 'https://drive.test/trufas/acta-2026-09-05.pdf', true,  '[PRUEBA] Tips del stream destinados al comedor.'),
  ('IMP-2026-00008','2026-09-05','CTP-0018','circuito-trufas-2026-3',           'especie',  false, 'patrocinador',3000, 'https://drive.test/trufas/acta-2026-09-05b.pdf',true,  '[PRUEBA] Periféricos del canje destinados a la biblioteca.'),
  ('IMP-2026-00009','2026-09-06','CTP-0016','EVT-GENERAL',                      'efectivo', true,  'donante',      250, 'https://drive.test/trufas/acta-2026-09-06.pdf', true,  '[PRUEBA] Donación particular canalizada al albergue.'),
  ('IMP-2026-00010','2026-09-07','CTP-0017','EVT-GENERAL',                      'efectivo', true,  'donante',      500, 'https://drive.test/trufas/acta-2026-09-07.pdf', true,  '[PRUEBA] Donación de setiembre canalizada al comedor.'),
  ('IMP-2026-00011','2026-09-08','CTP-0018','sorteo-valorant-points-2026-09-20','especie',  false, 'patrocinador', 180, 'https://drive.test/trufas/acta-2026-09-08.pdf', true,  '[PRUEBA] La marca entregó los Valorant Points directo al ganador.'),
  ('IMP-2026-00012','2026-09-08','CTP-0016','noche-de-camaleones-2026-09-03',   'servicio', false, 'comunidad',    130, 'https://drive.test/trufas/acta-2026-09-08b.pdf',true,  '[PRUEBA] Taller dictado por la comunidad en el albergue. Valorizado, sin pasar por caja.'),
  ('IMP-2026-00013','2026-09-09','CTP-0017','EVT-GENERAL',                      'efectivo', true,  'trufas',       400, null,                                            false, '[PRUEBA] Sin evidencia adjunta todavía: no publicable.'),
  ('IMP-2026-00014','2026-09-09','CTP-0018','circuito-trufas-2026-3',           'especie',  false, 'patrocinador', 900, 'https://drive.test/trufas/acta-2026-09-09.pdf', false, '[PRUEBA] Pendiente de revisión antes de publicar.');

select setval('finanzas.seq_impacto', 14);

-- =====================================================================
-- REG_ACUERDOS · 8 filas · el índice del contrato, no el contrato
-- =====================================================================
insert into finanzas.reg_acuerdos
  (id, contraparte_id, tipo, evento_id, depto_id, item_id, descripcion,
   moneda, monto_pactado, tc, incluye_especie,
   fecha_firma, fecha_inicio, fecha_fin, estado_acuerdo, url_contrato) values
  ('ACU-2026-0001','CTP-0001','patrocinio','circuito-trufas-2026-3','DEP-ESPORTS','ITM-PAQ-ORO',   '[PRUEBA] Paquete Oro Aurora Tech para el Circuito 2026-3','PEN',12000,1,   false,'2026-08-20','2026-09-01','2027-01-31','vigente', 'https://drive.test/trufas/contrato-aurora-2026-3.pdf'),
  ('ACU-2026-0002','CTP-0003','patrocinio','circuito-trufas-2026-3','DEP-ESPORTS','ITM-NAMING',    '[PRUEBA] Naming del Circuito Trufas 2026-3','PEN',20000,1,   false,'2026-08-22','2026-09-01','2027-01-31','vigente', 'https://drive.test/trufas/contrato-wayra-2026-3.pdf'),
  ('ACU-2026-0003','CTP-0005','patrocinio','circuito-trufas-2026-3','DEP-ESPORTS','ITM-PAQ-PLATA', '[PRUEBA] Paquete Plata Café Quilla para el Circuito 2026-3','PEN',6000,1,    false,'2026-08-25','2026-09-01','2027-01-31','vigente', 'https://drive.test/trufas/contrato-quilla-2026-3.pdf'),
  ('ACU-2026-0004','CTP-0002','patrocinio','circuito-trufas-2026-3','DEP-ESPORTS',null,            '[PRUEBA] Patrocinio Cripto Andina pactado en dólares, cobrado en USDT','USD',800,3.75,false,'2026-08-26','2026-09-01','2026-09-30','cumplido','https://drive.test/trufas/contrato-cripto-2026-3.pdf'),
  ('ACU-2026-0005','CTP-0004','patrocinio','circuito-trufas-2026-3','DEP-ESPORTS',null,            '[PRUEBA] Canje Kuntur: periféricos a cambio de activación','PEN',3000,1,    true, '2026-09-01','2026-09-01','2026-09-30','cumplido','https://drive.test/trufas/contrato-kuntur-canje.pdf'),
  ('ACU-2026-0006','CTP-0006','patrocinio','sorteo-valorant-points-2026-09-20','DEP-ESPORTS','ITM-ACT-PUNTUAL','[PRUEBA] Telecom Sierra Norte patrocina dos sorteos','PEN',2000,1,false,'2026-08-30','2026-08-31','2026-09-30','vigente','https://drive.test/trufas/contrato-tsn-sorteos.pdf'),
  ('ACU-2026-0007','CTP-0004','afiliacion','EVT-GENERAL','DEP-MARKETING',null,                     '[PRUEBA] Programa de referidos Kuntur, comisión trimestral','PEN',6000,1,   false,'2026-08-01','2026-08-15','2027-08-14','vigente', 'https://drive.test/trufas/contrato-kuntur-afiliados.pdf'),
  ('ACU-2026-0008','CTP-0006','patrocinio','circuito-trufas-2026-3','DEP-ESPORTS',null,            '[PRUEBA] Propuesta de patrocinio principal del próximo ciclo, sin firmar','PEN',30000,1,false,null,'2026-12-01','2027-06-30','borrador',null);

select setval('finanzas.seq_acuerdos', 8);

-- =====================================================================
-- REG_ACUERDO_CUOTAS · 13 filas
-- El cronograma alimenta el flujo proyectado y las alertas de
-- vencimiento. movimiento_id nulo es una cuota que todavía no entró;
-- si además su fecha ya pasó, es una cuota vencida.
-- =====================================================================
insert into finanzas.reg_acuerdo_cuotas
  (id, acuerdo_id, nro_cuota, fecha_prevista, moneda, monto, tc, movimiento_id) values
  ('CUO-2026-0001','ACU-2026-0001',1,'2026-11-30','PEN',12000,1,   null),
  ('CUO-2026-0002','ACU-2026-0002',1,'2026-12-05','PEN',20000,1,   null),
  ('CUO-2026-0003','ACU-2026-0003',1,'2026-12-10','PEN',6000,1,    null),
  ('CUO-2026-0004','ACU-2026-0004',1,'2026-09-01','USD',800,3.78,  'MOV-2026-000041'),
  ('CUO-2026-0005','ACU-2026-0005',1,'2026-09-05','PEN',3000,1,    'MOV-2026-000036'),
  ('CUO-2026-0006','ACU-2026-0006',1,'2026-09-02','PEN',1200,1,    'MOV-2026-000020'),
  ('CUO-2026-0007','ACU-2026-0006',2,'2026-09-05','PEN',800,1,     null),
  ('CUO-2026-0008','ACU-2026-0007',1,'2026-08-31','PEN',850,1,     'MOV-2026-000013'),
  ('CUO-2026-0009','ACU-2026-0007',2,'2026-11-30','PEN',1500,1,    null),
  ('CUO-2026-0010','ACU-2026-0007',3,'2027-02-28','PEN',1500,1,    null),
  ('CUO-2026-0011','ACU-2026-0007',4,'2027-05-31','PEN',1500,1,    null),
  ('CUO-2026-0012','ACU-2026-0008',1,'2026-12-15','PEN',15000,1,   null),
  ('CUO-2026-0013','ACU-2026-0008',2,'2027-01-15','PEN',15000,1,   null);

-- =====================================================================
-- REG_PRESUPUESTO · 10 filas
-- Se congela al aprobarse y nunca se edita. Los cambios entran como
-- versiones nuevas: PRE-00006 es la v1 superada y PRE-00007 la v2 vigente.
-- =====================================================================
insert into finanzas.reg_presupuesto
  (id, alcance, depto_id, anio, trimestre, evento_id, categoria_id, tipo,
   monto_pen, version, vigente, congelado_en, aprobado_por, notas) values
  ('PRE-00001','departamento_trimestre','DEP-MARKETING',   2026,3,null,null,'egreso',  3000, 1,true, '2026-06-28 10:00:00-05','Dirección de Finanzas','[PRUEBA] Pauta y creadores del tercer trimestre.'),
  ('PRE-00002','departamento_trimestre','DEP-OPERACIONES', 2026,3,null,null,'egreso',  4000, 1,true, '2026-06-28 10:00:00-05','Dirección de Finanzas','[PRUEBA] Talento de streams, plataforma y software.'),
  ('PRE-00003','departamento_trimestre','DEP-ESPORTS',     2026,3,null,null,'egreso',  2000, 1,true, '2026-06-28 10:00:00-05','Dirección de Finanzas','[PRUEBA] Premios de sorteos del trimestre.'),
  ('PRE-00004','departamento_trimestre','DEP-FINANZAS',    2026,3,null,null,'egreso',  1500, 1,true, '2026-06-28 10:00:00-05','Dirección de Finanzas','[PRUEBA] Contabilidad, comisiones y tributos.'),
  ('PRE-00005','departamento_trimestre','DEP-ESPORTS',     2026,3,null,null,'ingreso', 8000, 1,true, '2026-06-28 10:00:00-05','Dirección de Finanzas','[PRUEBA] Meta de patrocinios del tercer trimestre.'),
  ('PRE-00006','departamento_trimestre','DEP-MARKETING',   2026,4,null,null,'egreso',  5000, 1,false,'2026-09-01 10:00:00-05','Dirección de Finanzas','[PRUEBA] Línea base del cuarto trimestre. Superada por la versión 2; se conserva para el KPI de variación.'),
  ('PRE-00007','departamento_trimestre','DEP-MARKETING',   2026,4,null,null,'egreso',  7000, 2,true, '2026-09-05 10:00:00-05','Dirección de Finanzas','[PRUEBA] Versión 2 del cuarto trimestre, aprobada al sumar la campaña del Circuito.'),
  ('PRE-00008','evento',null,null,null,'circuito-trufas-2026-3',null,'egreso',30000,1,true,'2026-08-18 10:00:00-05','CEO','[PRUEBA] Presupuesto de egresos del Circuito Trufas 2026-3.'),
  ('PRE-00009','evento',null,null,null,'circuito-trufas-2026-3',null,'ingreso',42000,1,true,'2026-08-18 10:00:00-05','CEO','[PRUEBA] Meta de ingresos del Circuito Trufas 2026-3.'),
  ('PRE-00010','evento',null,null,null,'sorteo-nitro-2026-09-30',null,'egreso',500,1,true,null,null,'[PRUEBA] Borrador del sorteo de setiembre: sin congelar todavía, así que aún admite edición.');

select setval('finanzas.seq_presupuesto', 10);
