# Cerneva commercial intelligence pipeline
# ----------------------------------------
# Purpose: turn a fictional B2B CRM export into decision-ready commercial
# evidence. The script deliberately uses base R only so the analysis can be
# reproduced with a clean R installation.

options(stringsAsFactors = FALSE, scipen = 999)

root <- Sys.getenv("CERNEVA_ROOT", unset = ".")
raw_dir <- file.path(root, "data", "raw")
processed_dir <- file.path(root, "data", "processed")
tables_dir <- file.path(root, "outputs", "tables")
figures_dir <- file.path(root, "outputs", "figures")
docs_dir <- file.path(root, "docs")

for (path in c(processed_dir, tables_dir, figures_dir, docs_dir)) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

required_columns <- list(
  accounts = c("account", "sector", "year_established", "revenue", "employees", "office_location", "subsidiary_of"),
  products = c("product", "series", "sales_price"),
  sales_pipeline = c("opportunity_id", "sales_agent", "product", "account", "deal_stage", "engage_date", "close_date", "close_value"),
  sales_teams = c("sales_agent", "manager", "regional_office")
)

read_source <- function(name) {
  path <- file.path(raw_dir, paste0(name, ".csv"))
  if (!file.exists(path)) stop("Missing source file: ", path)
  data <- read.csv(path, na.strings = c("", "NA"), check.names = FALSE)
  missing <- setdiff(required_columns[[name]], names(data))
  if (length(missing) > 0) {
    stop(name, " is missing required columns: ", paste(missing, collapse = ", "))
  }
  data
}

replace_blank <- function(x, replacement = "Unknown") {
  x <- trimws(as.character(x))
  x[is.na(x) | x == ""] <- replacement
  x
}

safe_rate <- function(numerator, denominator) {
  ifelse(denominator == 0, NA_real_, numerator / denominator)
}

rank_auc <- function(actual, score) {
  keep <- !is.na(actual) & !is.na(score)
  actual <- actual[keep]
  score <- score[keep]
  positives <- sum(actual == 1)
  negatives <- sum(actual == 0)
  if (positives == 0 || negatives == 0) return(NA_real_)
  ranks <- rank(score, ties.method = "average")
  (sum(ranks[actual == 1]) - positives * (positives + 1) / 2) /
    (positives * negatives)
}

brier_score <- function(actual, score) mean((actual - score)^2, na.rm = TRUE)

log_loss <- function(actual, score) {
  score <- pmax(pmin(score, 1 - 1e-15), 1e-15)
  -mean(actual * log(score) + (1 - actual) * log(1 - score), na.rm = TRUE)
}

currency <- function(x) {
  if (abs(x) >= 1e6) return(sprintf("$%.2fm", x / 1e6))
  if (abs(x) >= 1e3) return(sprintf("$%.1fk", x / 1e3))
  sprintf("$%.0f", x)
}

write_table <- function(data, filename) {
  write.csv(data, file.path(tables_dir, filename), row.names = FALSE, na = "")
}

# 1. Ingest and standardise -------------------------------------------------
accounts <- read_source("accounts")
products <- read_source("products")
pipeline <- read_source("sales_pipeline")
teams <- read_source("sales_teams")

pipeline$source_row <- seq_len(nrow(pipeline))
pipeline$product <- trimws(pipeline$product)
pipeline$product[pipeline$product == "GTXPro"] <- "GTX Pro"
pipeline$account <- replace_blank(pipeline$account)
pipeline$sales_agent <- replace_blank(pipeline$sales_agent)
pipeline$deal_stage <- replace_blank(pipeline$deal_stage)
pipeline$engage_date <- as.Date(pipeline$engage_date)
pipeline$close_date <- as.Date(pipeline$close_date)

accounts$account <- replace_blank(accounts$account)
accounts$sector <- tolower(replace_blank(accounts$sector))
accounts$sector[accounts$sector == "technolgy"] <- "technology"
accounts$office_location <- replace_blank(accounts$office_location)
accounts$subsidiary_of <- replace_blank(accounts$subsidiary_of, "Independent")

