-- =====================================================================
-- Game Analytics - Delivery 1 : consultas SQL de KPIs
-- No requiere permisos de CREATE VIEW: cada consulta es independiente.
-- Cada bloque empieza con "-- name: <id>"; R lee este fichero y ejecuta
-- las consultas por su id (una sola fuente de verdad). En Workbench se
-- puede ejecutar una consulta seleccionandola y pulsando el rayo.
-- Dimension demografica (CTE "demo") repetida donde se necesita.
-- Convencion: un evento pertenece al dia en que EMPIEZA su sesion.
-- =====================================================================

-- name: dau
SELECT DATE(start_date) AS day,
       COUNT(DISTINCT player_id) AS dau
FROM sessions
GROUP BY DATE(start_date)
ORDER BY day;

-- name: mau
SELECT DATE_FORMAT(start_date, '%Y-%m') AS month,
       COUNT(DISTINCT player_id) AS mau
FROM sessions
GROUP BY DATE_FORMAT(start_date, '%Y-%m')
ORDER BY month;

-- name: stickiness
-- Stickiness = DAU medio del mes / MAU del mes
WITH d AS (
    SELECT DATE(start_date) AS day, COUNT(DISTINCT player_id) AS dau
    FROM sessions GROUP BY DATE(start_date)
), m AS (
    SELECT DATE_FORMAT(start_date, '%Y-%m') AS month, COUNT(DISTINCT player_id) AS mau
    FROM sessions GROUP BY DATE_FORMAT(start_date, '%Y-%m')
)
SELECT m.month,
       m.mau,
       SUM(d.dau) / DAY(LAST_DAY(CONCAT(m.month, '-01')))              AS avg_dau,
       SUM(d.dau) / DAY(LAST_DAY(CONCAT(m.month, '-01'))) / m.mau      AS stickiness
FROM m
JOIN d ON DATE_FORMAT(d.day, '%Y-%m') = m.month
GROUP BY m.month, m.mau
ORDER BY m.month;

-- name: retention_player
-- Una fila por jugador: ¿volvio exactamente el dia N despues de unirse?
-- observed_dN = 1 solo si el dia join+N cae dentro del periodo con datos.
WITH demo AS (
    SELECT p.player_id, DATE(p.join_date) AS join_day, c.name AS country,
           CASE WHEN p.age < 18 THEN '12-17' WHEN p.age < 25 THEN '18-24'
                WHEN p.age < 35 THEN '25-34' WHEN p.age < 50 THEN '35-49'
                WHEN p.age < 65 THEN '50-64' ELSE '65+' END AS age_group,
           CASE WHEN p.gender < 0.5 THEN 'G0' ELSE 'G1' END AS gender_group
    FROM players p JOIN countries c ON c.country_id = p.country_id
), lim AS (
    SELECT DATE(MAX(start_date)) AS last_day FROM sessions
)
SELECT d.player_id, d.join_day, d.country, d.age_group, d.gender_group,
       (d.join_day + INTERVAL 1 DAY <= lim.last_day) AS observed_d1,
       (d.join_day + INTERVAL 3 DAY <= lim.last_day) AS observed_d3,
       (d.join_day + INTERVAL 7 DAY <= lim.last_day) AS observed_d7,
       EXISTS (SELECT 1 FROM sessions s WHERE s.player_id = d.player_id
               AND s.start_date >= d.join_day + INTERVAL 1 DAY
               AND s.start_date <  d.join_day + INTERVAL 2 DAY) AS ret_d1,
       EXISTS (SELECT 1 FROM sessions s WHERE s.player_id = d.player_id
               AND s.start_date >= d.join_day + INTERVAL 3 DAY
               AND s.start_date <  d.join_day + INTERVAL 4 DAY) AS ret_d3,
       EXISTS (SELECT 1 FROM sessions s WHERE s.player_id = d.player_id
               AND s.start_date >= d.join_day + INTERVAL 7 DAY
               AND s.start_date <  d.join_day + INTERVAL 8 DAY) AS ret_d7
FROM demo d
CROSS JOIN lim;

-- name: retention_global
-- Retencion D1, D3 y D7 globales (solo jugadores con el dia N observable)
WITH lim AS (
    SELECT DATE(MAX(start_date)) AS last_day FROM sessions
), r AS (
    SELECT p.player_id, DATE(p.join_date) AS jd,
           EXISTS (SELECT 1 FROM sessions s WHERE s.player_id = p.player_id
                   AND s.start_date >= DATE(p.join_date) + INTERVAL 1 DAY
                   AND s.start_date <  DATE(p.join_date) + INTERVAL 2 DAY) AS r1,
           EXISTS (SELECT 1 FROM sessions s WHERE s.player_id = p.player_id
                   AND s.start_date >= DATE(p.join_date) + INTERVAL 3 DAY
                   AND s.start_date <  DATE(p.join_date) + INTERVAL 4 DAY) AS r3,
           EXISTS (SELECT 1 FROM sessions s WHERE s.player_id = p.player_id
                   AND s.start_date >= DATE(p.join_date) + INTERVAL 7 DAY
                   AND s.start_date <  DATE(p.join_date) + INTERVAL 8 DAY) AS r7
    FROM players p
)
SELECT SUM(CASE WHEN r.jd + INTERVAL 1 DAY <= lim.last_day THEN r.r1 END)
       / SUM(r.jd + INTERVAL 1 DAY <= lim.last_day) AS d1,
       SUM(CASE WHEN r.jd + INTERVAL 3 DAY <= lim.last_day THEN r.r3 END)
       / SUM(r.jd + INTERVAL 3 DAY <= lim.last_day) AS d3,
       SUM(CASE WHEN r.jd + INTERVAL 7 DAY <= lim.last_day THEN r.r7 END)
       / SUM(r.jd + INTERVAL 7 DAY <= lim.last_day) AS d7
