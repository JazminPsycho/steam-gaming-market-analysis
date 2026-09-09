-- =====================================================================
-- 0008 · Semilla de catálogos
--
-- Datos de configuración, no de prueba. Esto es la forma real de operar
-- de Somos Trufas: el árbol de categorías del documento, el plan de
-- cuentas PCGE en borrador y las cuentas y métodos con los que se cobra.
-- =====================================================================

-- Fondos: operativo frente a benéfico restringido
insert into finanzas.cat_fondos (id, nombre, tipo, restringido, descripcion) values
  ('FND-OPERATIVO', 'Fondo operativo', 'operativo', false,
   'Financia la operación de la empresa. Es el fondo por defecto de todo movimiento.'),
  ('FND-BENEFICO', 'Fondo benéfico restringido', 'benefico_restringido', true,
   'Donaciones con destino restringido. No puede financiar gasto operativo: es la base del informe público.');

-- Departamentos: centros de costo. Nombres por confirmar contra el organigrama.
insert into finanzas.cat_departamentos (id, nombre, responsable, descripcion) values
  ('DEP-GENERAL',     'General / no imputable', null,
   'Absorbe lo que no pertenece a un departamento concreto. Toda fila lleva depto_id, aunque sea este.'),
  ('DEP-DIRECCION',   'Dirección General',      'CEO', 'Dirección y gobierno de la empresa.'),
  ('DEP-FINANZAS',    'Finanzas',               'Director de Finanzas', 'Presupuesto, tesorería y conciliación.'),
  ('DEP-OPERACIONES', 'Operaciones',            'COO', 'Producción y ejecución de eventos.'),
  ('DEP-MARKETING',   'Marketing y Contenido',  null, 'Pauta, creadores, diseño y producción de contenido.'),
  ('DEP-ESPORTS',     'Esports y Competitivo',  null, 'Torneos, equipos y relación con la escena competitiva.');

-- Cuentas del sistema financiero primero: las cuentas puente las referencian.
insert into finanzas.cat_cuentas (id, nombre, tipo, institucion, moneda, es_sistema_financiero, notas) values
  ('CTA-BCP-PEN', 'Cuenta corriente BCP soles',   'banco', 'BCP', 'PEN', true,
   'Cuenta de la SAC. Destino de los patrocinios de S/ 2 000 o más.'),
  ('CTA-BCP-USD', 'Cuenta corriente BCP dólares', 'banco', 'BCP', 'USD', true,
   'Cuenta de la SAC. Destino de los patrocinios de US$ 500 o más.');

insert into finanzas.cat_cuentas
  (id, nombre, tipo, institucion, moneda, es_sistema_financiero, liquida_en_cuenta_id, notas) values
  ('CTA-BINANCE', 'Billetera Binance', 'billetera', 'Binance', 'USDT', false, 'CTA-BCP-USD',
   'Binance no es una Empresa del Sistema Financiero supervisada por la SBS. Tolerable para tips y montos chicos, siempre que se liquide a cuenta bancaria y el puente quede registrado.'),
  ('CTA-PAYPAL', 'PayPal', 'pasarela', 'PayPal', 'USD', false, 'CTA-BCP-USD',
   'PayPal no es ESF en Perú. Lo que documenta la operación es la transferencia posterior a la cuenta bancaria de la SAC, no el movimiento dentro de PayPal.'),
  ('CTA-MERCADOPAGO', 'Mercado Pago', 'pasarela', 'Mercado Pago', 'PEN', false, 'CTA-BCP-PEN',
   'Pasarela de venta de entradas. Liquida a la cuenta en soles.'),
  ('CTA-CAJA', 'Caja chica', 'caja', null, 'PEN', false, null,
   'Efectivo. Solo para gastos menores: no es Medio de Pago sobre el umbral del D. Leg. 1529.');