products$product <- trimws(products$product)
teams$sales_agent <- replace_blank(teams$sales_agent)
teams$manager <- replace_blank(teams$manager)
teams$regional_office <- replace_blank(teams$regional_office)

product_match <- match(pipeline$product, products$product)
team_match <- match(pipeline$sales_agent, teams$sales_agent)
account_match <- match(pipeline$account, accounts$account)

deals <- pipeline
deals$series <- products$series[product_match]
deals$sales_price <- products$sales_price[product_match]
deals$manager <- teams$manager[team_match]
deals$regional_office <- teams$regional_office[team_match]
deals$sector <- accounts$sector[account_match]
deals$year_established <- accounts$year_established[account_match]
deals$account_revenue_m <- accounts$revenue[account_match]
deals$employees <- accounts$employees[account_match]
deals$office_location <- accounts$office_location[account_match]
deals$subsidiary_of <- accounts$subsidiary_of[account_match]

for (field in c("series", "manager", "regional_office", "sector", "office_location", "subsidiary_of")) {
  deals[[field]] <- replace_blank(deals[[field]])
}

latest_source_date <- max(c(deals$engage_date, deals$close_date), na.rm = TRUE)
analysis_date <- latest_source_date + 1
deals$company_age <- as.integer(format(analysis_date, "%Y")) - deals$year_established
deals$engage_month <- ifelse(is.na(deals$engage_date), "Unknown", format(deals$engage_date, "%b"))
deals$close_month <- ifelse(is.na(deals$close_date), NA, format(deals$close_date, "%Y-%m"))
deals$sales_cycle_days <- as.integer(deals$close_date - deals$engage_date)
deals$is_closed <- deals$deal_stage %in% c("Won", "Lost")
deals$is_won <- as.integer(deals$deal_stage == "Won")
deals$account_known <- as.integer(deals$account != "Unknown")
deals$account_enriched <- as.integer(!is.na(account_match))
deals$product_matched <- as.integer(!is.na(product_match))
deals$team_matched <- as.integer(!is.na(team_match))
deals$discount_pct <- ifelse(
  deals$is_won == 1 & !is.na(deals$sales_price) & deals$sales_price > 0,
  1 - deals$close_value / deals$sales_price,
  NA_real_
)
deals <- deals[order(deals$source_row), ]

# 2. Executable data-quality controls --------------------------------------
valid_stages <- c("Prospecting", "Engaging", "Won", "Lost")
duplicate_ids <- sum(duplicated(deals$opportunity_id))
invalid_stages <- sum(!deals$deal_stage %in% valid_stages)
invalid_close_order <- sum(
  !is.na(deals$engage_date) & !is.na(deals$close_date) & deals$close_date < deals$engage_date
)
won_without_value <- sum(deals$deal_stage == "Won" & (is.na(deals$close_value) | deals$close_value <= 0))
closed_without_date <- sum(deals$is_closed & is.na(deals$close_date))

quality_checks <- data.frame(
  check = c(
    "Opportunity IDs are unique",
    "Deal stages are recognised",
    "Close dates follow engagement dates",
    "Won deals have positive close value",
    "Closed deals have close dates",
    "Product joins are complete",
    "Sales-team joins are complete"
  ),
  failures = c(
    duplicate_ids,
    invalid_stages,
    invalid_close_order,
    won_without_value,
    closed_without_date,
    sum(deals$product_matched == 0),
    sum(deals$team_matched == 0)
  )
)
quality_checks$status <- ifelse(quality_checks$failures == 0, "PASS", "FAIL")
quality_checks$rule <- c(
  "COUNT(DISTINCT opportunity_id) = row count",
  "stage in Prospecting, Engaging, Won, Lost",
  "close_date >= engage_date",
  "Won implies close_value > 0",
  "Won/Lost implies a close date",
  "Every product resolves after name standardisation",
  "Every sales agent resolves to a manager and region"
)
write_table(quality_checks, "data_quality_checks.csv")

if (any(quality_checks$status == "FAIL")) {
  failed <- quality_checks$check[quality_checks$status == "FAIL"]
  stop("Data-quality controls failed: ", paste(failed, collapse = "; "))
}

