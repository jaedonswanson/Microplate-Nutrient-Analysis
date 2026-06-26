# Microplate Nutrient Analysis
This repository contains everything needed to get started running freshwater samples on a microplate. This is an efficent and inexpensive method of measuring nutrient concentration of freshwater samples. 

This repository also contains all R code used to automate the processing data. I first fit the standard curve then run the calculation script to output the data when I get a sufficent R2

Lastly, this repository contains all data I collected via microplate during my masters program at the University of Nebraska - Omaha

## Core Purpose
* **Data Cleaning:** Parses and cleans raw 96-well plate reader outputs.
* **Standard Curves:** Fits linear regressions to standard ladders to calculate exact sample concentrations.
* **Dilution & Blank Correction:** Automatically applies dilution factors and subtracts blanks.
* **Visualization:** Uses `ggplot2` to generate standard curve diagnostic plots and final data summaries.

## Required Materials
* Microplate reader that will read at 540 nm

## A note on sample collection
All samples should be filtered through a .45 micron filter. If the samples can not be processed the same day, freeze them and analyze as soon as possible. 

I have found that samples collected during baseline conditions (i.e. not immediately proceeding rainfall) are relatively stable when frozen. However, it has been my expeince that samples collected post precipitation are more likely to rapidly degrade. For this reason I recomend that if you are running samples post precipitation, run a 5x dilution as well as the undiluted sample on the same plate.