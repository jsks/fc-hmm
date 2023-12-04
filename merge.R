#!/usr/bin/env Rscript
#
# Unit of Analysis: Conflict-years 1989 - 2021
###

library(dplyr)
library(readxl)
library(tidyr)

###
# SIPRI - Arms Transfer Dataset
tiv <- read.csv("./data/import-export-values_1950-2023.csv", skip = 9) |>
    select(Recipient, matches("^X\\d{4}$")) |>
    pivot_longer(cols = -Recipient, names_to = "year", values_to = "tiv") |>
    mutate(year = sub("X", "", year) |> as.numeric(),
           tiv = case_when(tiv ==  0 ~ 0.5,
                           is.na(tiv) ~ 0,
                           T ~ tiv)) |>
    filter(between(year, 1989, 2021))

###
# UCDP Terminations - Start with peace aggreements (1975 - 2021)
pce <- read_xlsx("./data/ucdp-peace-agreements-221.xlsx") |>
    select(paid, year, conflict_id, pa_date, duration, inclusive, pa_type) |>
    separate_longer_delim(conflict_id, delim = ",") |>
    mutate(conflict_id = as.numeric(conflict_id),
           year = as.numeric(year),
           end_date = as.Date(duration),
           pa_date = as.Date(pa_date),
           duration = end_date - pa_date,
           full_pax = inclusive == 1 & pa_type == 1 &
               (is.na(duration) | end_date > as.Date(paste0(year + 1, "-12-31"))))

pax.df <- group_by(pce, conflict_id, year) |>
    arrange(pa_date) |>
    slice(n()) |>
    select(conflict_id, year, pax = paid, full_pax)

# Conflict Termination Dataset (1948 - 2019)
term <- read_xlsx("./data/ucdp-term-acd-3-2021.xlsx") |>
    filter(type_of_conflict %in% 3:4, outcome %in% c(3, 4, 6)) |>
    select(conflict_id, year, confterm)


term.df <- full_join(pax.df, term, by = c("conflict_id", "year")) |>
    filter(between(year, 1989, 2021)) |>
    mutate(confterm = ifelse(is.na(confterm), 0, confterm))

###
# UCDP - Conflict episodes
conflicts <- readRDS("./data/UcdpPrioConflict_v23_1.rds") |>
    filter(type_of_conflict %in% 3:4) |>
    distinct(conflict_id) |>
    pull(conflict_id)

# Battle related fatalities - Event dataset
deaths <- readRDS("./data/GEDEvent_v23_1.rds") |>
    filter(conflict_new_id %in% conflicts) |>
    group_by(conflict_new_id, side_a, year) |>
    summarise(brd = sum(best),
              brd_low = sum(low),
              brd_high = sum(high),
              gwno_a = first(gwnoa),
              side_b = unique(side_b) |> paste(collapse = ", ")) |>
    ungroup() |>
    select(conflict_id = conflict_new_id, side_a, side_b, year, matches("brd")) |>
    mutate(side_a = sub("Government of\\s*", "", side_a))

# Merge conflict terminations and BRD data
full.df <- filter(term.df, conflict_id %in% conflicts) |>
    full_join(deaths, by = c("conflict_id", "year")) |>
    mutate(confterm = ifelse(is.na(confterm), 0, confterm),
           full_pax = ifelse(is.na(full_pax), 0, full_pax)) |>
    arrange(conflict_id, year)

###
# Define our sequences - terminate a conflict either with a
# comprehensive peace agreement, military victory, or actor death. If
# there is no termination, we assume (for now) that the conflict is
# ongoing.
reduced.df <- group_by(full.df, conflict_id) |>
    arrange(desc(year)) |>
    mutate(terminated = confterm == 1 | full_pax == 1,
           idx = cumsum(terminated)) |>
    filter(idx == max(idx), year <= 2021)

# Expand out the full grid, so that we also include conflict-years where BRD == 0
seqs <- group_by(reduced.df, conflict_id) |>
    summarise(start = min(year),
              stop = ifelse(last(terminated) == 1, max(year), 2021))

grid <- lapply(1:nrow(seqs), \(i) data.frame(conflict_id = seqs$conflict_id[i],
                                             year = seqs$start[i]:seqs$stop[i])) |>
    bind_rows()

# Finally,
final.df <- full_join(reduced.df, grid, by = c("conflict_id", "year")) |>
    group_by(conflict_id) |>
    mutate(brd = ifelse(is.na(brd), 0, brd),
           brd_low = ifelse(is.na(brd_low), 0, brd_low),
           brd_high = ifelse(is.na(brd_high), 0, brd_high),
           total = sum(brd),
           side_a = first(side_a, na_rm = T),
           side_b = first(side_b, na_rm = T),
           full_pax = ifelse(is.na(full_pax), 0, full_pax),
           confterm = ifelse(is.na(confterm), 0, confterm),
           pax = ifelse(!is.na(pax), 1, 0),
           terminated = ifelse(is.na(terminated), F, terminated)) |>
    ungroup() |>
    arrange(conflict_id, year) |>
    filter(total >= 500)

###
# Merge SIPRI and UCDP data - Mismatched names between SIPRI and UCDP
setdiff(deaths$side_a, tiv$Recipient)
renamed.df <- final.df |>
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

merge.df <- left_join(renamed.df, tiv, by = c("side_a" = "Recipient", "year")) |>
    arrange(conflict_id, year)

stopifnot(!is.na(merge.df$tiv))

###
# Finally merge with V-Dem
vdem <- readRDS("./data/V-Dem-CY-Full+Others-v14.rds") |>
    select(country_name, year, v2x_polyarchy, e_area, e_pop, e_gdppc) |>
    mutate(country_name =
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

q <- left_join(merge.df, vdem, by = c("side_a" = "country_name", "year")) |>
    group_by(conflict_id) |>
    arrange(year) |>
    fill(e_pop, e_gdppc) |>
    ungroup() |>
    arrange(conflict_id, year)

###
# Ceasefires
ceasefires <- read_xlsx("./data/Conflict_onset_2022-1.xlsx") |>
    group_by(conflict_id, year) |>
    summarise(ceasefire = any(onset_declare == 1)) |>
    filter(ceasefire) |>
    mutate(year = year + 1) |>
    ungroup()

model_data <- left_join(q, ceasefires, by = c("conflict_id", "year")) |>
    mutate(ceasefire = ifelse(is.na(ceasefire), 0, 1)) |>
    arrange(conflict_id, year)

saveRDS(model_data, "./data/merge.rds")