# 3. Commercial performance marts -----------------------------------------
closed <- deals[deals$is_closed & !is.na(deals$engage_date), ]
won <- closed[closed$is_won == 1, ]
global_win_rate <- mean(closed$is_won)

summarise_group <- function(data, group_field) {
  groups <- sort(unique(data[[group_field]]))
  rows <- lapply(groups, function(group) {
    part <- data[data[[group_field]] == group, ]
    data.frame(
      group = group,
      closed_deals = nrow(part),
      wins = sum(part$is_won),
      losses = sum(part$is_won == 0),
      win_rate = mean(part$is_won),
      won_revenue = sum(part$close_value[part$is_won == 1], na.rm = TRUE),
      median_cycle_days = median(part$sales_cycle_days, na.rm = TRUE)
    )
  })
  result <- do.call(rbind, rows)
  names(result)[1] <- group_field
  result
}

product_summary <- summarise_group(closed, "product")
product_summary$list_price <- products$sales_price[match(product_summary$product, products$product)]
product_summary <- product_summary[order(-product_summary$won_revenue), ]

region_summary <- summarise_group(closed, "regional_office")
region_summary <- region_summary[order(-region_summary$win_rate), ]

manager_summary <- summarise_group(closed, "manager")
manager_summary <- manager_summary[order(-manager_summary$won_revenue), ]

agent_summary <- summarise_group(closed, "sales_agent")
prior_deals <- 30
agent_summary$adjusted_win_rate <-
  (agent_summary$wins + prior_deals * global_win_rate) /
  (agent_summary$closed_deals + prior_deals)
agent_summary <- agent_summary[order(-agent_summary$adjusted_win_rate, -agent_summary$won_revenue), ]

month_groups <- sort(unique(closed$close_month))
monthly_summary <- do.call(rbind, lapply(month_groups, function(month) {
  part <- closed[closed$close_month == month, ]
  data.frame(
    close_month = month,
    closed_deals = nrow(part),
    wins = sum(part$is_won),
    win_rate = mean(part$is_won),
    won_revenue = sum(part$close_value[part$is_won == 1], na.rm = TRUE),
    median_cycle_days = median(part$sales_cycle_days, na.rm = TRUE)
  )
}))

stage_names <- valid_stages
stage_summary <- do.call(rbind, lapply(stage_names, function(stage) {
  part <- deals[deals$deal_stage == stage, ]
  data.frame(
    deal_stage = stage,
    opportunities = nrow(part),
    estimated_list_value = sum(part$sales_price, na.rm = TRUE),
    realised_revenue = sum(part$close_value, na.rm = TRUE)
  )
}))

account_names <- sort(unique(won$account[won$account != "Unknown"]))
account_summary <- do.call(rbind, lapply(account_names, function(account) {
  part <- closed[closed$account == account, ]
  data.frame(
    account = account,
    sector = part$sector[1],
    closed_deals = nrow(part),
    wins = sum(part$is_won),
    win_rate = mean(part$is_won),
    won_revenue = sum(part$close_value[part$is_won == 1], na.rm = TRUE)
  )
}))
account_summary <- account_summary[order(-account_summary$won_revenue), ]

write_table(product_summary, "product_performance.csv")
write_table(region_summary, "region_performance.csv")
write_table(manager_summary, "manager_performance.csv")
write_table(agent_summary, "agent_performance_adjusted.csv")
write_table(monthly_summary, "monthly_performance.csv")
write_table(stage_summary, "pipeline_stage_summary.csv")
write_table(account_summary, "account_performance.csv")

# 4. Chronological forecast diagnostic -------------------------------------
# Only information available when a deal is engaged is used. Close value,
# close date, outcome-derived discounts and sales cycle are excluded.
closed <- closed[order(closed$engage_date, closed$opportunity_id), ]
cutoff_index <- floor(0.80 * nrow(closed))
cutoff_date <- closed$engage_date[cutoff_index]
train <- closed[closed$engage_date < cutoff_date, ]
test <- closed[closed$engage_date >= cutoff_date, ]