FROM r CROSS JOIN lim;

-- name: arpu_daily
-- ARPU = ingresos / usuarios activos ; ARPPU = ingresos / usuarios que pagan
WITH d AS (
    SELECT DATE(start_date) AS day, COUNT(DISTINCT player_id) AS dau
    FROM sessions GROUP BY DATE(start_date)
), r AS (
    SELECT DATE(s.start_date) AS day,
           SUM(i.price) AS revenue,
           COUNT(DISTINCT s.player_id) AS paying_users
    FROM purchases pu
    JOIN items i    ON i.item_id    = pu.item_id
    JOIN sessions s ON s.session_id = pu.session_id
    GROUP BY DATE(s.start_date)
)
SELECT d.day, d.dau,
       COALESCE(r.revenue, 0)                  AS revenue,
       COALESCE(r.paying_users, 0)             AS paying_users,
       COALESCE(r.revenue, 0) / d.dau          AS arpu,
       r.revenue / NULLIF(r.paying_users, 0)   AS arppu
FROM d
LEFT JOIN r ON r.day = d.day
ORDER BY d.day;

-- name: player_revenue
-- Una fila por jugador con su gasto total (para ARPU/ARPPU y tests por segmento)
WITH demo AS (
    SELECT p.player_id, c.name AS country, p.age,
           CASE WHEN p.age < 18 THEN '12-17' WHEN p.age < 25 THEN '18-24'
                WHEN p.age < 35 THEN '25-34' WHEN p.age < 50 THEN '35-49'
                WHEN p.age < 65 THEN '50-64' ELSE '65+' END AS age_group,
           CASE WHEN p.gender < 0.5 THEN 'G0' ELSE 'G1' END AS gender_group
    FROM players p JOIN countries c ON c.country_id = p.country_id
)
SELECT d.player_id, d.country, d.age, d.age_group, d.gender_group,
       COALESCE(SUM(i.price), 0) AS revenue,
       COUNT(pu.purchase_id)     AS n_purchases
FROM demo d
LEFT JOIN sessions s   ON s.player_id   = d.player_id
LEFT JOIN purchases pu ON pu.session_id = s.session_id
LEFT JOIN items i      ON i.item_id     = pu.item_id
GROUP BY d.player_id, d.country, d.age, d.age_group, d.gender_group;

-- name: arpu_global
SELECT SUM(revenue) / COUNT(*)                    AS arpu,
       SUM(revenue) / NULLIF(SUM(revenue > 0), 0) AS arppu,
       AVG(revenue > 0)                           AS conversion
FROM (
    SELECT p.player_id, COALESCE(SUM(i.price), 0) AS revenue
    FROM players p
    LEFT JOIN sessions s   ON s.player_id   = p.player_id
    LEFT JOIN purchases pu ON pu.session_id = s.session_id
    LEFT JOIN items i      ON i.item_id     = pu.item_id
    GROUP BY p.player_id
) t;

-- name: session_detail
-- Sesiones cerradas con su duracion en segundos
WITH demo AS (
    SELECT p.player_id, c.name AS country,
           CASE WHEN p.age < 18 THEN '12-17' WHEN p.age < 25 THEN '18-24'
                WHEN p.age < 35 THEN '25-34' WHEN p.age < 50 THEN '35-49'
                WHEN p.age < 65 THEN '50-64' ELSE '65+' END AS age_group,
           CASE WHEN p.gender < 0.5 THEN 'G0' ELSE 'G1' END AS gender_group
    FROM players p JOIN countries c ON c.country_id = p.country_id
)
SELECT s.session_id, s.player_id, s.start_date, s.end_date,
       TIMESTAMPDIFF(SECOND, s.start_date, s.end_date) AS length_sec,
       d.country, d.age_group, d.gender_group
FROM sessions s
JOIN demo d ON d.player_id = s.player_id
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

-- name: demographics_country
SELECT c.name AS country, COUNT(DISTINCT p.player_id) AS players,
       COUNT(s.session_id) AS sessions
FROM players p
JOIN countries c ON c.country_id = p.country_id
LEFT JOIN sessions s ON s.player_id = p.player_id
GROUP BY c.name
ORDER BY players DESC;
