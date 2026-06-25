#### Setting Up the Environment ####
library(tidyverse)
library(ggpmisc)
nitrate_key_path <- "Plates/nitrate_key.xlsx"
nitrite_key_path <- "Plates/nitrite_key.xlsx"
min_r2 <- 0.98  # Your target minimum R²
stop_if_low_r2   <- TRUE

#### User Inputs (Should be same as calibration curve) ####
# Path to your plate
plate  <- "Plates/Nitrite/06192026_nitrite_1.csv"

# High or Low?
high_range <- FALSE 

# Rows to drop (Same as calibration curve)
bad_standards   <- c()

#### Load Data & Setup Concentration Vectors ####
data <- read.csv(plate)
n_low  <- c(0, 0.05, 0.1, 0.2, 0.4, 0.6, 0.8, 1.0)   
n_high <- c(0, 0.2,  0.5, 1.0, 2.0, 4.0, 7.5, 10.0)  
conc_vector <- if (high_range) n_high else n_low # if high_range is TRUE, use n_high; otherwise, use n_low

#### Curve Fitting ####
raw_data <- read.csv(plate, check.names = FALSE)

standards_clean <- raw_data %>% # setting up the standards data frame
  select(2:4) %>%
  setNames(c("Rep_1", "Rep_2", "Rep_3")) %>%
  mutate(across(everything(), as.numeric)) %>% # convert all columns to numeric
  mutate(Standard_Level = row_number()) %>% # add a new column for the standard level (1-8)
  mutate(Concentration = conc_vector[Standard_Level]) %>% # add a new column for the concentration based on the standard level
  mutate(Flagged = Standard_Level %in% bad_standards) %>% # add a new column to flag the bad standards
  pivot_longer( # reshape the data from wide to long format
    cols      = c("Rep_1", "Rep_2", "Rep_3"),
    names_to  = "Replication",
    values_to = "Absorbance"
  )

standards_for_model <- standards_clean %>% # filter out the flagged standards and drop any rows with NA absorbance values
  filter(!Flagged) %>%
  drop_na(Absorbance)

# calculate the linear model for the calibration curve
fit_model  <- lm(Absorbance ~ Concentration, data = standards_for_model)
slope      <- coef(fit_model)[["Concentration"]]
intercept  <- coef(fit_model)[["(Intercept)"]]
current_r2 <- summary(fit_model)$r.squared

#### Quality Control ####
cat("--- Calibration Performance ---\n")
cat("Standard Range: ", if (high_range) "HIGH (0-10 µM)" else "LOW (0-1.0 µM)", "\n") # add a line to indicate whether the standard range is high or low
cat("Omitted Rows:    ", if (length(bad_standards) == 0) "None" else paste(bad_standards, collapse = ", "), "\n") # add a line to indicate which rows have been omitted
cat("Achieved R²:     ", round(current_r2, 5), "\n") # add a line to indicate the achieved R² value

if (current_r2 >= min_r2) { # if the achieved R² value is greater than or equal to the minimum threshold, print a message indicating that the QC has passed
  cat("✅ QC PASSED: R² meets ", min_r2, " threshold.\n\n", sep="")
} else { # if the achieved R² value is less than the minimum threshold, print a warning message and run a diagnostic scan to find a better calibration setup
  cat("\n=============================================================================\n")
  cat("❌ QC WARNING: Current R² (", round(current_r2, 4), ") is BELOW ", min_r2, " target!\n", sep="")
  cat("=============================================================================\n")
  cat("Running diagnostic scan to find a better calibration setup...\n\n")
  
  row_letters <- c("A", "B", "C", "D", "E", "F", "G", "H")
  
  for (i in 1:8) # Loop through each standard level (1-8) to simulate omitting it and recalculating R²
    sim_standards <- standards_clean %>%
      filter(Standard_Level != i) %>%
      drop_na(Absorbance)
    
    if (nrow(sim_standards) > 3) { # Ensure there are enough data points to fit a model
      sim_fit <- lm(Absorbance ~ Concentration, data = sim_standards)
      sim_r2  <- summary(sim_fit)$r.squared
      
      status_marker <- if (sim_r2 >= min_r2) " [🎯 TARGET MET!]" else ""
      cat("  -> If you omit Row ", row_letters[i], " (Level ", i, "): Simulated R² = ", 
          round(sim_r2, 4), status_marker, "\n", sep="")
    }
  }
  
  cat("\n💡 Recommendation: Check your plate range setting or add a bad row to 'bad_standards' above.\n")
  
  if (stop_if_low_r2) { # If the user has set stop_if_low_r2 to TRUE, stop execution and prevent data export
    stop("Execution stopped: Data not exported due to low R² quality.")
  }
}


#### Mapping and Final Concentration Calculations ####
# AUTOMATED PATH SELECTION: Detects analyte type from your raw file path
is_nitrite <- grepl("nitrite", plate, ignore.case = TRUE)
key_path <- if (is_nitrite) nitrite_key_path else nitrate_key_path

# Strip directory path and extension to isolate file name components
file_base  <- str_remove(basename(plate), "\\.csv$")
name_parts <- str_split_1(file_base, "_")
file_date  <- name_parts[1]  
file_plate <- name_parts[3]  

# Generate the correct layout sheet identifier (e.g., "06172026_1")
key_sheet_name  <- paste0(file_date, "_", file_plate) 

# Redirect output folder away from /Plates/ and into /Concentrations/
target_out_dir      <- gsub("^Plates/", "Concentrations/", dirname(plate))
output_path    <- file.path(target_out_dir, paste0(file_base, ".csv"))


# Process and Reshape the Plate Absorbance Data
plate_long <- data %>%
  mutate(Row = LETTERS[1:n()]) %>%                    # Correctly maps A to H down the plate
  select(Row, matches("^X[0-9]+$|^[0-9]+$")) %>% # Selects only the columns that are either named like "X1", "X2", etc., or just numbers
  pivot_longer(
    cols      = -Row, 
    names_to  = "Column", 
    values_to = "Absorbance"
  ) %>%
  mutate(Column = as.integer(str_extract(Column, "[0-9]+"))) %>%
  mutate(Concentration = (Absorbance - intercept) / slope)

# Load and Flatten the Selected Excel Sheet 
key_raw <- read_excel(key_path, sheet = key_sheet_name, .name_repair = "minimal")
colnames(key_raw)[1] <- "Row"

key_long <- key_raw %>% # change the column names to match the expected format and reshape the data
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


# Merge Sample Keys, Calculate Replications, & Clean Columns
final_well_data <- inner_join(key_long, plate_long, by = c("Row", "Column")) %>%
  filter(!is.na(Sample_ID)) %>%                       # Safety: drop anything without a name
  group_by(Sample_ID) %>%
  mutate(Replication = row_number()) %>%
  ungroup() %>%
  select(Sample_ID, Replication, Row, Column, Absorbance, Concentration)


# Export Completed Data Tables to CSV
dir.create(target_out_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(final_well_data, output_path, row.names = FALSE)

# Print Summary of Exported Data
cat("=========================================================================\n")
cat("🤖 AUTOMATED METADATA MERGE SUCCESSFUL!\n")
cat("Target Workbook Layout:", key_path, "\n")
cat("Target Excel Sheet:    ", key_sheet_name, "\n")
cat("Saved Well Results to: ", output_path, "\n")
cat("=========================================================================\n")