numeric_predictors <- c("sales_price", "account_revenue_m", "employees")
training_medians <- sapply(train[numeric_predictors], median, na.rm = TRUE)
for (field in numeric_predictors) {
  train[[field]][is.na(train[[field]])] <- training_medians[[field]]
  test[[field]][is.na(test[[field]])] <- training_medians[[field]]
}

region_levels <- sort(unique(c(train$regional_office, test$regional_office, "Unknown")))
train$regional_office <- factor(train$regional_office, levels = region_levels)
test$regional_office <- factor(test$regional_office, levels = region_levels)
train$log_sales_price <- log1p(train$sales_price)
train$log_account_revenue <- log1p(train$account_revenue_m)
train$log_employees <- log1p(train$employees)
test$log_sales_price <- log1p(test$sales_price)
test$log_account_revenue <- log1p(test$account_revenue_m)
test$log_employees <- log1p(test$employees)

diagnostic_model <- glm(
  is_won ~ regional_office + log_sales_price + log_account_revenue + log_employees,
  data = train,
  family = binomial()
)
model_probability <- as.numeric(predict(diagnostic_model, newdata = test, type = "response"))
baseline_probability <- rep(mean(train$is_won), nrow(test))

metric_row <- function(name, probability) {
  data.frame(
    model = name,
    roc_auc = rank_auc(test$is_won, probability),
    brier_score = brier_score(test$is_won, probability),
    log_loss = log_loss(test$is_won, probability),
    accuracy_at_0_5 = mean((probability >= 0.5) == test$is_won)
  )
}

model_metrics <- rbind(
  metric_row("Known-at-engagement logistic model", model_probability),
  metric_row("Training win-rate baseline", baseline_probability)
)
model_metrics$train_rows <- nrow(train)
model_metrics$test_rows <- nrow(test)
model_metrics$cutoff_date <- as.character(cutoff_date)

model_is_useful <-
  model_metrics$roc_auc[1] >= 0.60 &&
  model_metrics$brier_score[1] < model_metrics$brier_score[2] - 0.005

model_decision <- if (model_is_useful) {
  "Suitable only for a monitored pilot"
} else {
  "Do not operationalise: collect stage history, activities and buyer signals first"
}
model_metrics$decision <- c(model_decision, "Reference benchmark")
write_table(model_metrics, "forecast_model_metrics.csv")

test$forecast_probability <- model_probability
test$baseline_probability <- baseline_probability
test$absolute_error <- abs(test$is_won - test$forecast_probability)

quantile_breaks <- unique(quantile(model_probability, probs = seq(0, 1, 0.2), na.rm = TRUE))
if (length(quantile_breaks) < 3) {
  test$probability_band <- "All predictions"
} else {
  test$probability_band <- cut(
    model_probability,
    breaks = quantile_breaks,
    include.lowest = TRUE,
    ordered_result = TRUE
  )
}
calibration_groups <- levels(factor(test$probability_band))
calibration <- do.call(rbind, lapply(calibration_groups, function(band) {
  part <- test[as.character(test$probability_band) == band, ]
  data.frame(
    probability_band = band,
    opportunities = nrow(part),
    mean_predicted = mean(part$forecast_probability),
    actual_win_rate = mean(part$is_won)
  )
}))
write_table(calibration, "forecast_calibration.csv")

forecast_holdout <- test[c(
  "opportunity_id", "engage_date", "sales_agent", "manager", "regional_office",
  "product", "account", "sector", "is_won", "forecast_probability",
  "baseline_probability", "absolute_error"
)]
write_table(forecast_holdout, "forecast_holdout_predictions.csv")

coefficient_table <- data.frame(
  term = names(coef(diagnostic_model)),
  coefficient = as.numeric(coef(diagnostic_model)),
  odds_ratio = exp(as.numeric(coef(diagnostic_model)))
)
write_table(coefficient_table, "forecast_coefficients.csv")

# 5. Open-pipeline action queue --------------------------------------------
open_pipeline <- deals[deals$deal_stage %in% c("Prospecting", "Engaging"), ]
open_pipeline$stale_days <- as.integer(analysis_date - open_pipeline$engage_date)
open_pipeline$record_completeness <- round(100 * rowMeans(cbind(
  open_pipeline$account_known,
  as.integer(!is.na(open_pipeline$engage_date)),
  open_pipeline$account_enriched,
  open_pipeline$product_matched,
  open_pipeline$team_matched
)))

