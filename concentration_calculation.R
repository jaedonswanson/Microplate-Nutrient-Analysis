library(tidyverse)
# =============================================================================
# Input Section
# =============================================================================
input_path     <- "Plates/Nitrite/06172026_nitrite_1.csv"
USE_HIGH_RANGE <- FALSE 
ROWS_TO_DROP   <- c()

# Quality Control Settings
MIN_R2_THRESHOLD <- 0.98  # Your target minimum R²
HALT_ON_LOW_R2   <- TRUE  # TRUE = stop script if R² is bad; FALSE = warn but proceed

# =============================================================================
# Concentration(s) & output
# =============================================================================
n_low  <- c(0, 0.05, 0.1, 0.2, 0.4, 0.6, 0.8, 1.0)   
n_high <- c(0, 0.2,  0.5, 1.0, 2.0, 4.0, 7.5, 10.0)  
conc_vector <- if (USE_HIGH_RANGE) n_high else n_low

output_path <- gsub("^Plates/", "Concentrations/", input_path)

# =============================================================================
# Curve Fitting
# =============================================================================
raw_data <- read.csv(input_path, check.names = FALSE)

standards_clean <- raw_data %>%
  select(2:4) %>%
  setNames(c("Rep_1", "Rep_2", "Rep_3")) %>%
  mutate(across(everything(), as.numeric)) %>%
  mutate(Standard_Level = row_number()) %>%
  mutate(Concentration = conc_vector[Standard_Level]) %>%
  mutate(Flagged = Standard_Level %in% ROWS_TO_DROP) %>%
  pivot_longer(
    cols      = c("Rep_1", "Rep_2", "Rep_3"),
    names_to  = "Replication",
    values_to = "Absorbance"
  )

standards_for_model <- standards_clean %>%
  filter(!Flagged) %>%
  drop_na(Absorbance)

fit_model  <- lm(Absorbance ~ Concentration, data = standards_for_model)
slope      <- coef(fit_model)[["Concentration"]]
intercept  <- coef(fit_model)[["(Intercept)"]]
current_r2 <- summary(fit_model)$r.squared

# =============================================================================
# SECTION 4: AUTOMATED QUALITY CONTROL & DIAGNOSTICS SCANNER
# =============================================================================
cat("--- Calibration Performance ---\n")
cat("Standard Range: ", if (USE_HIGH_RANGE) "HIGH (0-10 µM)" else "LOW (0-1.0 µM)", "\n")
cat("Omitted Rows:   ", if (length(ROWS_TO_DROP) == 0) "None" else paste(ROWS_TO_DROP, collapse = ", "), "\n")
cat("Achieved R²:    ", round(current_r2, 5), "\n")

if (current_r2 >= MIN_R2_THRESHOLD) {
  cat("✅ QC PASSED: R² meets ", MIN_R2_THRESHOLD, " threshold.\n\n", sep="")
} else {
  cat("\n=============================================================================\n")
  cat("❌ QC WARNING: Current R² (", round(current_r2, 4), ") is BELOW ", MIN_R2_THRESHOLD, " target!\n", sep="")
  cat("=============================================================================\n")
  cat("Running diagnostic scan to find a better calibration setup...\n\n")
  
  row_letters <- c("A", "B", "C", "D", "E", "F", "G", "H")
  
  for (i in 1:8) {
    # Simulate dropping this specific row standalone
    sim_standards <- standards_clean %>%
      filter(Standard_Level != i) %>%
      drop_na(Absorbance)
    
    if (nrow(sim_standards) > 2) {
      sim_fit <- lm(Absorbance ~ Concentration, data = sim_standards)
      sim_r2  <- summary(sim_fit)$r.squared
      
      status_marker <- if (sim_r2 >= MIN_R2_THRESHOLD) " [🎯 TARGET MET!]" else ""
      cat("  -> If you omit Row ", row_letters[i], " (Level ", i, "): Simulated R² = ", 
          round(sim_r2, 4), status_marker, "\n", sep="")
    }
  }
  
  cat("\n💡 Recommendation: Check your plate range setting or add a bad row to 'ROWS_TO_DROP' above.\n")
  
  if (HALT_ON_LOW_R2) {
    stop("Execution stopped: Data not exported due to low R² quality.")
  }
}

# =============================================================================
# SECTION 5: CONVERT UNKNOWNS & EXPORT LAYOUT (Runs only if QC passes or flag allows)
# =============================================================================
concentration_plate <- raw_data

# Back-calculate concentration for unknown columns 4 to 12 (indices 5:13)
for (col_idx in 5:13) {
  concentration_plate[[col_idx]] <- (as.numeric(concentration_plate[[col_idx]]) - intercept) / slope
}

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
write.csv(concentration_plate, output_path, row.names = FALSE)
cat("Matrix layout safely saved to: ", output_path, "\n")