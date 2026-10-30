-- =====================================================================
-- Game Analytics - Delivery 1 : consultas SQL de los KPIs
-- Cada consulta es independiente (no se necesitan vistas).
-- Cada bloque empieza con "-- name: <id>"; R lee este fichero y ejecuta
-- las consultas por su id. En Workbench se puede ejecutar una consulta
-- seleccionandola y pulsando el rayo.
-- Convencion: un evento pertenece al dia en que EMPIEZA su sesion.
-- =====================================================================

-- name: dau
-- Usuarios activos por dia
SELECT DATE(start_date) AS day,
       COUNT(DISTINCT player_id) AS dau
FROM sessions
GROUP BY DATE(start_date)
ORDER BY day;

-- name: mau_daily
-- MAU para cada dia: jugadores distintos en los ultimos 30 dias (incluido el dia).
-- Primero se reduce a parejas (jugador, dia) para que el calculo sea rapido.
SELECT d.day,
       (SELECT COUNT(DISTINCT pd.player_id)
        FROM (SELECT DISTINCT player_id, DATE(start_date) AS day FROM sessions) pd
        WHERE pd.day BETWEEN d.day - INTERVAL 29 DAY AND d.day) AS mau
FROM (SELECT DISTINCT DATE(start_date) AS day FROM sessions) d
ORDER BY d.day;

-- name: stickiness_daily
-- Stickiness para cada dia = DAU / MAU
SELECT d.day, d.dau, m.mau, d.dau / m.mau AS stickiness
FROM (SELECT DATE(start_date) AS day, COUNT(DISTINCT player_id) AS dau
      FROM sessions
      GROUP BY DATE(start_date)) d
JOIN (SELECT d2.day,
             (SELECT COUNT(DISTINCT pd.player_id)
              FROM (SELECT DISTINCT player_id, DATE(start_date) AS day FROM sessions) pd
              WHERE pd.day BETWEEN d2.day - INTERVAL 29 DAY AND d2.day) AS mau
      FROM (SELECT DISTINCT DATE(start_date) AS day FROM sessions) d2) m
  ON m.day = d.day
ORDER BY d.day;

-- name: retention_player
-- Una fila por jugador. ret_dN = 1 si el jugador vuelve exactamente N dias
-- despues del dia en que se unio: DATE(sesion - interval N day) = DATE(join_date).
-- observed_dN = 1 solo si el dia join+N cae dentro del periodo con datos.
SELECT p.player_id,
       DATE(p.join_date) AS join_day,
       c.name AS country,
       CASE WHEN p.age < 18 THEN '12-17'
            WHEN p.age < 25 THEN '18-24'
            WHEN p.age < 35 THEN '25-34'
            WHEN p.age < 50 THEN '35-49'
            WHEN p.age < 65 THEN '50-64'
            ELSE '65+' END AS age_group,
       CASE WHEN p.gender < 0.5 THEN 'G0' ELSE 'G1' END AS gender_group,
       DATE(p.join_date) + INTERVAL 1 DAY <= lim.last_day AS observed_d1,
       DATE(p.join_date) + INTERVAL 3 DAY <= lim.last_day AS observed_d3,
       DATE(p.join_date) + INTERVAL 7 DAY <= lim.last_day AS observed_d7,
       COALESCE(MAX(DATE(s.start_date - INTERVAL 1 DAY) = DATE(p.join_date)), 0) AS ret_d1,
       COALESCE(MAX(DATE(s.start_date - INTERVAL 3 DAY) = DATE(p.join_date)), 0) AS ret_d3,
       COALESCE(MAX(DATE(s.start_date - INTERVAL 7 DAY) = DATE(p.join_date)), 0) AS ret_d7
FROM players p
JOIN countries c ON c.country_id = p.country_id
LEFT JOIN sessions s ON s.player_id = p.player_id
CROSS JOIN (SELECT DATE(MAX(start_date)) AS last_day FROM sessions) lim
GROUP BY p.player_id, p.join_date, c.name, p.age, p.gender, lim.last_day;

-- name: retention_global
-- Retencion D1, D3 y D7 (solo jugadores con el dia N observable)
SELECT SUM(CASE WHEN observed_d1 = 1 THEN ret_d1 END) / SUM(observed_d1) AS d1,
       SUM(CASE WHEN observed_d3 = 1 THEN ret_d3 END) / SUM(observed_d3) AS d3,
       SUM(CASE WHEN observed_d7 = 1 THEN ret_d7 END) / SUM(observed_d7) AS d7