value_percentile <- rank(open_pipeline$sales_price, ties.method = "average", na.last = "keep") /
  sum(!is.na(open_pipeline$sales_price))
stale_component <- ifelse(
  is.na(open_pipeline$stale_days),
  35,
  pmin(open_pipeline$stale_days / 90, 1) * 35
)
open_pipeline$priority_score <- round(
  (100 - open_pipeline$record_completeness) * 0.45 +
    stale_component +
    ifelse(is.na(value_percentile), 0, value_percentile * 20)
)
open_pipeline$recommended_action <- ifelse(
  open_pipeline$record_completeness < 80,
  "Complete CRM record",
  ifelse(
    open_pipeline$deal_stage == "Engaging" & open_pipeline$stale_days >= 60,
    "Review stalled opportunity",
    ifelse(
      open_pipeline$deal_stage == "Engaging" & open_pipeline$stale_days >= 30,
      "Confirm next step or close",
      "Progress next action"
    )
  )
)
open_pipeline <- open_pipeline[order(-open_pipeline$priority_score, -open_pipeline$sales_price), ]
action_queue <- open_pipeline[c(
  "opportunity_id", "deal_stage", "sales_agent", "manager", "regional_office",
  "product", "account", "sales_price", "engage_date", "stale_days",
  "record_completeness", "priority_score", "recommended_action"
)]
write_table(action_queue, "open_pipeline_action_queue.csv")

# 6. Tableau-ready analytical grain ---------------------------------------
tableau_deals <- deals[c(
  "opportunity_id", "deal_stage", "engage_date", "close_date", "close_month",
  "sales_agent", "manager", "regional_office", "product", "series",
  "sales_price", "account", "sector", "office_location", "account_revenue_m",
  "employees", "is_closed", "is_won", "close_value", "sales_cycle_days",
  "discount_pct", "account_known", "account_enriched"
)]
write.csv(
  tableau_deals,
  file.path(processed_dir, "cerneva_deal_detail.csv"),
  row.names = FALSE,
  na = ""
)
write.csv(
  action_queue,
  file.path(processed_dir, "cerneva_action_queue.csv"),
  row.names = FALSE,
  na = ""
)

# 7. Visual evidence -------------------------------------------------------
ink <- "#211B1F"
oxblood <- "#5B1738"
rose <- "#A75A78"
brass <- "#C49A5A"
ivory <- "#F5F0E7"
muted <- "#756B70"

png(file.path(figures_dir, "won_revenue_by_product.png"), width = 1400, height = 850, res = 150)
par(mar = c(8, 5, 3, 1), bg = ivory, fg = ink, col.axis = ink, col.lab = ink)
barplot(
  product_summary$won_revenue / 1e6,
  names.arg = product_summary$product,
  las = 2,
  col = c(brass, oxblood, rep(rose, max(0, nrow(product_summary) - 2))),
  border = NA,
  ylab = "Won revenue (USD millions)",
  main = "Revenue is concentrated in the premium product lines"
)
dev.off()

png(file.path(figures_dir, "win_rate_by_region.png"), width = 1200, height = 760, res = 150)
par(mar = c(5, 5, 3, 1), bg = ivory, fg = ink, col.axis = ink, col.lab = ink)
region_bar <- barplot(
  region_summary$win_rate * 100,
  names.arg = region_summary$regional_office,
  col = oxblood,
  border = NA,
  ylim = c(0, 75),
  ylab = "Closed-deal win rate (%)",
  main = "Regional win rates are operationally similar"
)
abline(h = global_win_rate * 100, col = brass, lwd = 3, lty = 2)
text(region_bar, region_summary$win_rate * 100 + 2, sprintf("%.1f%%", region_summary$win_rate * 100), col = ink)
dev.off()

