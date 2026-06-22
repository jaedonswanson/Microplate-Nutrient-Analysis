# BEFORE RUNNING:
#   1. Run your calibration script and note the slope and intercept it prints.
#   2. Fill in those values in SECTION 1 below.
#   3. Update the file path and column range for your unknowns.
# =============================================================================
library(tidyverse)   # For data wrangling and the %>% pipe operator
# =============================================================================
# SECTION 1: USER INPUTS — UPDATE THESE FOR EACH PLATE
# =============================================================================

# --- Calibration values ------------------------------------------------------
# Copy these from the annotation box or console output of your calibration
# script. These tell us the relationship between absorbance and concentration.
SLOPE     <- 0.5132    # <-- PASTE your slope here
INTERCEPT <- 0.0821    # <-- PASTE your intercept here

# --- File path ---------------------------------------------------------------
# Point this to the same CSV used in the calibration script.
data <- read.csv("Plates/Nitrite/20260617_nitrite_2.csv")

# --- Which columns are your UNKNOWN samples? ---------------------------------
# Set these to the column numbers that contain your unknown sample absorbances.
# Example: if unknowns are in columns 4 through 12, set:
#   SAMPLE_COL_START <- 4
#   SAMPLE_COL_END   <- 12
SAMPLE_COL_START <- 4    # <-- CHANGE THIS
SAMPLE_COL_END   <- 12   # <-- CHANGE THIS

# --- How many rows are your standards? ---------------------------------------
# The first N rows are standards — we skip those and only process sample rows.
# For an 8-point standard curve, this is 8.
N_STANDARD_ROWS <- 8     # <-- CHANGE THIS if your curve has more/fewer points

# --- Output file name --------------------------------------------------------
# The results CSV will be saved here. Change the name if you like.
OUTPUT_FILE <- "Results/nitrite_concentrations.csv"


# =============================================================================
# SECTION 2: LOAD AND CLEAN DATA
# =============================================================================

# Remove the stray "X" column Excel sometimes adds.
if ("X" %in% names(data)) data$X <- NULL

# Remove rows with missing values.
data <- data %>% drop_na()

# Pull out only the unknown sample rows (skip the standard rows at the top).
# Negative indexing in R: -1:-8 means "give me everything EXCEPT rows 1 to 8."
samples_raw <- data[-1:-N_STANDARD_ROWS, SAMPLE_COL_START:SAMPLE_COL_END]

# Print a quick check so you can confirm the right data was selected.
cat("=== Raw sample absorbance values loaded ===\n")
cat("Rows (samples):", nrow(samples_raw), "\n")
cat("Columns (replicates or wells):", ncol(samples_raw), "\n\n")


# =============================================================================
# SECTION 3: BACK-CALCULATE CONCENTRATIONS
# =============================================================================
# Apply the rearranged Beer-Lambert equation to every cell in the table.
# across(everything()) means "do this to every column."
# The tilde (~) and .x are how tidyverse writes a mini-function inline:
#   (.x - INTERCEPT) / SLOPE  means  (this_value - intercept) / slope

samples_conc <- samples_raw %>%
  mutate(across(everything(), ~ (.x - INTERCEPT) / SLOPE))

# Add a column labeling each row by sample number so results are easy to read.
# nrow() counts the number of rows; paste0() glues text together.
samples_conc <- samples_conc %>%
  mutate(Sample = paste0("Sample_", row_number()), .before = 1)

samples_raw <- samples_raw %>%
  mutate(Sample = paste0("Sample_", row_number()), .before = 1)

cat("=== Calculated concentrations (µM) ===\n")
print(samples_conc)
cat("\n")


# =============================================================================
# SECTION 4: SUMMARY STATISTICS PER SAMPLE
# =============================================================================
# For each sample row, calculate the mean and standard deviation across
# all replicates. This gives you one concentration estimate per sample
# with a measure of how consistent the replicates were.

# We need to pivot to long format first so we can summarise across replicates.
# pivot_longer() collapses all replicate columns into two columns:
#   "Replicate" (which column it came from) and "Concentration" (the value).

summary_stats <- samples_conc %>%
  pivot_longer(
    cols      = -Sample,           # Pivot everything EXCEPT the Sample column
    names_to  = "Replicate",
    values_to = "Concentration_uM"
  ) %>%
  group_by(Sample) %>%            # Do the calculations separately for each sample
  summarise(
    Mean_uM = round(mean(Concentration_uM, na.rm = TRUE), 4),   # Average
    SD_uM   = round(sd(Concentration_uM,   na.rm = TRUE), 4),   # Std deviation
    CV_pct  = round((SD_uM / Mean_uM) * 100, 2),                # % coefficient of variation
    N_reps  = n(),                                               # How many replicates
    .groups = "drop"
  ) %>%
  # Flag any samples with high variability (CV > 10% is a common threshold).
  # if_else() works like: if_else(condition, value_if_true, value_if_false)
  mutate(Flag = if_else(CV_pct > 10, "⚠ High CV", "OK"))

cat("=== Summary statistics per sample ===\n")
print(summary_stats)
cat("\n")

# Warn the user if any samples were flagged.
n_flagged <- sum(summary_stats$Flag != "OK")
if (n_flagged > 0) {
  cat("⚠ WARNING:", n_flagged, "sample(s) have CV > 10%. Check replicates.\n\n")
} else {
  cat("✓ All samples have acceptable replicate variability (CV ≤ 10%).\n\n")
}


# =============================================================================
# SECTION 5: SAVE RESULTS TO CSV
# =============================================================================
# Combine the raw absorbances, calculated concentrations, and summary stats
# into one tidy output file.

# Make sure the output folder exists; create it if not.
# dirname() extracts just the folder path from a full file path.
if (!dir.exists(dirname(OUTPUT_FILE))) {
  dir.create(dirname(OUTPUT_FILE), recursive = TRUE)
}

# Build a combined output table:
#   - Raw absorbances (so the reader can verify)
#   - Calculated concentrations per replicate
#   - Summary statistics
output_full <- summary_stats %>%
  left_join(
    # Pivot the concentration table to long, then back to wide with clearer names
    samples_conc %>%
      pivot_longer(cols = -Sample, names_to = "Replicate", values_to = "Conc_uM") %>%
      pivot_wider(names_from = Replicate, values_from = Conc_uM,
                  names_prefix = "Conc_"),
    by = "Sample"
  )

write.csv(output_full, OUTPUT_FILE, row.names = FALSE)
cat("✓ Results saved to:", OUTPUT_FILE, "\n")