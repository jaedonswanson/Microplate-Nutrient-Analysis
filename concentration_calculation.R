library(tidyverse)
library(readxl)
library(ggpmisc)

# =============================================================================
# Input Section — CHANGE ONLY THESE LINES FOR EACH RUN
# =============================================================================
# 1. Path to your raw plate data CSV
RAW_DATA_PATH  <- "Plates/Nitrate/06192026_nitrate_3.csv"

# 2. Paths to your master Excel layout keys
NITRATE_KEY_PATH <- "Plates/nitrate_key.xlsx"
NITRITE_KEY_PATH <- "Plates/nitrite_key.xlsx"

# 3. Standard curve calibration settings
USE_HIGH_RANGE <- FALSE 
ROWS_TO_DROP   <- c()

# 4. Quality Control Settings
MIN_R2_THRESHOLD <- 0.98  # Your target minimum R²
HALT_ON_LOW_R2   <- TRUE  # TRUE = stop script if R² is bad; FALSE = warn but proceed


# =============================================================================
# Load Data & Setup Concentration Vectors
# =============================================================================
data <- read.csv(RAW_DATA_PATH)

n_low  <- c(0, 0.05, 0.1, 0.2, 0.4, 0.6, 0.8, 1.0)   
n_high <- c(0, 0.2,  0.5, 1.0, 2.0, 4.0, 7.5, 10.0)  
conc_vector <- if (USE_HIGH_RANGE) n_high else n_low

# =============================================================================
# Curve Fitting
# =============================================================================
raw_data <- read.csv(RAW_DATA_PATH, check.names = FALSE)

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
cat("Omitted Rows:    ", if (length(ROWS_TO_DROP) == 0) "None" else paste(ROWS_TO_DROP, collapse = ", "), "\n")
cat("Achieved R²:     ", round(current_r2, 5), "\n")

if (current_r2 >= MIN_R2_THRESHOLD) {
  cat("✅ QC PASSED: R² meets ", MIN_R2_THRESHOLD, " threshold.\n\n", sep="")
} else {
  cat("\n=============================================================================\n")
  cat("❌ QC WARNING: Current R² (", round(current_r2, 4), ") is BELOW ", MIN_R2_THRESHOLD, " target!\n", sep="")
  cat("=============================================================================\n")
  cat("Running diagnostic scan to find a better calibration setup...\n\n")
  
  row_letters <- c("A", "B", "C", "D", "E", "F", "G", "H")
  
  for (i in 1:8) {
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
# SECTION 5: AUTOMATED KEY MAPPING AND FINAL CONCENTRATION CALCULATIONS
# =============================================================================
# AUTOMATED PATH SELECTION: Detects analyte type from your raw file path
is_nitrite <- grepl("nitrite", RAW_DATA_PATH, ignore.case = TRUE)
MASTER_KEY_PATH <- if (is_nitrite) NITRITE_KEY_PATH else NITRATE_KEY_PATH

# Strip directory path and extension to isolate file name components
file_base  <- str_remove(basename(RAW_DATA_PATH), "\\.csv$")
name_parts <- str_split_1(file_base, "_")
file_date  <- name_parts[1]  
file_plate <- name_parts[3]  

# Generate the correct layout sheet identifier (e.g., "06172026_1")
KEY_SHEET_NAME  <- paste0(file_date, "_", file_plate) 

# Redirect output folder away from /Plates/ and into /Concentrations/
target_out_dir      <- gsub("^Plates/", "Concentrations/", dirname(RAW_DATA_PATH))
WELL_OUTPUT_PATH    <- file.path(target_out_dir, paste0(file_base, ".csv"))


# --- 2. Process and Reshape the Plate Absorbance Data -------------------------
plate_long <- data %>%
  mutate(Row = LETTERS[1:n()]) %>%                    # FIX: Correctly maps A to H down the plate
  select(Row, matches("^X[0-9]+$|^[0-9]+$")) %>%
  pivot_longer(
    cols      = -Row, 
    names_to  = "Column", 
    values_to = "Absorbance"
  ) %>%
  mutate(Column = as.integer(str_extract(Column, "[0-9]+"))) %>%
  mutate(Concentration = (Absorbance - intercept) / slope)


# --- 3. Load and Flatten the Selected Excel Sheet -----------------------------
key_raw <- read_excel(MASTER_KEY_PATH, sheet = KEY_SHEET_NAME, .name_repair = "minimal")
colnames(key_raw)[1] <- "Row"

key_long <- key_raw %>%
  select(Row, matches("^[0-9]+$")) %>%
  pivot_longer(
    cols      = -Row, 
    names_to  = "Column", 
    values_to = "Sample_ID"
  ) %>%
  mutate(Column = as.integer(Column)) %>%
  mutate(Sample_ID = str_trim(Sample_ID)) %>%        # Strip all whitespace
  mutate(Sample_ID = na_if(Sample_ID, "")) %>%        # Now empty strings become NA
  filter(!is.na(Sample_ID))                          # Drop anything still empty


# --- 4. Merge Sample Keys, Calculate Replications, & Clean Columns -------------
final_well_data <- inner_join(key_long, plate_long, by = c("Row", "Column")) %>%
  filter(!is.na(Sample_ID)) %>%                       # Safety: drop anything without a name
  group_by(Sample_ID) %>%
  mutate(Replication = row_number()) %>%
  ungroup() %>%
  select(Sample_ID, Replication, Row, Column, Absorbance, Concentration)


# --- 5. Export Completed Data Tables to CSV -----------------------------------
dir.create(target_out_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(final_well_data, WELL_OUTPUT_PATH, row.names = FALSE)

cat("=========================================================================\n")
cat("🤖 AUTOMATED METADATA MERGE SUCCESSFUL!\n")
cat("Target Workbook Layout:", MASTER_KEY_PATH, "\n")
cat("Target Excel Sheet:    ", KEY_SHEET_NAME, "\n")
cat("Saved Well Results to: ", WELL_OUTPUT_PATH, "\n")
cat("=========================================================================\n")