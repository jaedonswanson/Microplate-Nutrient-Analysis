# A bundle of packages for data wrangling and plotting. Includes dplyr (data manipulation) and ggplot2 (graphs).
library(tidyverse)
# Adds extra annotation tools to ggplot2 (e.g., stat_poly_eq).
library(ggpmisc)
# =============================================================================
# USER INPUTS — CHANGE THESE FOR EACH PLATE
# =============================================================================
# --- File path ---------------------------------------------------------------
# Update this to point to the CSV file for the plate you are checking.
<<<<<<< HEAD
data <- read.csv("Plates/Nitrite/06222026_nitrite.csv")
=======
data <- read.csv("Plates/Nitrite/06172026_nitrite_1.csv")
>>>>>>> 3e423c27125c1cdc906cde778036428591f7a5f0
# --- Which standard range are you using? -------------------------------------
# Set USE_HIGH_RANGE to TRUE for n_high, or FALSE for n_low.
# This controls which set of known concentrations gets attached to your data.
USE_HIGH_RANGE <- FALSE   # <-- CHANGE THIS: TRUE = high range, FALSE = low range

# --- Which standard rows should be DROPPED? ----------------------------------
# Leave as c() (empty) to keep all standards.
ROWS_TO_DROP <- c()   # <-- CHANGE THIS each plate as needed
# =============================================================================
# SECTION 2: CONCENTRATION VECTORS
# =============================================================================
# These are the *known* concentrations (in µM) for each row of standards.
n_low  <- c(0, 0.05, 0.1, 0.2, 0.4, 0.6, 0.8, 1.0)   # Low-range standards
n_high <- c(0, 0.2,  0.5, 1.0, 2.0, 4.0, 7.5, 10.0)  # High-range standards
# Pick the right vector based on the flag you set above.
# 'if' works like this: if (condition) {do this} else {do that}
conc_vector <- if (USE_HIGH_RANGE) n_high else n_low

# Print a confirmation so you can double-check in the console.
cat("Using", if (USE_HIGH_RANGE) "HIGH" else "LOW", "range standards.\n")
cat("Concentrations:", paste(conc_vector, collapse = ", "), "\n\n")
# =============================================================================
# SECTION 3: DATA LOADING AND TIDYING
# =============================================================================

# Remove the stray "X" column Excel sometimes adds when you save a CSV.
# The %in% operator checks if "X" is in the column names.
if ("X" %in% names(data)) data$X <- NULL
# =============================================================================
# SECTION 4: BUILD THE STANDARDS TABLE
# =============================================================================
# We isolate the first 3 columns (the triplicates for each standard row),
# attach the known concentrations, then reshape the data for plotting.

standards_clean <- data %>%
  
  # Keep only columns 1, 2, and 3 (the three replicates of your standards).
  # 'select(1:3)' means "select columns 1 through 3.
  select(1:3) %>%
  
  # Give those columns simple names so we can reference them easily.
  setNames(c("Rep_1", "Rep_2", "Rep_3")) %>%
  
  # Make sure R treats all values as numbers, not text.
  mutate(across(everything(), as.numeric)) %>%
  
  # Add a column called Standard_Level numbering each row 1, 2, 3, ...
  # row_number() just counts the rows in order.
  mutate(Standard_Level = row_number()) %>%
  
  # Attach the known concentrations using the vector we selected above.
  # We use Standard_Level as an index: row 1 gets conc_vector[1], etc.
  mutate(Concentration = conc_vector[Standard_Level]) %>%
  
  # Add a column that marks whether this standard is flagged for removal.
  # %in% checks if Standard_Level is in our ROWS_TO_DROP list.
  mutate(Flagged = Standard_Level %in% ROWS_TO_DROP) %>%
  
  # 'pivot_longer' reshapes the data from WIDE format to LONG format.
  # WIDE: each replicate is its own column  →  Rep_1 | Rep_2 | Rep_3
  # LONG: each replicate is its own ROW    →  Replication | Absorbance
  # ggplot2 works much better with long-format data.
  pivot_longer(
    cols      = c("Rep_1", "Rep_2", "Rep_3"),  # Columns to collapse
    names_to  = "Replication",                  # New column: which replicate
    values_to = "Absorbance"                    # New column: the absorbance value
  )


