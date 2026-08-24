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
  full_join(nitrite, by = c("Sample_ID", "Replication")) %>% # Keeps all records from both sets
  mutate(
    # We use coalesce ONLY for the calculation of total_n. 
    # This does NOT overwrite the nitrate or nitrite columns themselves.
    total_n = coalesce(nitrate, 0) + coalesce(nitrite, 0)
  )
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
#### Saving all created CSV files ####
write.csv(heron, "/Users/jaedonswanson/Desktop/School/MS/Research/Thesis/Data/heron_nitrogen.csv", row.names = FALSE)
write.csv(adams, "//Users/jaedonswanson/Desktop/School/MS/Research/Thesis/Data/adams_nitrogen.csv", row.names = FALSE)
write.csv(gcp, "/Users/jaedonswanson/Desktop/School/MS/Research/Thesis/Data/gcp_nitrogen.csv", row.names = FALSE)
write.csv(elmwood, "/Users/jaedonswanson/Desktop/School/MS/Research/Thesis/Data/elmwood_nitrogen.csv", row.names = FALSE)
write.csv(total_N, "/Users/jaedonswanson/Desktop/School/MS/Research/Thesis/Data/all_nitrogen.csv", row.names = FALSE)