-- Métodos de pago. es_medio_pago_valido según D. Leg. 1529.
insert into finanzas.cat_metodos (id, nombre, es_medio_pago_valido, descripcion) values
  ('MTD-TRANSFERENCIA', 'Transferencia bancaria',     true,
   'Medio de Pago válido. Emitida por una ESF supervisada por la SBS.'),
  ('MTD-DEPOSITO',      'Depósito en cuenta',         true,  'Medio de Pago válido.'),
  ('MTD-TARJETA',       'Tarjeta de crédito o débito',true,  'Medio de Pago válido: tarjeta emitida por una ESF.'),
  ('MTD-YAPE',          'Yape o Plin',                true,
   'Respaldado por una ESF, así que califica. Confirmar con el contador para montos sobre el umbral.'),
  ('MTD-EFECTIVO',      'Efectivo',                   false,
   'No es Medio de Pago. Sobre S/ 2 000 o US$ 500 el gasto puede ser reparado.'),
  ('MTD-CRIPTO',        'Cripto (USDT)',              false,
   'Binance no es ESF. La cripto recibida es ingreso valorizado en soles al tipo de cambio de la fecha.'),
  ('MTD-PAYPAL',        'PayPal',                     false,
   'No es ESF en Perú. Lo que documenta la operación es la liquidación posterior al banco.'),
  ('MTD-ESPECIE',       'Canje en especie',           false,
   'No hay movimiento de dinero. En Perú el canje es una permuta: dos operaciones con comprobante e IGV.');

-- =====================================================================
-- Plan de cuentas PCGE · BORRADOR POR VALIDAR
-- Res. CNC 002-2019-EF/30, obligatorio para el sector privado desde
-- el 1 de enero de 2020. mef.gob.pe/contenidos/conta_publ/pcge/PCGE_2019.pdf
--
-- El nivel de tres dígitos es firme. Las denominaciones de cuarto dígito
-- se derivaron de la estructura del PCGE y son correctas en estructura,
-- pero los literales exactos deben verificarse contra el PDF oficial.
-- Por eso validado = false en todas.
-- =====================================================================
insert into finanzas.cat_pcge (cuenta, denominacion, naturaleza, en_disputa, notas) values
  -- Ingresos
  ('7041', 'Prestación de servicios — terceros',              'ingreso', false, null),
  ('752',  'Comisiones y corretajes',                          'ingreso', false, null),
  ('7592', 'Otros ingresos de gestión — donaciones',           'ingreso', false, null),
  ('776',  'Diferencia en cambio',                             'ingreso', true,
   'Punto en disputa 2: el spread USDT a PEN va aquí o como comisión, según cómo se documente la operación.'),
  -- Gastos
  ('6211', 'Sueldos y salarios',                               'gasto', false, null),
  ('6271', 'Régimen de prestaciones de salud',                 'gasto', false,
   'Aportes de planilla. La categoría Personal -> Planilla apunta a 6211; los aportes se separan aquí en los libros.'),
  ('6311', 'Transporte',                                       'gasto', false, null),
  ('6322', 'Asesoría y consultoría — legal y tributaria',      'gasto', false, null),
  ('6323', 'Asesoría y consultoría — auditoría y contable',    'gasto', false, null),
  ('6324', 'Asesoría y consultoría — mercadotecnia',           'gasto', false, null),
  ('6329', 'Asesoría y consultoría — otros',                   'gasto', false, null),
  ('6352', 'Alquileres — edificaciones',                       'gasto', false, null),
  ('6364', 'Servicios básicos — teléfono',                     'gasto', false,
   'Sin categoría de gestión asignada: Administrativos -> Comunicaciones apunta a 6365.'),
  ('6365', 'Servicios básicos — internet',                     'gasto', false, null),
  ('6371', 'Publicidad',                                       'gasto', false, null),
  ('6373', 'Relaciones públicas',                              'gasto', false, null),
  ('6391', 'Otros servicios — gastos bancarios',               'gasto', true,
   'Punto en disputa 1: conceptualmente son gasto financiero (679), pero la práctica extendida las lleva aquí como servicio de terceros.'),
  ('6399', 'Otros servicios prestados por terceros',           'gasto', false, null),
  ('6411', 'Gobierno nacional — IGV e ISC',                    'gasto', false, null),
  ('6412', 'Gobierno nacional — ITF',                          'gasto', false, null),
  ('6419', 'Gobierno nacional — otros',                        'gasto', false, null),
  ('6433', 'Gobierno local — tasas',                           'gasto', false, null),
  ('651',  'Seguros',                                          'gasto', false,
   'Sin categoría de gestión asignada todavía. Cuelga de Administrativos cuando exista la línea.'),
  ('653',  'Suscripciones',                                    'gasto', false, null),
  ('654',  'Licencias y derechos de vigencia',                 'gasto', false, null),
  ('656',  'Suministros',                                      'gasto', false, null),
  ('6591', 'Otros gastos de gestión — donaciones',             'gasto', false, null),
  ('6592', 'Sanciones administrativas fiscales',               'gasto', false, null),
  ('6599', 'Otros gastos de gestión',                          'gasto', true,
   'Punto en disputa 4: el asiento del canje. Genera comprobante e IGV en ambas direcciones y un error acá sí tiene consecuencia tributaria.'),
  ('676',  'Diferencia en cambio',                             'gasto', true,
   'Punto en disputa 2: ver 776. Depende de cómo se documente la conversión.'),
  ('6799', 'Otros gastos financieros',                         'gasto', true,
   'Punto en disputa 1: alternativa a 6391 para comisiones de pasarela y banco.'),
  ('6814', 'Depreciación de IME — costo',                      'gasto', false,
   'Depreciación de los equipos activados en 3361 y 3362. No hay categoría de gestión: no es un movimiento de caja.'),
  -- Activo
  ('3361', 'Equipos diversos — procesamiento de información',  'activo', true,
   'Punto en disputa 3: el corte de un cuarto de la UIT define si un equipo va aquí o directo a gasto. Requiere la UIT vigente.'),
  ('3362', 'Equipos diversos — comunicación',                  'activo', false,
   'Equipos de audio y captura. La categoría Tecnología -> Equipos apunta a 3361; el contador separa según el bien.');

