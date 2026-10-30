# =====================================================================
# Game Analytics - Delivery 1 : analisis estadistico de KPIs en R
# Requisitos: DBI + (RMariaDB o RMySQL) + ggplot2
# Uso: ejecutar desde la carpeta r/ (lee ../sql/02_kpi_queries.sql)
#      Rscript analysis.R   (variables GA_HOST, GA_USER, GA_PASS, GA_DB)
# =====================================================================
suppressPackageStartupMessages({ library(DBI); library(ggplot2) })

# ---------------------------- CONFIG ---------------------------------
cfg <- list(host = Sys.getenv("GA_HOST", "localhost"),
            user = Sys.getenv("GA_USER", "CAMBIAR_USUARIO"),
            pass = Sys.getenv("GA_PASS", "CAMBIAR_PASSWORD"),
            db   = Sys.getenv("GA_DB",   "CAMBIAR_BASE_DE_DATOS"),
            port = as.integer(Sys.getenv("GA_PORT", "3306")))
out_dir <- Sys.getenv("GA_OUT", "output")
conf    <- 0.95
dir.create(out_dir, showWarnings = FALSE)
set.seed(42)

# ---------------------------- CONEXION -------------------------------
drv <- if (requireNamespace("RMariaDB", quietly = TRUE)) RMariaDB::MariaDB() else RMySQL::MySQL()
con <- dbConnect(drv, host = cfg$host, user = cfg$user, password = cfg$pass,
                 dbname = cfg$db, port = cfg$port)
q <- function(sql) dbGetQuery(con, sql)

# Las consultas viven en sql/02_kpi_queries.sql (una sola fuente de verdad).
# Cada bloque empieza con "-- name: <id>".
read_queries <- function(path) {
  lines <- readLines(path, warn = FALSE)
  idx   <- grep("^-- name:", lines)
  ends  <- c(idx[-1] - 1, length(lines))
  qs <- lapply(seq_along(idx), function(i)
    sub(";\\s*$", "", trimws(paste(lines[(idx[i] + 1):ends[i]], collapse = "\n"))))
  setNames(qs, trimws(sub("^-- name:", "", lines[idx])))
}
sql_path <- Sys.getenv("GA_SQL", "../sql/02_kpi_queries.sql")
Q <- read_queries(sql_path)
# RMariaDB devuelve los recuentos como integer64, que rompe lm(), t.test(), etc.
# Se convierten a numeric normal nada mas leerlos.
run <- function(id) {
  d <- q(Q[[id]])
  d[] <- lapply(d, function(x) if (inherits(x, "integer64")) as.numeric(x) else x)
  d
}

dau   <- run("dau");        dau$day <- as.Date(dau$day)
mau   <- run("mau_daily");   mau$day <- as.Date(mau$day)
stick <- run("stickiness_daily"); stick$day <- as.Date(stick$day)
ret   <- run("retention_player")
prev  <- run("player_revenue")
sess  <- run("session_detail")
arpu_d <- run("arpu_daily"); arpu_d$day <- as.Date(arpu_d$day)
n_sess_player <- run("sessions_per_player")

theme_set(theme_minimal(base_size = 12))
save_plot <- function(p, name) ggsave(file.path(out_dir, name), p, width = 8, height = 4.5, dpi = 150)

# ---------------------------- utilidades -----------------------------
# IC de una proporcion (Wilson, via prop.test sin correccion de continuidad)
prop_ci <- function(x, n) {
  if (n == 0) return(c(est = NA, lo = NA, hi = NA))
  t <- prop.test(x, n, conf.level = conf, correct = FALSE)
  c(est = unname(t$estimate), lo = t$conf.int[1], hi = t$conf.int[2])
}
# IC de una media (t de Student)
mean_ci <- function(x) {
  x <- x[!is.na(x)]
  t <- t.test(x, conf.level = conf)
  c(est = mean(x), lo = t$conf.int[1], hi = t$conf.int[2])
}
# IC bootstrap percentil (robusto para ingresos, muy asimetricos)
boot_ci <- function(x, f = mean, B = 5000) {
  x <- x[!is.na(x)]
  b <- replicate(B, f(sample(x, replace = TRUE)))
  c(est = f(x), lo = unname(quantile(b, (1 - conf) / 2)), hi = unname(quantile(b, 1 - (1 - conf) / 2)))
}

