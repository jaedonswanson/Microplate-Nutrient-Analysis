#### Loading Packages & Setting Up data ####
library(tidyverse)
library(ggpmisc)
library(readxl)

# Creating the data frame containing the NO3 concentrations
nitrate <- list.files(path = "Concentrations/Nitrate", # Reading in and combining all csv files for concentrations 
                      pattern = "\\.csv$",
                      full.names = TRUE) %>%
  lapply(read_csv) %>%
  bind_rows %>%
  rename(nitrate = Concentration) %>% # Renaming Concentration to nitrate
  filter(!str_detect(Sample_ID, "High STD")) %>% # Removing the standards from the data frame
  filter(!str_detect(Sample_ID, "x5dilute")) %>% # Removing the dilutions since full samples were within the curve
  select(Sample_ID, Replication, nitrate) %>% # Keeping Sample_ID, Replication, and concentration
  mutate(nitrate = pmax(nitrate, 0)) # Changing all negative values to 0 since negative nitrate is not possible.

# Same as above, but for nitrite. Also was not necessary to remove dilutions since there were no dilutions for nitrite plates.
nitrite <- list.files(path = "Concentrations/Nitrite",
                      pattern = "\\.csv$",
                      full.names = TRUE) %>%
  lapply(read_csv) %>%
  bind_rows %>%
  rename(nitrite = Concentration) %>%
  filter(!str_detect(Sample_ID, "Low STD")) %>%
  select(Sample_ID, Replication, nitrite) %>%
  mutate(nitrite = pmax(nitrite, 0))

# Combining NO3 and NO2 to get NOx for each site/replicate.
total_N <- nitrate %>%
  inner_join(nitrite, by = c("Sample_ID", "Replication")) %>% # Joining on both Sample_ID and Replication
  mutate(total_n = nitrate + nitrite) # Calculating total N

# Printing all unique dates 
total_N %>%
  mutate(Date = str_sub(Sample_ID, -8, -1)) %>%
  pull(Date) %>%
  unique()

# Adding categorization of the dates as storm or base conditions
total_N <- total_N %>%
  mutate(Event = case_when(
    str_detect(Sample_ID, "06212026") ~ "storm",
    str_detect(Sample_ID, "07312026") ~ "storm",
    str_detect(Sample_ID, "08052026") ~ "storm",
    TRUE ~ "base"
  ))
# Adding categorization of the sites as wetland or stream
total_N <- total_N %>%
  mutate(Type = case_when(
    str_detect(Sample_ID, "gcp") ~ "stream", # gcp = stream
    str_detect(Sample_ID, "elm") ~ "stream", # elm = stream
    TRUE ~ "wetland" # not gcp or elm = wetland
  ))

heron <- total_N %>%
  filter(str_detect(Sample_ID, "heron")) %>%
  mutate(Subsite = case_when(
    str_detect(Sample_ID, "heron-map") ~ "Maple",
    str_detect(Sample_ID, "heron-resi") ~ "Residential",
    str_detect(Sample_ID, "heron-out") ~ "Out"
  ))

heron %>%
  mutate(Date = str_sub(Sample_ID, -8, -1)) %>%
  pull(Date) %>%
  unique()

adams <- total_N %>%
  filter(str_detect(Sample_ID, "adams")) %>%
  mutate(Subsite = case_when(
    str_detect(Sample_ID, "adams-in") ~ "In",
    str_detect(Sample_ID, "adams-mid-up") ~ "Mid-Up",
    str_detect(Sample_ID, "adams-mid-down") ~ "Mid-Down",
    str_detect(Sample_ID, "adams-out") ~ "Out"
  ))

adams %>%
  mutate(Date = str_sub(Sample_ID, -8, -1)) %>%
  pull(Date) %>%
  unique()

gcp <- total_N %>%
  filter(str_detect(Sample_ID, "gcp"))

gcp %>%
  mutate(Date = str_sub(Sample_ID, -8, -1)) %>%
  pull(Date) %>%
  unique()

elmwood <- total_N %>%
  filter(str_detect(Sample_ID, "elm")) %>%
  mutate(Subsite = case_when(
    str_detect(Sample_ID, "elm-bridge") ~ "Bridge",
    str_detect(Sample_ID, "elm-school") ~ "School"
  ))
elmwood %>%
  mutate(Date = str_sub(Sample_ID, -8, -1)) %>%
  pull(Date) %>%
  unique()







#### Heron Haven Visualization ####
heron_base_plot <- heron %>%
  filter(Event == "base") %>%
  mutate(Subsite = factor(Subsite, levels = c("Residential", "Maple", "Out"))) %>% # Reordering Subsite
  ggplot(aes(x = Subsite, y = total_n, fill = Subsite, color = Subsite)) + # 
  geom_dotplot(binaxis = 'y', stackdir = 'center',
               position = position_dodge(1), binwidth = 0.15,
               alpha = 1, dotsize = 1) +
  stat_summary(fun.data = mean_cl_normal, geom = "pointrange", size = 1, linewidth = 0.6, color = "black") +
  labs(title = "Dissolved Nitrogen at Heron Haven During Base Conditions", x = "Site", y = expression(bold("NOx (ppm)"))) +
  theme(axis.text = element_text(size = 18),
        axis.title = element_text(size = 18, face = "bold"),
        legend.position = "none") +
  scale_color_manual(values = c("#648FFF", "#FFB000", "#DC267F")) +
  scale_fill_manual(values = c("#648FFF", "#FFB000", "#DC267F"))