# =============================================================================
# SECTION 5: PLOT 1 — ALL STANDARDS (unfiltered, flagged points highlighted)
# =============================================================================
# This first plot shows EVERYTHING, but visually marks the flagged standards
# in red so the viewer can see why they were eventually removed.

# Separate the data into "good" and "flagged" subsets for layering on the plot.
standards_good    <- standards_clean %>% filter(!Flagged)  # ! means "NOT flagged"
standards_flagged <- standards_clean %>% filter(Flagged)

# Build a linear model using only the good (non-flagged) data.
# lm() = "linear model". Formula: Absorbance ~ Concentration means
# "model Absorbance as a function of Concentration."
fit_all <- lm(Absorbance ~ Concentration, data = standards_clean)

# Extract the R² value from the model summary.
r2_all   <- summary(fit_all)$r.squared
# Extract the slope (how much absorbance changes per unit concentration).
slope_all <- coef(fit_all)[["Concentration"]]
# Extract the intercept (expected absorbance when concentration = 0).
intercept_all <- coef(fit_all)[["(Intercept)"]]

# Build an annotation label combining all three statistics.
# paste0() glues strings together. round() limits decimal places.
label_all <- paste0(
  "R² = ", round(r2_all, 4), " (all standards) \n ",             # \n = new line
  "Slope = ", round(slope_all, 4), "\n",
  "Intercept = ", round(intercept_all, 4)
)

# Build the plot using ggplot2.
# ggplot works in layers — each '+' adds a new layer on top of the previous one.
plot_all <- ggplot() +
  
  # LAYER 1: Gray connecting lines between replicates of the same standard.
  # These show how spread out (variable) the replicates are at each level.
  geom_line(
    data = standards_clean,
    aes(x = Concentration, y = Absorbance, group = Standard_Level),
    color = "gray80", linetype = "dashed"
  ) +
  
  # LAYER 2: Points for the GOOD (non-flagged) standards, colored by replicate.
  geom_point(
    data = standards_good,
    aes(x = Concentration, y = Absorbance, color = Replication),
    size = 3, alpha = 0.85
  ) +
  
  # LAYER 3: Points for FLAGGED standards — shown in red with a larger size
  # so they stand out immediately as the ones to investigate.
  geom_point(
    data = standards_flagged,
    aes(x = Concentration, y = Absorbance),
    color = "firebrick", size = 4, shape = 4,  # shape 4 = ✕ symbol
    stroke = 1.5
  ) +
  
  # LAYER 4: A label "FLAGGED" near each flagged standard group.
  # We calculate one label per Standard_Level (not per replicate) to avoid overlap.
  geom_label(
    data = standards_flagged %>%
      group_by(Standard_Level, Concentration) %>%
      summarise(Absorbance = max(Absorbance), .groups = "drop"),
    aes(x = Concentration, y = Absorbance, label = "FLAGGED"),
    color = "firebrick", fill = "white", size = 3,
    vjust = -0.6,         # nudge the label above the point
    label.size = 0.3
  ) +
  
  # LAYER 5: The regression line fitted to the GOOD data only, plus a shaded
  # 95% confidence band (se = TRUE). This shows uncertainty in the line itself.
  geom_smooth(
    data = standards_clean,
    aes(x = Concentration, y = Absorbance),
    method = "lm", se = TRUE,
    color = "black", fill = "steelblue", alpha = 0.15,
    linewidth = 0.9
  ) +
  
  # LAYER 6: Text box in the top-left with R², slope, and intercept.
  # hjust = 0 → left-align the text; vjust = 1 → anchor to the top.
  annotate(
    "label",
    x    = min(standards_good$Concentration, na.rm = TRUE),
    y    = max(standards_clean$Absorbance,   na.rm = TRUE),
    label = label_all,
    hjust = 0, vjust = 1,
    size  = 3.8, fontface = "bold",
    fill  = "white", label.size = 0.3
  ) +
  
  # Axis labels and titles.
  labs(
    title    = "Nitrite Standards: Full Calibration Curve (Flagged Standards Shown)",
    subtitle = paste(
      "Red ✕ marks = flagged rows:", paste(ROWS_TO_DROP, collapse = ", "),
      "| Regression fitted to non-flagged points only"
    ),
    x     = "Concentration (µM)",
    y     = "Absorbance (AU)",
    color = "Replicate"
  ) +
  
  # theme_minimal() removes the grey background and heavy gridlines.
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor  = element_blank(),
    plot.title        = element_text(face = "bold"),
    plot.subtitle     = element_text(color = "gray40", size = 10)
  )

