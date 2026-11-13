-- =====================================================================
-- Protocolo Z - 05: Dados iniciais (facções, itens, expedições)
-- =====================================================================

-- symbol = nome do arquivo do emblema em assets/factions/<symbol>.svg
insert into public.factions (id, name, symbol, color, description, motto, specialty) values
  (1, 'Bastião',   'bastiao',   '#3A9A5B',
      'Construtores e guardiões. Levantam muros, reforçam portas e transformam qualquer prédio vazio em refúgio para o grupo.',
      'Onde a gente finca o pé, a horda não passa.', 'Abrigos'),
  (2, 'Sentinela', 'sentinela', '#168AA0',
      'Olheiros e operadores de rádio. Passam a noite nos telhados, avistam a horda de longe e avisam toda a rede antes que ela chegue.',
      'Quem vê primeiro vive mais.', 'Alertas de horda'),
  (3, 'Sucata',    'sucata',    '#D2602A',
      'Saqueadores e mecânicos. Entram em mercados, hospitais e postos abandonados e voltam com tudo o que conseguem carregar.',
      'Tudo o que sobrou ainda serve.', 'Expedições'),
  (4, 'Caravana',  'caravana',  '#B83A78',
      'Negociadores e mensageiros. Circulam entre os abrigos levando água, remédio e combustível de quem tem sobrando para quem precisa.',
      'Ninguém atravessa o fim do mundo sozinho.', 'Trocas')
on conflict (id) do update
  set name = excluded.name, symbol = excluded.symbol, color = excluded.color,
      description = excluded.description, motto = excluded.motto, specialty = excluded.specialty;

insert into public.items (id, name, category, icon) values
  (1,  'Garrafa de água',       'agua',         '💧'),
  (2,  'Galão de água',         'agua',         '🚰'),
  (3,  'Comida enlatada',       'comida',       '🥫'),
  (4,  'Ração militar',         'comida',       '🍱'),
  (5,  'Kit de primeiros socorros', 'medicamentos', '🩹'),
  (6,  'Antibiótico',           'medicamentos', '💊'),
  (7,  'Lanterna',              'ferramentas',  '🔦'),
  (8,  'Pé de cabra',           'ferramentas',  '🔨'),
  (9,  'Gasolina',              'combustivel',  '⛽'),
  (10, 'Diesel',                'combustivel',  '🛢️')
on conflict (id) do update
  set name = excluded.name, category = excluded.category, icon = excluded.icon;

insert into public.expedition_types (id, name, description, icon, duration_seconds, risk, failure_chance) values
  (1, 'Mercado abandonado', 'Prateleiras saqueadas, mas ainda sobra comida e água.', '🛒', 60,  'baixo', 0.00),
  (2, 'Posto de gasolina',  'Combustível e ferramentas, com alguns errantes por perto.', '⛽', 120, 'medio', 0.10),
  (3, 'Hospital',           'Remédios valiosos, mas os corredores estão infestados.', '🏥', 180, 'alto',  0.25),
  (4, 'Loja de ferragens',  'Ferramentas resistentes para fortificar abrigos.',      '🧰', 300, 'medio', 0.10)
on conflict (id) do update
  set name = excluded.name, description = excluded.description, icon = excluded.icon,
      duration_seconds = excluded.duration_seconds, risk = excluded.risk,
      failure_chance = excluded.failure_chance;

delete from public.expedition_rewards;
insert into public.expedition_rewards (expedition_type_id, item_id, min_qty, max_qty, chance) values
  (1, 3, 1, 3, 0.90), (1, 1, 1, 3, 0.80), (1, 4, 1, 1, 0.30),
  (2, 9, 1, 3, 0.90), (2, 10, 1, 2, 0.50), (2, 7, 1, 1, 0.30), (2, 1, 1, 2, 0.40),
  (3, 5, 1, 2, 0.90), (3, 6, 1, 2, 0.60), (3, 2, 1, 1, 0.30),
  (4, 8, 1, 1, 0.70), (4, 7, 1, 2, 0.70), (4, 9, 1, 1, 0.30);