# ---------------------------- 1. DAU / MAU / Stickiness --------------
p_dau <- ggplot(dau, aes(day, dau)) + geom_col(fill = "grey70") +
  geom_smooth(method = "lm", level = conf, colour = "firebrick") +
  labs(title = "DAU con tendencia lineal e IC 95%", x = NULL, y = "Usuarios activos diarios")
save_plot(p_dau, "01_dau.png")

p_mau <- ggplot(mau, aes(day, mau)) + geom_line(colour = "steelblue") +
  labs(title = "MAU diario (jugadores distintos en los ultimos 30 dias)", x = NULL, y = "MAU")
save_plot(p_mau, "02_mau.png")

p_st <- ggplot(stick, aes(day, stickiness)) + geom_line(colour = "grey60") +
  geom_smooth(method = "loess", level = conf, colour = "firebrick") +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Stickiness diaria (DAU / MAU) con tendencia", x = NULL, y = NULL)
save_plot(p_st, "03_stickiness.png")

# Tendencia del DAU: ¿es significativa la pendiente?
dau$t <- as.numeric(dau$day - min(dau$day))
fit_dau <- lm(dau ~ t, data = dau)
cat("\n== Tendencia DAU (lm) ==\n"); print(summary(fit_dau)$coefficients)
cat("IC95% pendiente (usuarios/dia):", confint(fit_dau, "t", level = conf), "\n")

# ---------------------------- 2. Retencion ---------------------------
ret_tab <- do.call(rbind, lapply(c(1, 3, 7), function(d) {
  obs <- ret[[paste0("observed_d", d)]] == 1
  x <- sum(ret[[paste0("ret_d", d)]][obs]); n <- sum(obs)
  data.frame(day = paste0("D", d), n = n, retained = x, t(prop_ci(x, n)))
}))
cat("\n== Retencion (IC Wilson 95%) ==\n"); print(ret_tab, row.names = FALSE)
p_ret <- ggplot(ret_tab, aes(day, est)) + geom_col(fill = "steelblue") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = .2) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Retencion D1 / D3 / D7 con IC 95%", x = NULL, y = "Retencion")
save_plot(p_ret, "04_retention.png")

# Retencion D1 por segmento + test chi-cuadrado/Fisher
seg_ret <- function(var) {
  d <- ret[ret$observed_d1 == 1, ]
  tab <- table(d[[var]], d$ret_d1)
  p <- tryCatch(fisher.test(tab, simulate.p.value = TRUE, B = 1e4)$p.value, error = function(e) NA)
  list(rate = aggregate(ret_d1 ~ d[[var]], d, mean), p = p)
}
cat("\n== D1 por franja de edad (Fisher simulado) ==\n"); r <- seg_ret("age_group"); print(r$rate); cat("p =", r$p, "\n")
cat("\n== D1 por grupo de genero ==\n");                   r <- seg_ret("gender_group"); print(r$rate); cat("p =", r$p, "\n")
cat("\n== D1 por pais ==\n");                              r <- seg_ret("country"); print(r$rate); cat("p =", r$p, "\n")

# ---------------------------- 3. Monetizacion ------------------------
payers <- prev$revenue[prev$revenue > 0]
arpu_ci  <- rbind(t = mean_ci(prev$revenue), bootstrap = boot_ci(prev$revenue))
arppu_ci <- if (length(payers) > 1) rbind(t = mean_ci(payers), bootstrap = boot_ci(payers)) else NA
conv_ci  <- prop_ci(length(payers), nrow(prev))
cat("\n== ARPU (por jugador) ==\n");        print(arpu_ci)
cat("\n== ARPPU (solo pagadores) ==\n");    print(arppu_ci)
cat("\n== Conversion a pagador ==\n");      print(conv_ci)

mon <- data.frame(kpi = c("ARPU", "ARPPU", "Conversion"),
                  rbind(arpu_ci["bootstrap", ], if (is.matrix(arppu_ci)) arppu_ci["bootstrap", ] else c(est=NA,lo=NA,hi=NA), conv_ci))
p_mon <- ggplot(mon[1:2, ], aes(kpi, est)) + geom_col(fill = "darkgreen") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = .2) +
  labs(title = "ARPU y ARPPU con IC 95% (bootstrap)", x = NULL, y = "EUR")
save_plot(p_mon, "05_arpu_arppu.png")

