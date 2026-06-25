#### Packages used in this code ####
library(tidyverse)
library(ggpmisc)

#### User inputs ####
# File path
data <- read.csv("Plates/Nitrate/06252026_nitrate_1.csv")
# High or low?
USE_HIGH_RANGE <- TRUE
#Potential problem standards
ROWS_TO_DROP <- c()   # only change this after checking the curve with all points

#### Concentration Vector creation ####
# Concentrations for the standards (ppm)
n_low  <- c(0, 0.05, 0.1, 0.2, 0.4, 0.6, 0.8, 1.0)   # Low standards
n_high <- c(0, 0.2,  0.5, 1.0, 2.0, 4.0, 7.5, 10.0)  # High standards
conc_vector <- if (USE_HIGH_RANGE) n_high else n_low
# Print a confirmation so you can double-check in the console.
cat("Using", if (USE_HIGH_RANGE) "HIGH" else "LOW", "range standards.\n")
cat("Concentrations:", paste(conc_vector, collapse = ", "), "\n\n")
# the microplate adds a seemingly useless column "X" so remove it
if ("X" %in% names(data)) data$X <- NULL

#### Building the data frame of just standards to be graphed. ####
standards_clean <- data %>%
  select(1:3) %>% # the rows with the standards
  setNames(c("Rep_1", "Rep_2", "Rep_3")) %>% #not necassary, but makes it easier to read replications
  mutate(across(everything(), as.numeric)) %>% # ensuring all vectors are treated as numeric
  mutate(Standard_Level = row_number()) %>% #adding a column for standard level numbering each row
  mutate(Concentration = conc_vector[Standard_Level]) %>% # attatches the correct concentrations based on the selected level in user inputs
  mutate(Flagged = Standard_Level %in% ROWS_TO_DROP) %>% # adds a way to see which standards are removed from the standard curve.
  pivot_longer( # ggplot2 expects a long format
    cols      = c("Rep_1", "Rep_2", "Rep_3"),  # columns to collapse
    names_to  = "Replication",                  # New column: replicate
    values_to = "Absorbance"                    # New column: absorbance
  )
#### Plot 1: All standards (Showing flagged if applicable) ####
# Creating vectors for the 'good' and 'bad' standards.
standards_good    <- standards_clean %>% filter(!Flagged)  # included standards (! means "NOT flagged")
standards_flagged <- standards_clean %>% filter(Flagged)   # Flagged standards

# Creating vectors used for the R2 calculation
fit_all <- lm(Absorbance ~ Concentration, data = standards_clean) # linear model with the good standards
r2_all   <- summary(fit_all)$r.squared #r^2 for all standards
slope_all <- coef(fit_all)[["Concentration"]] # slope (how much absorbance changes per unit concentration).
intercept_all <- coef(fit_all)[["(Intercept)"]] # Extract the intercept (expected absorbance when concentration = 0).

# Building a label vector for the plot later.
label_all <- paste0(
  "R² = ", round(r2_all, 4), " (all standards) \n ",             # \n = new line
  "Slope = ", round(slope_all, 4), "\n",
  "Intercept = ", round(intercept_all, 4)
)
# Building the plot
plot_all <- ggplot() +
  geom_line(
    data = standards_clean,
    aes(x = Concentration, y = Absorbance, group = Standard_Level),
    color = "gray80", linetype = "dashed"
  ) +
    geom_point(
    data = standards_good, # Adding the good standards
    aes(x = Concentration, y = Absorbance, color = Replication),
    size = 3, alpha = 0.85 # how big and how transparent the points are
  ) +
  geom_point(
    data = standards_flagged, # Adding the flagged standards
    aes(x = Concentration, y = Absorbance),
    color = "firebrick", size = 4, shape = 4,  # making these show up as red X's (shape 4 = ✕ symbol)
    stroke = 1.5
  ) +
  geom_label( # Adding a 'FLAGGED' label to the removed standards.
    data = standards_flagged %>%
      group_by(Standard_Level, Concentration) %>%
      summarise(Absorbance = max(Absorbance), .groups = "drop"),
    aes(x = Concentration, y = Absorbance, label = "FLAGGED"),
    color = "firebrick", fill = "white", size = 3,
    vjust = -0.6,         # nudge the label above the point
    label.size = 0.3
  ) +
  geom_smooth( #regression line fitted to the GOOD data with 95% confidence band
    data = standards_clean,
    aes(x = Concentration, y = Absorbance),
    method = "lm", se = TRUE,
    color = "black", fill = "steelblue", alpha = 0.15,
    linewidth = 0.9
  ) +
  annotate( # Adding R2 and stuff to the graph
    "label",
    x    = min(standards_good$Concentration, na.rm = TRUE),
    y    = max(standards_clean$Absorbance,   na.rm = TRUE),
    label = label_all,
    hjust = 0, vjust = 1,
    size  = 3.8, fontface = "bold",
    fill  = "white", label.size = 0.3
  ) +
  labs(  # Axis labels and titles.
    title    = "Full Calibration Curve (Flagged Standards Shown)",
    subtitle = paste(
      "Red ✕ marks = flagged rows:", paste(ROWS_TO_DROP, collapse = ", "),
      "| Regression fitted to non-flagged points only"
    ),
    x     = "Concentration (µM)",
    y     = "Absorbance",
    color = "Replicate"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor  = element_blank(),
    plot.title        = element_text(face = "bold"),
    plot.subtitle     = element_text(color = "gray40", size = 10)
  )
print(plot_all) # Looking at the plot

#### Plot 2 — Calibration curve with flagged standards removed ####
# Remove the flagged rows entirely.
standards_filtered <- standards_clean %>% filter(!Flagged)
# Rebuild the linear model with only the clean data.
fit_filtered      <- lm(Absorbance ~ Concentration, data = standards_filtered)
r2_filtered       <- summary(fit_filtered)$r.squared
slope_filtered    <- coef(fit_filtered)[["Concentration"]]
intercept_filtered <- coef(fit_filtered)[["(Intercept)"]]
r2_direction <- if (r2_filtered > r2_all) "IMPROVED" else if (r2_filtered < r2_all) "WORSENED" else "unchanged"
label_filtered <- paste0(
  "R² = ", round(r2_filtered, 4), "\n",
  "Slope = ", round(slope_filtered, 4), "\n",
  "Intercept = ", round(intercept_filtered, 4)
)

# Report the improvement in R² to the console.
cat("=== R² Comparison ===\n")
cat("All standards (excl. flagged):", round(r2_all, 4), "\n")
cat("Filtered standards only:       ", round(r2_filtered, 4), "\n\n")

plot_filtered <- ggplot(data = standards_filtered, aes(x = Concentration, y = Absorbance)) +
  geom_line(   # connecting replicates within each standard level.
    aes(group = Standard_Level),
    color = "gray80", linetype = "dashed"
  ) +
  geom_point(  # Individual replicate points, colored by which replicate they are.

    aes(color = Replication),
    size = 3, alpha = 0.85
  ) +
  geom_smooth(   # Linear regression line + shaded 95% confidence band.
    method = "lm", se = TRUE,
    color = "black", fill = "steelblue", alpha = 0.15,
    linewidth = 0.9
  ) +
  annotate(  # Added R2 stuff

    "label",
    x     = min(standards_filtered$Concentration, na.rm = TRUE),
    y     = max(standards_filtered$Absorbance,    na.rm = TRUE),
    label = label_filtered,
    hjust = 0, vjust = 1,
    size  = 3.8, fontface = "bold",
    fill  = "white", label.size = 0.3
  ) +
  
  labs( # Labels
    title    = "Filtered Calibration Curve",
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