heron_storm_plot <- heron %>%
  filter(Event == "storm") %>%
  mutate(Subsite = factor(Subsite, levels = c("Residential", "Maple", "Out"))) %>% # Reordering Subsite
  ggplot(aes(x = Subsite, y = total_n, fill = Subsite, color = Subsite)) + # 
  geom_dotplot(binaxis = 'y', stackdir = 'center',
               position = position_dodge(1), binwidth = 0.15,
               alpha = 1, dotsize = 1) +
  stat_summary(fun.data = mean_cl_normal, geom = "pointrange", size = 1, linewidth = 0.6, color = "black") +
  labs(title = "Dissolved Nitrogen at Heron Haven After a Precipitation Event", x = "Site", y = expression(bold("NOx (ppm)"))) +
  theme(axis.text = element_text(size = 18),
        axis.title = element_text(size = 18, face = "bold"),
        legend.position = "none") +
  scale_color_manual(values = c("#648FFF", "#FFB000", "#DC267F")) +
  scale_fill_manual(values = c("#648FFF", "#FFB000", "#DC267F"))

heron_base_plot
heron_storm_plot

#### Adams Park Visualization ####
adams_base_plot <- adams %>%
  filter(Event == "base") %>%
  mutate(Subsite = factor(Subsite, levels = c("In", "Mid-Up", "Mid-Down", "Out"))) %>%
  ggplot(aes(x = Subsite, y = total_n, fill = Subsite, color = Subsite)) + # Added fill/color mapping
  geom_dotplot(binaxis = 'y', stackdir = 'center',
               position = position_dodge(1), binwidth = 0.01, # Shrunk binwidth to match smaller scale
               alpha = 1, dotsize = 1) +
  stat_summary(fun.data = mean_cl_normal, geom = "pointrange", size = 1, linewidth = 0.6, color = "black") +
  labs(title = "Dissolved Nitrogen at Adams Park During Base Conditions", x = "Site", y = expression(bold("NOx (ppm)"))) +
  theme(axis.text = element_text(size = 18),
        axis.title = element_text(size = 18, face = "bold"),
        legend.position = "none") +
  scale_color_manual(values = c("#648FFF", "#FFB000", "#DC267F", "#785EF0")) + # Added 4th color for 4 subsites
  scale_fill_manual(values = c("#648FFF", "#FFB000", "#DC267F", "#785EF0"))

adams_storm_plot <- adams %>%
  filter(Event == "storm") %>%
  mutate(Subsite = factor(Subsite, levels = c("In", "Mid-Up", "Mid-Down", "Out"))) %>%
  ggplot(aes(x = Subsite, y = total_n, fill = Subsite, color = Subsite)) + # Added fill/color mapping
  geom_dotplot(binaxis = 'y', stackdir = 'center',
               position = position_dodge(1), binwidth = 0.01, # Shrunk binwidth to match smaller scale
               alpha = 1, dotsize = 1) +
  stat_summary(fun.data = mean_cl_normal, geom = "pointrange", size = 1, linewidth = 0.6, color = "black") +
  labs(title = "Dissolved Nitrogen at Adams Park After a Precipitation Event", x = "Site", y = expression(bold("NOx (ppm)"))) +
  theme(axis.text = element_text(size = 18),
        axis.title = element_text(size = 18, face = "bold"),
        legend.position = "none") +
  scale_color_manual(values = c("#648FFF", "#FFB000", "#DC267F", "#785EF0")) + # Added 4th color for 4 subsites
  scale_fill_manual(values = c("#648FFF", "#FFB000", "#DC267F", "#785EF0"))

adams_base_plot
adams_storm_plot

#### Saving all created plots and CSV files ####
ggsave("heron_base_plot.png", plot = heron_base_plot, width = 12, height = 8, dpi = 300)
ggsave("heron_storm_plot.png", plot = heron_storm_plot, width = 12, height = 8, dpi = 300)
ggsave("adams_base_plot.png", plot = adams_base_plot, width = 12, height = 8, dpi = 300)
ggsave("adams_storm_plot.png", plot = adams_storm_plot, width = 12, height = 8, dpi = 300)
write.csv(heron, "/Users/jaedonswanson/Desktop/School/MS/Research/Wetland Stuff/heron.csv", row.names = FALSE)
write.csv(adams, "/Users/jaedonswanson/Desktop/School/MS/Research/Wetland Stuff/adams.csv", row.names = FALSE)