# Ingresos mensuales y prediccion de los 2 meses siguientes
arpu_d$month <- as.Date(format(arpu_d$day, "%Y-%m-01"))
rev_m <- aggregate(revenue ~ month, arpu_d, sum)
rev_m$k <- seq_len(nrow(rev_m))
fit_rev <- lm(revenue ~ k, data = rev_m)
newk <- data.frame(k = nrow(rev_m) + 1:2)
pred <- predict(fit_rev, newk, interval = "prediction", level = conf)
cat("\n== Prediccion de ingresos de los 2 meses siguientes (IC de prediccion 95%) ==\n")
print(cbind(newk, pred))
cat("Pendiente mensual:", coef(fit_rev)[2], " IC95%:", confint(fit_rev, "k", level = conf), "\n")
fc <- data.frame(month = seq(max(rev_m$month), by = "month", length.out = 3)[-1], revenue = pred[, 1], lo = pred[, 2], hi = pred[, 3])
p_rev <- ggplot(rev_m, aes(month, revenue)) + geom_col(fill = "grey70") +
  geom_pointrange(data = fc, aes(ymin = lo, ymax = hi), colour = "firebrick") +
  geom_smooth(method = "lm", se = TRUE, colour = "firebrick", linewidth = .6) +
  labs(title = "Ingresos mensuales y prediccion (IC 95%)", x = NULL, y = "EUR")
save_plot(p_rev, "06_revenue_forecast.png")

# ---------------------------- 4. Sesiones ----------------------------
cat("\n== Duracion de sesion (s) ==\n");     print(mean_ci(sess$length_sec))
cat("\n== Sesiones por jugador ==\n");       print(mean_ci(n_sess_player$n))
p_len <- ggplot(sess, aes(length_sec / 60)) + geom_histogram(bins = 30, fill = "steelblue") +
  labs(title = "Distribucion de la duracion de sesion", x = "minutos", y = "sesiones")
save_plot(p_len, "07_session_length.png")

# ---------------------------- 5. Demografia --------------------------
cat("\n== ARPU por franja de edad (Kruskal-Wallis) ==\n")
print(aggregate(revenue ~ age_group, prev, mean)); print(kruskal.test(revenue ~ age_group, prev))
cat("\n== ARPU por grupo de genero (Wilcoxon) ==\n")
print(aggregate(revenue ~ gender_group, prev, mean)); print(wilcox.test(revenue ~ gender_group, prev, exact = FALSE))
cat("\n== ARPU por pais (Kruskal-Wallis) ==\n")
print(aggregate(revenue ~ country, prev, mean)); print(kruskal.test(revenue ~ country, prev))
cat("\n== Correlacion edad-gasto (Spearman) ==\n")
print(cor.test(prev$age, prev$revenue, method = "spearman", exact = FALSE))
cat("\n== Conversion a pagador por franja de edad (chi-cuadrado) ==\n")
print(suppressWarnings(chisq.test(table(prev$age_group, prev$revenue > 0))))

p_demo <- ggplot(prev, aes(age_group, revenue)) + stat_summary(fun.data = mean_cl_boot, geom = "pointrange", colour = "darkgreen") +
  labs(title = "Gasto medio por jugador segun edad (IC 95% bootstrap)", x = "Franja de edad", y = "EUR")
save_plot(p_demo, "08_arpu_by_age.png")

# ---------------------------- Resumen --------------------------------
summary_tab <- rbind(
  data.frame(kpi = "D1", t(prop_ci(sum(ret$ret_d1[ret$observed_d1 == 1]), sum(ret$observed_d1 == 1)))),
  data.frame(kpi = "D3", t(prop_ci(sum(ret$ret_d3[ret$observed_d3 == 1]), sum(ret$observed_d3 == 1)))),
  data.frame(kpi = "D7", t(prop_ci(sum(ret$ret_d7[ret$observed_d7 == 1]), sum(ret$observed_d7 == 1)))),
  data.frame(kpi = "ARPU", t(arpu_ci["bootstrap", ])),
  data.frame(kpi = "Conversion", t(conv_ci)),
  data.frame(kpi = "Sesion (s)", t(mean_ci(sess$length_sec)))
)
write.csv(summary_tab, file.path(out_dir, "kpi_summary.csv"), row.names = FALSE)
dbDisconnect(con)   # se cierra al final (on.exit no funciona dentro de source())
cat("\nListo. Graficos y kpi_summary.csv en:", normalizePath(out_dir), "\n")
