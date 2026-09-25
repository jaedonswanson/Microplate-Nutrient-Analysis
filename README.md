# Colorometric analysis of NO$_x$

This repository contains everything needed to get started running freshwater samples on a microplate (elx800) or similar. This is an efficient and inexpensive method of measuring nutrient concentration in freshwater samples.

## A note on sample collection
If only collecting water samples, they should be filtered through a 0.45 micron filter. If the samples cannot be processed the same day, freeze them.

# Part 1: Setting up the experiment
**NOTE:** Double check the required chemicals; not all are needed if only running water samples.

1. Pick the relevant procedure:
   - [Ammonium](Procedures/Micoplate%20Anlaysis%20of%20Ammonium.md)
   - [Nitrate & Nitrite](Procedures/Microplate%20Analysis%20of%20Nitrate%20&%20Nitrite.md)

2. Set up an Excel file to act as a key for the sample locations.
   1. If not formatted like [this key](Plates/nitrate_key.xlsx), the code following this will break.

3. After the appropriate incubation time, analyze the plate using the computer software.
   - [Nitrate/Nitrite procedure](Nitrate-Nitrite_protocol.prt)
   - [Ammonium procedure](Procedures/Micoplate%20Anlaysis%20of%20Ammonium.md)

4. Copy the data to a CSV and name it.

## Part 2: Assessing the Standards
1. After the plate is run, copy the data to a `.csv` and name it:
   1. [MMDDYYYY_nutrient_replication](Plates/Nitrate/)
      1. This is essential to make sure the plate ID matches the corresponding key.

2. Open the [standard checking](Standard-Checking.qmd) and update the relevant information.
3. Run the script and examine the $r^2$ value.
   1. Ideally, all standards produce an $r^2$ ≥ 0.98.
4. If $r^2$ is < 0.98, examine the graph and remove problem standards.
   1. **Notes:**
      1. If possible, do not remove a standard that best approximates sample concentration.
      2. If you have to remove more than 3 standards (only 5 points remaining), something likely went wrong and you should start over.

# Part 3: Calculating concentrations
1. Open the [concentration calculation](concentration_calculation.qmd) script.
2. Update the information to exactly match the settings from above (e.g., plate ID, removed standards).
3. Run the script.
4. It should output a file with the concentrations of your samples.

# Part 4: Tidying
1. Whenever you want a clean file of your data, run the [tidying script](tidying.qmd).
   1. **Note:** Update site names and output paths to reflect your desired output.