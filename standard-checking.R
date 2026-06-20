library(ggpmisc)
library(tidyverse)
library(ggplot2)
library(dplyr)
# 1. Load and clean data (same as before)
data <- read.csv("Plates/20260617_nitrite_2.csv")

data$X <- NULL
data <- data %>% drop_na()

# 1. Clean and reshape the data using the correct columns (2 through 4)
standards_clean <- data %>%
  # Skip Column 1 (A, B, C...) and select Columns 2, 3, and 4
  select(1:3) %>% 
  
  # Name them cleanly as Replications 1, 2, and 3
  setNames(c("1", "2", "3")) %>% 
  
  # Force them to be numeric
  mutate(across(everything(), as.numeric)) %>%       
  
  # Create X-axis index (1 to 8 for rows A through H)
  mutate(Standard_Level = row_number()) %>% 
  
  # Pivot them into long format
  pivot_longer(
    cols = c("1", "2", "3"), 
    names_to = "Replication", 
    values_to = "Absorbance"                 
  )

# 2. Calculate the R2 value
fit <- lm(Absorbance ~ Standard_Level, data = standards_clean)
r2_value <- summary(fit)$r.squared
r2_label <- paste0("R^2 = ", round(r2_value, 4))

# 3. Create the graph
ggplot(standards_clean, aes(x = Standard_Level, y = Absorbance)) +
  geom_point(aes(color = Replication), size = 3, alpha = 0.8) + 
  geom_line(aes(group = Standard_Level), color = "gray80", linetype = "dashed") +
  geom_smooth(method = "lm", se = TRUE, color = "black", fill = "blue", alpha = 0.15) +
  
  annotate("text", 
           x = min(standards_clean$Standard_Level, na.rm = TRUE), 
           y = max(standards_clean$Absorbance, na.rm = TRUE), 
           label = r2_label, 
           hjust = 0, vjust = 1, size = 5, fontface = "bold", color = "black") +
  
  labs(
    title = "Nitrite Standards: Calibration Curve Check",
    subtitle = paste("Linear regression check for standard replications |", r2_label),
    x = "Standard",
    y = "Absorbance",
    color = "Replication"
  ) +
  theme_minimal() +
  theme(panel.grid.minor = element_blank())

library(ggplot2)
library(dplyr)
library(tidyr)
# 1. Clean, reshape, and filter out Standard 4 and 1 (keeping ALL replications)
standards_clean_filtered <- data %>%
  # Select columns 2, 3, and 4 (the true numeric replicates)
  select(1:3) %>% 
  setNames(c("1", "2", "3")) %>% 
  mutate(across(everything(), as.numeric)) %>%       
  mutate(Standard_Level = row_number()) %>% 
  
  # Pivot into long format so we have individual points
  pivot_longer(
    cols = c("1", "2", "3"), 
    names_to = "Replication", 
    values_to = "Absorbance"                 
  ) %>% 
  
  # REMOVE Standard 4 and Standard 1 from the replications dataset
  filter(Standard_Level != 4 & Standard_Level !=5)

# 2. Calculate the R2 value based on all remaining individual replications
fit_all_filtered <- lm(Absorbance ~ Standard_Level, data = standards_clean_filtered)
r2_value <- summary(fit_all_filtered)$r.squared
r2_label <- paste0("R^2 = ", round(r2_value, 4))

# 3. Create the graph showing all replicates except Standard 4
ggplot(standards_clean_filtered, aes(x = Standard_Level, y = Absorbance)) +
  # Plots individual replication points (colored 1, 2, 3)
  geom_point(aes(color = Replication), size = 3, alpha = 0.8) + 
  
  # Connects the remaining replicates vertically to show variance
  geom_line(aes(group = Standard_Level), color = "gray80", linetype = "dashed") +
  
  # Adds line of best fit and 95% confidence bands
  geom_smooth(method = "lm", se = TRUE, color = "black", fill = "blue", alpha = 0.15) +
  
  # Adds the recalculated R2 value to the top-left
  annotate("text", 
           x = min(standards_clean_filtered$Standard_Level, na.rm = TRUE), 
           y = max(standards_clean_filtered$Absorbance, na.rm = TRUE), 
           label = r2_label, 
           hjust = 0, vjust = 1, size = 5, fontface = "bold", color = "black") +
  
  labs(
    title = "Nitrite Standards: Filtered Calibration Curve",
    subtitle = paste("Standard 4 Removed | All remaining replications shown |", r2_label),
    x = "Standard Level (Row Index)",
    y = "Absorbance",
    color = "Replication"
  ) +
  theme_minimal() +
  theme(panel.grid.minor = element_blank())