png(file.path(figures_dir, "sales_cycle_by_outcome.png"), width = 1200, height = 760, res = 150)
par(mar = c(5, 5, 3, 1), bg = ivory, fg = ink, col.axis = ink, col.lab = ink)
boxplot(
  sales_cycle_days ~ deal_stage,
  data = closed,
  col = c(rose, oxblood),
  border = ink,
  ylab = "Sales-cycle days",
  main = "Sales-cycle duration by outcome",
  outline = FALSE
)
dev.off()

png(file.path(figures_dir, "forecast_calibration.png"), width = 1200, height = 760, res = 150)
par(mar = c(5, 5, 3, 1), bg = ivory, fg = ink, col.axis = ink, col.lab = ink)
plot(
  calibration$mean_predicted,
  calibration$actual_win_rate,
  pch = 19,
  cex = 2,
  col = oxblood,
  xlim = c(0, 1),
  ylim = c(0, 1),
  xlab = "Mean predicted probability",
  ylab = "Observed win rate",
  main = "Forecast diagnostic: chronological holdout"
)
abline(0, 1, col = brass, lwd = 3, lty = 2)
dev.off()

png(file.path(figures_dir, "cerneva_executive_preview.png"), width = 1600, height = 900, res = 150)
par(bg = ivory, mar = c(0, 0, 0, 0))
plot.new()
plot.window(xlim = c(0, 100), ylim = c(0, 100))
rect(0, 0, 100, 100, col = ivory, border = NA)
rect(0, 90, 100, 100, col = oxblood, border = NA)
text(4, 95, "CERNEVA", adj = c(0, 0.5), col = ivory, cex = 2.2, font = 2)
text(96, 95, "COMMERCIAL INTELLIGENCE", adj = c(1, 0.5), col = brass, cex = 0.9)
kpi_values <- c(
  currency(sum(won$close_value, na.rm = TRUE)),
  sprintf("%.1f%%", global_win_rate * 100),
  sprintf("%.0f days", median(closed$sales_cycle_days, na.rm = TRUE)),
  format(nrow(action_queue), big.mark = ",")
)
kpi_labels <- c("Won revenue", "Closed win rate", "Median sales cycle", "Open opportunities")
for (i in seq_along(kpi_values)) {
  x0 <- 4 + (i - 1) * 24
  rect(x0, 72, x0 + 21, 86, col = "white", border = "#DED5D9", lwd = 1.5)
  text(x0 + 2, 81, kpi_values[i], adj = c(0, 0.5), col = ink, cex = 1.45, font = 2)
  text(x0 + 2, 76, kpi_labels[i], adj = c(0, 0.5), col = muted, cex = 0.8)
}
rect(4, 9, 62, 67, col = "white", border = "#DED5D9")
text(7, 62, "Won revenue by product", adj = c(0, 0.5), col = ink, cex = 1.05, font = 2)
max_revenue <- max(product_summary$won_revenue)
for (i in seq_len(min(6, nrow(product_summary)))) {
  y <- 56 - (i - 1) * 8
  width <- 46 * product_summary$won_revenue[i] / max_revenue
  rect(7, y - 2.5, 7 + width, y + 1.5, col = ifelse(i <= 2, oxblood, rose), border = NA)
  text(7, y + 3.5, product_summary$product[i], adj = c(0, 0.5), col = ink, cex = 0.72)
  text(55, y - 0.5, currency(product_summary$won_revenue[i]), adj = c(1, 0.5), col = ink, cex = 0.72)
}
rect(65, 36, 96, 67, col = "white", border = "#DED5D9")
text(68, 62, "Forecast integrity", adj = c(0, 0.5), col = ink, cex = 1.05, font = 2)
text(68, 54, sprintf("Holdout AUC  %.3f", model_metrics$roc_auc[1]), adj = c(0, 0.5), col = oxblood, cex = 1.1, font = 2)
text(68, 48, sprintf("Model Brier  %.3f", model_metrics$brier_score[1]), adj = c(0, 0.5), col = ink, cex = 0.85)
text(68, 43, sprintf("Baseline       %.3f", model_metrics$brier_score[2]), adj = c(0, 0.5), col = ink, cex = 0.85)
text(68, 38.5, "Decision: do not automate", adj = c(0, 0.5), col = oxblood, cex = 0.82, font = 2)
rect(65, 9, 96, 32, col = oxblood, border = NA)
text(68, 27, "THE COMMERCIAL CALL", adj = c(0, 0.5), col = brass, cex = 0.78, font = 2)
text(68, 21, "Improve activity and stage-history", adj = c(0, 0.5), col = ivory, cex = 0.82)
text(68, 16, "capture before trusting forecasts.", adj = c(0, 0.5), col = ivory, cex = 0.82)
dev.off()

