# =====================================================================
# Exporta a CSV los datos de cada KPI (para montar el Excel con graficos)
# Uso: igual que analysis.R (desde la carpeta r/, con Sys.setenv(GA_...))
# =====================================================================
library(DBI)
cfg <- list(host = Sys.getenv("GA_HOST", "localhost"), user = Sys.getenv("GA_USER"),
            pass = Sys.getenv("GA_PASS"), db = Sys.getenv("GA_DB"),
            port = as.integer(Sys.getenv("GA_PORT", "3306")))
out_dir <- Sys.getenv("GA_OUT", "output")
dir.create(out_dir, showWarnings = FALSE)
drv <- if (requireNamespace("RMariaDB", quietly = TRUE)) RMariaDB::MariaDB() else RMySQL::MySQL()
con <- dbConnect(drv, host = cfg$host, user = cfg$user, password = cfg$pass, dbname = cfg$db, port = cfg$port)

lines <- readLines(Sys.getenv("GA_SQL", "../sql/02_kpi_queries.sql"), warn = FALSE)
idx  <- grep("^-- name:", lines); ends <- c(idx[-1] - 1, length(lines))
Q <- setNames(lapply(seq_along(idx), function(i)
  sub(";\\s*$", "", trimws(paste(lines[(idx[i] + 1):ends[i]], collapse = "\n")))),
  trimws(sub("^-- name:", "", lines[idx])))
run <- function(id) {
  d <- dbGetQuery(con, Q[[id]])
  d[] <- lapply(d, function(x) if (inherits(x, "integer64")) as.numeric(x) else x)
  d
}
save <- function(d, name) write.csv(d, file.path(out_dir, paste0("tabla_", name, ".csv")), row.names = FALSE)

dau <- run("dau"); mau <- run("mau_daily"); st <- run("stickiness_daily")
ret <- run("retention_player"); prev <- run("player_revenue")
sess <- run("session_detail"); arpu_d <- run("arpu_daily"); nsp <- run("sessions_per_player")

save(dau, "dau"); save(mau, "mau"); save(st, "stickiness")

conf <- 0.95
pci <- function(x, n) { t <- prop.test(x, n, conf.level = conf, correct = FALSE); c(t$estimate, t$conf.int[1], t$conf.int[2]) }
rt <- do.call(rbind, lapply(c(1, 3, 7), function(d) {
  obs <- ret[[paste0("observed_d", d)]] == 1
  data.frame(kpi = paste0("D", d), t(setNames(pci(sum(ret[[paste0("ret_d", d)]][obs]), sum(obs)), c("est", "lo", "hi"))))
}))
save(rt, "retencion")

set.seed(42)
boot <- function(x, B = 5000) { b <- replicate(B, mean(sample(x, replace = TRUE))); c(mean(x), quantile(b, .025), quantile(b, .975)) }
payers <- prev$revenue[prev$revenue > 0]
mon <- rbind(data.frame(kpi = "ARPU", t(setNames(boot(prev$revenue), c("est", "lo", "hi")))),
             data.frame(kpi = "ARPPU", t(setNames(boot(payers), c("est", "lo", "hi")))))
save(mon, "monetizacion")
conv <- pci(length(payers), nrow(prev)); names(conv) <- c("est", "lo", "hi")
save(data.frame(kpi = "Conversion", t(conv)), "conversion")

arpu_d$month <- as.Date(format(as.Date(arpu_d$day), "%Y-%m-01"))
rev_m <- aggregate(revenue ~ month, arpu_d, sum); rev_m$k <- seq_len(nrow(rev_m))
fit <- lm(revenue ~ k, rev_m)
pr <- predict(fit, data.frame(k = nrow(rev_m) + 1:2), interval = "prediction", level = conf)
rev_m$tipo <- "real"; rev_m$fit <- NA; rev_m$lwr <- NA; rev_m$upr <- NA
fc <- data.frame(month = seq(max(rev_m$month), by = "month", length.out = 3)[-1], revenue = NA,
                 k = nrow(rev_m) + 1:2, tipo = "prediccion", fit = pr[, 1], lwr = pr[, 2], upr = pr[, 3])
save(rbind(rev_m, fc), "ingresos_mensuales")

mt <- function(x) { t <- t.test(x[!is.na(x)]); c(mean(x, na.rm = TRUE), t$conf.int) }
ses <- rbind(data.frame(kpi = "Duracion sesion (s)", t(setNames(mt(sess$length_sec), c("est", "lo", "hi")))),
             data.frame(kpi = "Sesiones por jugador", t(setNames(mt(nsp$n), c("est", "lo", "hi")))))
save(ses, "sesiones")
h <- hist(sess$length_sec / 60, breaks = 30, plot = FALSE)
save(data.frame(minutos_desde = head(h$breaks, -1), minutos_hasta = h$breaks[-1], sesiones = h$counts), "duracion_hist")

save(aggregate(revenue ~ age_group, prev, mean), "arpu_edad")
save(aggregate(revenue ~ gender_group, prev, mean), "arpu_genero")
save(aggregate(revenue ~ country, prev, mean), "arpu_pais")
d1 <- ret[ret$observed_d1 == 1, ]
save(aggregate(ret_d1 ~ age_group, d1, mean), "d1_edad")
save(aggregate(ret_d1 ~ gender_group, d1, mean), "d1_genero")

dbDisconnect(con)
cat("Listo. Tablas en:", normalizePath(out_dir), "\n")