-- =====================================================================
-- Árbol de categorías · CERRADO
-- Seis líneas de ingreso, nueve de egreso. El nivel 1 solo lo modifica
-- el CEO. cuenta_pcge se mapea en nivel 2, donde se clasifican los
-- movimientos; el nivel 1 queda nulo.
-- =====================================================================

-- Nivel 1 · ingresos
insert into finanzas.cat_categorias (id, tipo, nivel, padre_id, nombre, orden, activo) values
  ('CAT-I-01', 'ingreso', 1, null, 'Patrocinios',           1, true),
  ('CAT-I-02', 'ingreso', 1, null, 'Referidos y afiliados', 2, true),
  ('CAT-I-03', 'ingreso', 1, null, 'Venta de entradas',     3, true),
  ('CAT-I-04', 'ingreso', 1, null, 'Donaciones y tips',     4, true),
  ('CAT-I-05', 'ingreso', 1, null, 'Servicios',             5, false),
  ('CAT-I-06', 'ingreso', 1, null, 'Otros ingresos',        6, true);

-- Nivel 1 · egresos
insert into finanzas.cat_categorias (id, tipo, nivel, padre_id, nombre, orden, activo) values
  ('CAT-E-01', 'egreso', 1, null, 'Premios y entregas',        1, true),
  ('CAT-E-02', 'egreso', 1, null, 'Producción de eventos',     2, true),
  ('CAT-E-03', 'egreso', 1, null, 'Marketing y contenido',     3, true),
  ('CAT-E-04', 'egreso', 1, null, 'Tecnología',                4, true),
  ('CAT-E-05', 'egreso', 1, null, 'Personal y colaboradores',  5, true),
  ('CAT-E-06', 'egreso', 1, null, 'Servicios profesionales',   6, true),
  ('CAT-E-07', 'egreso', 1, null, 'Gastos financieros',        7, true),
  ('CAT-E-08', 'egreso', 1, null, 'Tributos',                  8, true),
  ('CAT-E-09', 'egreso', 1, null, 'Administrativos',           9, true);

