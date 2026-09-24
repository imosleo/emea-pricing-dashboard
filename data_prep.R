# ETW2001 A2 - Data Preparation
# Reproduces the EMEA filter + World Bank merge entirely in R.
# OUTPUT: shiny_master_data.csv 

library(readxl)
library(dplyr)
library(tidyr)
library(readr)

#  1. The 40 EMEA countries (World Bank spellings) 
emea_countries <- c(
  "Albania","Armenia","Austria","Azerbaijan","Bahrain","Belarus",
  "Bosnia and Herzegovina","Bulgaria","Croatia","Czech Republic","Estonia","Georgia",
  "Hungary","Iran, Islamic Rep.","Iraq","Israel","Jordan","Kazakhstan","Kyrgyz Republic",
  "Lebanon","Lithuania","North Macedonia","Moldova","Mongolia","Montenegro","Poland",
  "Qatar","Romania","Russian Federation","Saudi Arabia","Slovak Republic","Slovenia",
  "Syrian Arab Republic","Tajikistan","Turkiye","Turkmenistan","Ukraine",
  "United Arab Emirates","Uzbekistan","Yemen, Rep."
)

#  2. Reusable function to clean a World Bank CSV 
# World Bank files have 4 junk header rows; real header is on row 5.
clean_wb <- function(filename, metric_name) {
  df <- read.csv(filename, skip = 4, check.names = FALSE,
                 stringsAsFactors = FALSE)
  df <- df[, c("Country Name", "2011", "2012", "2013", "2014")]
  df <- df[df[["Country Name"]] %in% emea_countries, ]
  df %>%
    pivot_longer(cols = c("2011", "2012", "2013", "2014"),
                 names_to = "Year", values_to = metric_name)
}

#  3. Clean all three indicators 
cat("Cleaning World Bank files...\n")
gdp          <- clean_wb("wb_gdp.csv",          "GDP_per_Capita")
inflation    <- clean_wb("wb_inflation.csv",    "Inflation_Rate")
unemployment <- clean_wb("wb_unemployment.csv", "Unemployment_Rate")

#  4. Merge the three external indicators 
external <- gdp %>%
  inner_join(inflation,    by = c("Country Name", "Year")) %>%
  inner_join(unemployment, by = c("Country Name", "Year"))
external$Year <- as.integer(external$Year)

#  5. Standardize World Bank names to Superstore names 
name_map <- c(
  "Iran, Islamic Rep."   = "Iran",
  "Kyrgyz Republic"      = "Kyrgyzstan",
  "North Macedonia"      = "Macedonia",
  "Russian Federation"   = "Russia",
  "Slovak Republic"      = "Slovakia",
  "Syrian Arab Republic" = "Syria",
  "Turkiye"              = "Turkey",
  "Yemen, Rep."          = "Yemen"
)
external <- external %>%
  rename(Country = `Country Name`) %>%
  mutate(Country = recode(Country, !!!name_map))

#  6. Load Superstore, filter to EMEA 
cat("Loading and filtering Superstore (EMEA)...\n")
superstore <- read_excel("superstore.xlsx")
superstore$Sales <- as.numeric(superstore$Sales)
emea <- superstore %>%
  filter(Market == "EMEA") %>%
  mutate(Year = as.integer(Year))

#  7. Merge (left join keeps ALL EMEA transactions) 
master <- emea %>%
  left_join(external, by = c("Country", "Year"))

# Drop the leftover junk record-count column if present (originally 记录数,
# read in by R as a column of dots). Matches a name that is X followed by dots.
master <- master[, !grepl("^X\\.+$", colnames(master)), drop = FALSE]

#  8. Save the file app.R will read 
write_csv(master, "shiny_master_data.csv")

#  9. Verification printout 
cat("SUCCESS: shiny_master_data.csv ready\n")
cat("Total EMEA rows:", nrow(master), "(expected 5029)\n")
cat("Rows with external data:", sum(!is.na(master$GDP_per_Capita)), "\n")
cat("Rows without match:", sum(is.na(master$GDP_per_Capita)), "\n")
unmatched <- sort(unique(master$Country[is.na(master$GDP_per_Capita)]))
cat("Countries without external match:",
    paste(unmatched, collapse = ", "), "\n\n")
cat("Critical narrative countries:\n")
for (cc in c("Turkey", "Kazakhstan")) {
  sub <- master[master$Country == cc, ]
  cat("  ", cc, ":", nrow(sub), "rows,",
      sum(!is.na(sub$GDP_per_Capita)), "with external data\n")
}