FROM (SELECT DATE(p.join_date) + INTERVAL 1 DAY <= lim.last_day AS observed_d1,
             DATE(p.join_date) + INTERVAL 3 DAY <= lim.last_day AS observed_d3,
             DATE(p.join_date) + INTERVAL 7 DAY <= lim.last_day AS observed_d7,
             COALESCE(MAX(DATE(s.start_date - INTERVAL 1 DAY) = DATE(p.join_date)), 0) AS ret_d1,
             COALESCE(MAX(DATE(s.start_date - INTERVAL 3 DAY) = DATE(p.join_date)), 0) AS ret_d3,
             COALESCE(MAX(DATE(s.start_date - INTERVAL 7 DAY) = DATE(p.join_date)), 0) AS ret_d7
      FROM players p
      LEFT JOIN sessions s ON s.player_id = p.player_id
      CROSS JOIN (SELECT DATE(MAX(start_date)) AS last_day FROM sessions) lim
      GROUP BY p.player_id, p.join_date, lim.last_day) t;

-- name: arpu_daily
-- ARPU = ingresos / usuarios activos ; ARPPU = ingresos / usuarios que pagan
SELECT d.day, d.dau,
       COALESCE(r.revenue, 0) AS revenue,
       COALESCE(r.paying_users, 0) AS paying_users,
       COALESCE(r.revenue, 0) / d.dau AS arpu,
       r.revenue / NULLIF(r.paying_users, 0) AS arppu
FROM (SELECT DATE(start_date) AS day, COUNT(DISTINCT player_id) AS dau
      FROM sessions
      GROUP BY DATE(start_date)) d
LEFT JOIN (SELECT DATE(s.start_date) AS day,
                  SUM(i.price) AS revenue,
                  COUNT(DISTINCT s.player_id) AS paying_users
           FROM purchases pu
           JOIN items i ON i.item_id = pu.item_id
           JOIN sessions s ON s.session_id = pu.session_id
           GROUP BY DATE(s.start_date)) r
  ON r.day = d.day
ORDER BY d.day;

-- name: player_revenue
-- Una fila por jugador con su gasto total (ARPU/ARPPU y tests por segmento)
SELECT p.player_id,
       c.name AS country,
       p.age,
       CASE WHEN p.age < 18 THEN '12-17'
            WHEN p.age < 25 THEN '18-24'
            WHEN p.age < 35 THEN '25-34'
            WHEN p.age < 50 THEN '35-49'
            WHEN p.age < 65 THEN '50-64'
            ELSE '65+' END AS age_group,
       CASE WHEN p.gender < 0.5 THEN 'G0' ELSE 'G1' END AS gender_group,
       COALESCE(SUM(i.price), 0) AS revenue,
       COUNT(pu.purchase_id) AS n_purchases
FROM players p
JOIN countries c ON c.country_id = p.country_id
LEFT JOIN sessions s ON s.player_id = p.player_id
LEFT JOIN purchases pu ON pu.session_id = s.session_id
LEFT JOIN items i ON i.item_id = pu.item_id
GROUP BY p.player_id, c.name, p.age, p.gender;

-- name: arpu_global
SELECT SUM(revenue) / COUNT(*) AS arpu,
       SUM(revenue) / NULLIF(SUM(revenue > 0), 0) AS arppu,
       AVG(revenue > 0) AS conversion
FROM (SELECT p.player_id, COALESCE(SUM(i.price), 0) AS revenue
      FROM players p
      LEFT JOIN sessions s ON s.player_id = p.player_id
      LEFT JOIN purchases pu ON pu.session_id = s.session_id
      LEFT JOIN items i ON i.item_id = pu.item_id
      GROUP BY p.player_id) t;

-- name: session_detail
-- Sesiones cerradas con su duracion en segundos
SELECT s.session_id, s.player_id, s.start_date, s.end_date,
       TIMESTAMPDIFF(SECOND, s.start_date, s.end_date) AS length_sec,
       c.name AS country,
       CASE WHEN p.age < 18 THEN '12-17'
            WHEN p.age < 25 THEN '18-24'
            WHEN p.age < 35 THEN '25-34'
            WHEN p.age < 50 THEN '35-49'
            WHEN p.age < 65 THEN '50-64'
            ELSE '65+' END AS age_group,
       CASE WHEN p.gender < 0.5 THEN 'G0' ELSE 'G1' END AS gender_group
FROM sessions s
JOIN players p ON p.player_id = s.player_id
JOIN countries c ON c.country_id = p.country_id
WHERE s.end_date IS NOT NULL;

-- name: sessions_per_player
SELECT player_id, COUNT(*) AS n
FROM sessions
GROUP BY player_id;

-- name: sessions_daily
SELECT DATE(start_date) AS day,
       COUNT(*) AS n_sessions,
       AVG(TIMESTAMPDIFF(SECOND, start_date, end_date)) AS avg_length_sec
FROM sessions
WHERE end_date IS NOT NULL
GROUP BY DATE(start_date)
ORDER BY day;

-- name: sessions_country
-- Numero de sesiones y duracion media por pais
SELECT c.name AS country,
       COUNT(DISTINCT p.player_id) AS players,
       COUNT(s.session_id) AS sessions,
       AVG(TIMESTAMPDIFF(SECOND, s.start_date, s.end_date)) AS avg_length_sec
FROM players p
JOIN countries c ON c.country_id = p.country_id
LEFT JOIN sessions s ON s.player_id = p.player_id
GROUP BY c.name
ORDER BY players DESC;