-- Nivel 2 · ingresos
insert into finanzas.cat_categorias (id, tipo, nivel, padre_id, nombre, cuenta_pcge, orden, activo, notas) values
  ('CAT-I-01-01', 'ingreso', 2, 'CAT-I-01', 'Paquete de temporada',            '7041', 1, true, null),
  ('CAT-I-01-02', 'ingreso', 2, 'CAT-I-01', 'Activación puntual',              '7041', 2, true, null),
  ('CAT-I-01-03', 'ingreso', 2, 'CAT-I-01', 'Naming de torneo',                '7041', 3, true, null),
  ('CAT-I-02-01', 'ingreso', 2, 'CAT-I-02', 'Comisión por referido',           '752',  1, true, null),
  ('CAT-I-02-02', 'ingreso', 2, 'CAT-I-02', 'Bonos de campaña',                '752',  2, true, null),
  ('CAT-I-03-01', 'ingreso', 2, 'CAT-I-03', 'Entrada general',                 '7041', 1, true,
   'Se registra agregada por evento y día, no ticket por ticket.'),
  ('CAT-I-03-02', 'ingreso', 2, 'CAT-I-03', 'Entrada preferencial',            '7041', 2, true,
   'Se registra agregada por evento y día, no ticket por ticket.'),
  ('CAT-I-04-01', 'ingreso', 2, 'CAT-I-04', 'Tips en stream',                  '7592', 1, true, null),
  ('CAT-I-04-02', 'ingreso', 2, 'CAT-I-04', 'Donación general',                '7592', 2, true, null),
  ('CAT-I-04-03', 'ingreso', 2, 'CAT-I-04', 'Donación con destino restringido','7592', 3, true,
   'Va al fondo FND-BENEFICO. No puede financiar gasto operativo.'),
  ('CAT-I-05-01', 'ingreso', 2, 'CAT-I-05', 'Configuración de Discord',        '7041', 1, false, null),
  ('CAT-I-05-02', 'ingreso', 2, 'CAT-I-05', 'Producción para terceros',        '7041', 2, false, null),
  ('CAT-I-06-01', 'ingreso', 2, 'CAT-I-06', 'Diferencia de cambio favorable',  '776',  1, true, null),
  ('CAT-I-06-02', 'ingreso', 2, 'CAT-I-06', 'Recuperos',                       null,   2, true,
   'Sin cuenta PCGE asignada. Pendiente de criterio del contador.');

-- Nivel 2 · egresos
insert into finanzas.cat_categorias (id, tipo, nivel, padre_id, nombre, cuenta_pcge, orden, activo, notas) values
  ('CAT-E-01-01', 'egreso', 2, 'CAT-E-01', 'Premio en efectivo',              '6599', 1, true,
   'Solo los premios que salen de la cuenta de Trufas. Los que el patrocinador entrega directo al ganador van únicamente a REG_IMPACTO con origen = patrocinador.'),
  ('CAT-E-01-02', 'egreso', 2, 'CAT-E-01', 'Premio en especie',               '6599', 2, true, null),
  ('CAT-E-01-03', 'egreso', 2, 'CAT-E-01', 'Entrega a beneficiario',          '6591', 3, true, null),
  ('CAT-E-02-01', 'egreso', 2, 'CAT-E-02', 'Talento y casters',               '6399', 1, true, null),
  ('CAT-E-02-02', 'egreso', 2, 'CAT-E-02', 'Plataforma de torneo',            '6399', 2, true, null),
  ('CAT-E-02-03', 'egreso', 2, 'CAT-E-02', 'Software de streaming',           '653',  3, true, null),
  ('CAT-E-02-04', 'egreso', 2, 'CAT-E-02', 'Arte del evento',                 '6599', 4, true, null),
  ('CAT-E-02-05', 'egreso', 2, 'CAT-E-02', 'Local',                           '6352', 5, true, null),
  ('CAT-E-03-01', 'egreso', 2, 'CAT-E-03', 'Pauta publicitaria',              '6371', 1, true, null),
  ('CAT-E-03-02', 'egreso', 2, 'CAT-E-03', 'Creadores y colaboraciones',      '6373', 2, true, null),
  ('CAT-E-03-03', 'egreso', 2, 'CAT-E-03', 'Diseño y branding',               '6324', 3, true, null),
  ('CAT-E-03-04', 'egreso', 2, 'CAT-E-03', 'Producción de contenido',         '6399', 4, true, null),
  ('CAT-E-04-01', 'egreso', 2, 'CAT-E-04', 'Hosting y dominios',              '6399', 1, true, null),
  ('CAT-E-04-02', 'egreso', 2, 'CAT-E-04', 'Suscripciones SaaS',              '653',  2, true, null),
  ('CAT-E-04-03', 'egreso', 2, 'CAT-E-04', 'Licencias de software',           '654',  3, true, null),
  ('CAT-E-04-04', 'egreso', 2, 'CAT-E-04', 'Equipos y hardware',              '3361', 4, true,
   'Con es_activo_fijo = true va a 3361 o 3362 y se deprecia. Bajo un cuarto de la UIT puede deducirse como gasto del ejercicio.'),
  ('CAT-E-05-01', 'egreso', 2, 'CAT-E-05', 'Honorarios',                      '6329', 1, true, null),
  ('CAT-E-05-02', 'egreso', 2, 'CAT-E-05', 'Planilla',                        '6211', 2, true,
   'Los aportes al régimen de prestaciones de salud se separan en 6271 en los libros del contador.'),
  ('CAT-E-05-03', 'egreso', 2, 'CAT-E-05', 'Incentivos',                      '6211', 3, true, null),
  ('CAT-E-06-01', 'egreso', 2, 'CAT-E-06', 'Contabilidad',                    '6323', 1, true, null),
  ('CAT-E-06-02', 'egreso', 2, 'CAT-E-06', 'Legal y notarial',                '6322', 2, true, null),
  ('CAT-E-06-03', 'egreso', 2, 'CAT-E-06', 'Consultoría',                     '6329', 3, true, null),
  ('CAT-E-07-01', 'egreso', 2, 'CAT-E-07', 'Comisión de pasarela',            '6391', 1, true,
   'Punto en disputa: 6391 frente a 679.'),
  ('CAT-E-07-02', 'egreso', 2, 'CAT-E-07', 'Comisión bancaria',               '6391', 2, true,
   'Punto en disputa: 6391 frente a 679.'),
  ('CAT-E-07-03', 'egreso', 2, 'CAT-E-07', 'ITF',                             '6412', 3, true, null),
  ('CAT-E-07-04', 'egreso', 2, 'CAT-E-07', 'Conversión y diferencia de cambio','676', 4, true,
   'Punto en disputa: el spread USDT a PEN como diferencia en cambio o como comisión.'),
  ('CAT-E-08-01', 'egreso', 2, 'CAT-E-08', 'Renta',                           '6419', 1, true, null),
  ('CAT-E-08-02', 'egreso', 2, 'CAT-E-08', 'Multas y moras',                  '6592', 2, true, null),
  ('CAT-E-08-03', 'egreso', 2, 'CAT-E-08', 'Tasas registrales',               '6433', 3, true, null),
  ('CAT-E-09-01', 'egreso', 2, 'CAT-E-09', 'Movilidad',                       '6311', 1, true, null),
  ('CAT-E-09-02', 'egreso', 2, 'CAT-E-09', 'Comunicaciones',                  '6365', 2, true, null),
  ('CAT-E-09-03', 'egreso', 2, 'CAT-E-09', 'Útiles',                          '656',  3, true, null);

