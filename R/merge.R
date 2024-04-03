#!/usr/bin/env Rscript
#
# Unit of Analysis: Conflict-years 1990 - 2021
###

library(dplyr)
library(readxl)
library(tidyr)

window <- function(x, n) {
    x <- c(rep(NA, n - 1), x)
    lapply(1:(length(x) - n + 1), function(i) x[i:(i + n - 1)])
}

roll_mean <- function(x, n) {
    window(x, n) |> lapply(mean, na.rm = T) |> unlist()
}

###
# Conflict sequences
df <- readRDS("./data/sequences.rds") |>
    filter(conflict_id != 418) |>
    mutate(side_a = case_when(side_a == "Myanmar (Burma)" ~ "Myanmar",
                              side_a == "Russia (Soviet Union)" & year <= 1991 ~ "Soviet Union",
                              side_a == "Russia (Soviet Union)" & year > 1991 ~ "Russia",
                              side_a == "Yemen (North Yemen)" ~ "North Yemen",
                              side_a == "DR Congo (Zaire)" ~ "DR Congo",
                              side_a == "Cambodia (Kampuchea)" ~ "Cambodia",
                              side_a == "Turkey" ~ "Turkiye",
                              side_a == "Serbia (Yugoslavia)" & year < 1992 ~ "Yugoslavia",
                              side_a == "Serbia (Yugoslavia)" & year >= 1992 ~ "Serbia",
                              side_a == "United States of America" ~ "United States",
                              side_a == "Ivory Coast" ~ "Cote d'Ivoire",
                              T ~ side_a))

###
# V-Dem data
vdem <- readRDS("./data/raw/V-Dem-CY-Full+Others-v14.rds") |>
    select(country_name, COWcode, year, v2x_polyarchy, e_pop, e_gdppc) |>
    group_by(country_name) |>
    arrange(year) |>
    mutate(e_pop = log(e_pop) |> lag(),
           e_gdppc = log(e_gdppc) |> lag(),
           country_name =
               case_when(country_name ==  "Burma/Myanmar" ~ "Myanmar",
                         country_name == "Yemen" ~ "North Yemen",
                         country_name ==  "Democratic Republic of the Congo" ~ "DR Congo",
                         country_name == "Türkiye" ~ "Turkiye",
                         year < 1992 & country_name ==  "Serbia" ~ "Yugoslavia",
                         country_name ==  "Bosnia and Herzegovina" ~ "Bosnia-Herzegovina",
                         country_name ==  "Republic of the Congo" ~ "Congo",
                         country_name ==  "United States of America" ~ "United States",
                         country_name ==  "Ivory Coast" ~ "Cote d'Ivoire",
                         T ~ country_name))

# TODO: adjust newly independent countries, use the values from the
# previous unified country
vdem <- vdem |>
    mutate(e_pop = case_when(country_name == "Bosnia-Herzegovina" & year == 1992 ~ 7.02,
                             country_name == "South Sudan" & year == 2011 ~ 8.22,
                             T ~ e_pop),
           e_gdppc = case_when(country_name == "Bosnia-Herzegovina" & year == 1992 ~ 1.93,
                               country_name == "South Sudan" & year == 2011 ~ 1.30,
                               T ~ e_gdppc))

###
# PKO Data
pko <- read_xls("./data/raw/Third-Party-PKMs-version-3.5.xls") |>
    select(idx = OBSNUM, COWcode = CCODE1, start = STARTYR, end = ENDYR) |>
    mutate(end = ifelse(is.na(end), 2021, end)) |>
    reframe(COWcode = first(COWcode), year = (start+1):(end+1), .by = idx) |>
    distinct(COWcode, year) |>
    mutate(pko = 1)

###
# Ceasefires (1989 - 2021)
ceasefires <- read_xlsx("./data/raw/CFD_oct_2022_id-1.xlsx") |>
    filter(ucdp_acd_id != -1, partial == 0, p_holiday == 0,
           p_humanitarian == 0, cf_effect_yr != 0) |>
    mutate(year = ifelse(cf_effect_yr == -1, cf_dec_yr, cf_effect_yr)) |>
    select(conflict_id = ucdp_acd_id, year) |>
    group_by(conflict_id, year) |>
    summarise(ceasefire = 1) |>
    mutate(year = year + 1)

###
# SIPRI - Arms Transfer Dataset (1950 - 2023)
lags <- lapply(1:4, \(i) function(...) lag(..., n=i))
tiv <- read.csv("./data/raw/import-export-values_1950-2023.csv", skip = 9) |>
    select(Recipient, matches("^X\\d{4}$")) |>
    pivot_longer(cols = -Recipient, names_to = "year", values_to = "tiv") |>
    mutate(year = sub("X", "", year) |> as.numeric(),
           tiv = case_when(tiv == 0 ~ 0.5,
                           is.na(tiv) ~ 0,
                           T ~ tiv)) |>
    group_by(Recipient) |>
    arrange(year) |>
    mutate(across(tiv, .fns = lags, .names = "{.col}_{.fn}"),
           tiv_avg = roll_mean(tiv, 5)) |>
    ungroup()

###
# Full merge
merge.df <- left_join(df, vdem, by = c("side_a" = "country_name", "year")) |>
    left_join(pko, by = c("COWcode", "year")) |>
    left_join(ceasefires, by = c("conflict_id", "year")) |>
    left_join(tiv, by = c("side_a" = "Recipient", "year"))

model_data <- merge.df |>
    mutate(pko = replace_na(pko, 0),
           ceasefire = replace_na(ceasefire, 0)) |>
    group_by(conflict_id) |>
    arrange(year) |>
    fill(gwno_a, e_pop, e_gdppc) |>
    ungroup()

# Finally, add major ongoing civil conflicts
final.df <- filter(model_data, year != 1989) |>
    select(-termination_year) |>
    group_by(gwno_a, year) |>
    mutate(ongoing = (sum(brd) - brd) >= 500) |>
    ungroup() |>
    arrange(conflict_id, year)

# Save the final dataset
saveRDS(final.df, "./data/merge_data.rds")
