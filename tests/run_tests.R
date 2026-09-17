options(stringsAsFactors = FALSE)

root <- Sys.getenv("CERNEVA_ROOT", unset = ".")
processed <- file.path(root, "data", "processed")
tables <- file.path(root, "outputs", "tables")

required_outputs <- c(
  file.path(processed, "cerneva_deal_detail.csv"),
  file.path(processed, "cerneva_action_queue.csv"),
  file.path(processed, "run_summary.csv"),
  file.path(tables, "data_quality_checks.csv"),
  file.path(tables, "forecast_model_metrics.csv"),
  file.path(tables, "product_performance.csv")
)

missing_outputs <- required_outputs[!file.exists(required_outputs)]
if (length(missing_outputs) > 0) {
  stop("Missing pipeline outputs: ", paste(missing_outputs, collapse = ", "))
}

deals <- read.csv(file.path(processed, "cerneva_deal_detail.csv"), na.strings = c("", "NA"))
queue <- read.csv(file.path(processed, "cerneva_action_queue.csv"), na.strings = c("", "NA"))
quality <- read.csv(file.path(tables, "data_quality_checks.csv"))
metrics <- read.csv(file.path(tables, "forecast_model_metrics.csv"))
summary <- read.csv(file.path(processed, "run_summary.csv"))

stopifnot(nrow(deals) == 8800)
stopifnot(length(unique(deals$opportunity_id)) == nrow(deals))
stopifnot(all(quality$status == "PASS"))
stopifnot(nrow(queue) == sum(deals$deal_stage %in% c("Prospecting", "Engaging")))
stopifnot(all(queue$record_completeness >= 0 & queue$record_completeness <= 100))
stopifnot(all(queue$priority_score >= 0 & queue$priority_score <= 100))
stopifnot(all(c("Known-at-engagement logistic model", "Training win-rate baseline") %in% metrics$model))
stopifnot(all(metrics$roc_auc >= 0 & metrics$roc_auc <= 1))
stopifnot(all(metrics$brier_score >= 0 & metrics$brier_score <= 1))
stopifnot(as.numeric(summary$value[summary$metric == "closed_deals"]) == 6711)
stopifnot(as.numeric(summary$value[summary$metric == "won_deals"]) == 4238)

message("All Cerneva validation tests passed.")