-- Items vendibles. Precio de lista, no precio pactado.
insert into finanzas.cat_items (id, nombre, tipo, categoria_id, precio_lista, moneda, descripcion, activo) values
  ('ITM-PAQ-ORO',        'Paquete Oro',              'paquete_patrocinio', 'CAT-I-01-01', 12000, 'PEN',
   'Paquete de temporada: naming secundario, presencia en overlay y activaciones en los cuatro torneos del ciclo.', true),
  ('ITM-PAQ-PLATA',      'Paquete Plata',            'paquete_patrocinio', 'CAT-I-01-01',  6000, 'PEN',
   'Paquete de temporada: presencia en overlay y menciones de caster.', true),
  ('ITM-PAQ-BRONCE',     'Paquete Bronce',           'paquete_patrocinio', 'CAT-I-01-01',  2500, 'PEN',
   'Paquete de temporada: presencia en piezas gráficas y redes.', true),
  ('ITM-ACT-PUNTUAL',    'Activación puntual',       'activacion',         'CAT-I-01-02',  1800, 'PEN',
   'Activación de marca en un solo evento.', true),
  ('ITM-NAMING',         'Naming de torneo',         'activacion',         'CAT-I-01-03', 20000, 'PEN',
   'La marca da nombre al torneo durante todo el ciclo.', true),
  ('ITM-ENT-GENERAL',    'Entrada general',          'entrada',            'CAT-I-03-01',    20, 'PEN',
   'Se registra agregada por evento y día.', true),
  ('ITM-ENT-PREF',       'Entrada preferencial',     'entrada',            'CAT-I-03-02',    45, 'PEN',
   'Se registra agregada por evento y día.', true),
  ('ITM-DISCORD-BASICO', 'Discord — plan básico',    'plan_discord',       'CAT-I-05-01',   350, 'PEN',
   'Línea de servicios inactiva.', false),
  ('ITM-DISCORD-PRO',    'Discord — plan avanzado',  'plan_discord',       'CAT-I-05-01',   900, 'PEN',
   'Línea de servicios inactiva.', false);