# 8. Executive decision brief ----------------------------------------------
total_won_revenue <- sum(won$close_value, na.rm = TRUE)
top_two_share <- sum(head(product_summary$won_revenue, 2)) / total_won_revenue
regional_spread <- max(region_summary$win_rate) - min(region_summary$win_rate)
missing_open_records <- sum(action_queue$record_completeness < 80)

brief <- c(
  "# Cerneva executive commercial brief",
  "",
  paste0("**Decision question:** Where should sales leadership intervene, and how much confidence should it place in the current CRM forecast?"),
  "",
  "## What the evidence says",
  "",
  paste0("- **", currency(total_won_revenue), "** was won across **", format(nrow(closed), big.mark = ","), "** closed opportunities."),
  paste0("- The overall closed-deal win rate was **", sprintf("%.1f%%", global_win_rate * 100), "**, with a median sales cycle of **", median(closed$sales_cycle_days, na.rm = TRUE), " days**."),
  paste0("- The two highest-revenue products generated **", sprintf("%.1f%%", top_two_share * 100), "** of won revenue. Commercial planning should separate premium-product value from unit volume."),
  paste0("- Regional win rates differed by only **", sprintf("%.1f percentage points", regional_spread * 100), "**. The data does not justify declaring one region structurally superior."),
  paste0("- **", missing_open_records, "** open opportunities need basic CRM fields completed before leadership can rely on pipeline reporting."),
  "",
  "## Forecast integrity",
  "",
  paste0("The known-at-engagement logistic model produced a chronological holdout ROC AUC of **", sprintf("%.3f", model_metrics$roc_auc[1]), "**. Its Brier score was **", sprintf("%.3f", model_metrics$brier_score[1]), "**, compared with **", sprintf("%.3f", model_metrics$brier_score[2]), "** for the simple training win-rate baseline."),
  "",
  paste0("**Model decision:** ", model_decision, "."),
  "",
  "The CRM records who owned the opportunity, the product and the account, but not stage changes, calls, meetings, stakeholder engagement, next-step dates or buyer intent. Those missing behavioural signals are the priority data-engineering requirement; a more complex algorithm would not repair the evidence gap.",
  "",
  "## Recommended actions",
  "",
  "1. Work the ranked open-pipeline queue, beginning with incomplete and long-stalled opportunities.",
  "2. Add activity history, stage-transition timestamps, buyer-role coverage and next-step dates to the CRM model.",
  "3. Review premium-product pipeline separately because it drives revenue concentration.",
  "4. Reassess forecast modelling only after the new signals cover at least two complete sales cycles.",
  "",
  "## Analytical guardrail",
  "",
  "Cerneva does not present a weak model as artificial certainty. It uses the failed holdout test as a decision: improve the underlying commercial evidence before operationalising predictive scores."
)
writeLines(brief, file.path(docs_dir, "executive-brief.md"))

# Compact machine-readable run summary for CI and portfolio metadata.
run_summary <- data.frame(
  metric = c(
    "source_rows", "closed_deals", "won_deals", "won_revenue",
    "win_rate", "median_cycle_days", "open_opportunities",
    "holdout_auc", "model_brier", "baseline_brier", "model_operationalised"
  ),
  value = c(
    nrow(deals), nrow(closed), nrow(won), total_won_revenue,
    global_win_rate, median(closed$sales_cycle_days, na.rm = TRUE), nrow(action_queue),
    model_metrics$roc_auc[1], model_metrics$brier_score[1],
    model_metrics$brier_score[2], model_is_useful
  )
)
write.csv(run_summary, file.path(processed_dir, "run_summary.csv"), row.names = FALSE)

message("Cerneva pipeline complete: ", nrow(deals), " opportunities processed; model decision = ", model_decision)