# Print (display) the first plot.
print(plot_all)


# =============================================================================
# SECTION 6: PLOT 2 — FILTERED CALIBRATION CURVE (flagged standards removed)
# =============================================================================
# This is the "clean" version used for reporting. Flagged standards are gone.

# Remove the flagged rows entirely.
standards_filtered <- standards_clean %>% filter(!Flagged)
# Rebuild the linear model with only the clean data.
fit_filtered      <- lm(Absorbance ~ Concentration, data = standards_filtered)
r2_filtered       <- summary(fit_filtered)$r.squared
slope_filtered    <- coef(fit_filtered)[["Concentration"]]
intercept_filtered <- coef(fit_filtered)[["(Intercept)"]]
r2_direction <- if (r2_filtered > r2_all) "improved" else if (r2_filtered < r2_all) "WORSENED ⚠" else "unchanged"
label_filtered <- paste0(
  "R² = ", round(r2_filtered, 4), "\n",
  "Slope = ", round(slope_filtered, 4), "\n",
  "Intercept = ", round(intercept_filtered, 4)
)

# Report the improvement in R² to the console.
cat("=== R² Comparison ===\n")
cat("All standards (excl. flagged):", round(r2_all, 4), "\n")
cat("Filtered standards only:       ", round(r2_filtered, 4), "\n\n")

plot_filtered <- ggplot(standards_filtered,
                        aes(x = Concentration, y = Absorbance)) +
  
  # Dashed lines connecting replicates within each standard level.
  geom_line(
    aes(group = Standard_Level),
    color = "gray80", linetype = "dashed"
  ) +
  
  # Individual replicate points, colored by which replicate they are.
  geom_point(
    aes(color = Replication),
    size = 3, alpha = 0.85
  ) +
  
  # Linear regression line + shaded 95% confidence band.
  geom_smooth(
    method = "lm", se = TRUE,
    color = "black", fill = "steelblue", alpha = 0.15,
    linewidth = 0.9
  ) +
  
  # Stats annotation box.
  annotate(
    "label",
    x     = min(standards_filtered$Concentration, na.rm = TRUE),
    y     = max(standards_filtered$Absorbance,    na.rm = TRUE),
    label = label_filtered,
    hjust = 0, vjust = 1,
    size  = 3.8, fontface = "bold",
    fill  = "white", label.size = 0.3
  ) +
  
  labs(
    title    = "Nitrite Standards: Filtered Calibration Curve",
    subtitle = paste0(
      "Rows removed: ", paste(ROWS_TO_DROP, collapse = ", "),
      " | R² ", r2_direction, " from ", round(r2_all, 4),
      " → ", round(r2_filtered, 4)
    ),
    x     = "Concentration (µM)",
    y     = "Absorbance (AU)",
    color = "Replicate"
  ) +
  
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold"),
    plot.subtitle    = element_text(color = "gray40", size = 10)
  )

print(plot_filtered)