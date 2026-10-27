-- =====================================================================
-- Game Analytics - Delivery 1 : esquema de la base de datos
-- Normalizado (3NF): jugadores, sesiones y compras son entidades
-- distintas; paises e items son tablas de catalogo.
-- =====================================================================
CREATE TABLE IF NOT EXISTS countries (
    country_id  SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(64)       NOT NULL,
    PRIMARY KEY (country_id),
    UNIQUE KEY uq_country_name (name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS items (
    item_id  SMALLINT UNSIGNED NOT NULL,
    price    DECIMAL(8,2)      NOT NULL,
    PRIMARY KEY (item_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS players (
    player_id   INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    name        VARCHAR(64)       NOT NULL,
    country_id  SMALLINT UNSIGNED NOT NULL,
    age         TINYINT UNSIGNED  NOT NULL,
    gender      FLOAT             NOT NULL,          -- valor 0..1 que envia el simulador
    join_date   DATETIME          NOT NULL,
    PRIMARY KEY (player_id),
    KEY idx_players_join_date (join_date),
    KEY idx_players_country   (country_id),
    CONSTRAINT fk_players_country FOREIGN KEY (country_id) REFERENCES countries (country_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sessions (
    session_id  INT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id   INT UNSIGNED NOT NULL,
    start_date  DATETIME     NOT NULL,
    end_date    DATETIME     NULL,                   -- NULL mientras la sesion sigue abierta
    PRIMARY KEY (session_id),
    KEY idx_sessions_start  (start_date),
    KEY idx_sessions_player (player_id, start_date),
    CONSTRAINT fk_sessions_player FOREIGN KEY (player_id) REFERENCES players (player_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS purchases (
    purchase_id    INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    session_id     INT UNSIGNED      NOT NULL,
    item_id        SMALLINT UNSIGNED NOT NULL,
    purchase_date  DATETIME          NOT NULL,
    PRIMARY KEY (purchase_id),
    KEY idx_purchases_date    (purchase_date),
    KEY idx_purchases_session (session_id),
    CONSTRAINT fk_purchases_session FOREIGN KEY (session_id) REFERENCES sessions (session_id),
    CONSTRAINT fk_purchases_item    FOREIGN KEY (item_id)    REFERENCES items (item_id)
) ENGINE=InnoDB;

-- Catalogo de items (Items.xlsx)
INSERT INTO items (item_id, price) VALUES
    (1, 0.99), (2, 1.99), (3, 9.99), (4, 49.99), (5, 99.99)
ON DUPLICATE KEY UPDATE price = VALUES(price);
