#!/usr/bin/env Rscript
#
# Create sequence of active and non-active years for all civil
# conflicts in UCDP.
###

library(dplyr)
library(readxl)
library(tidyr)

###
# UCDP peace agreements (1975 - 2021)
pce <- read_xlsx("./data/raw/ucdp-peace-agreements-221.xlsx") |>
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
term <- read_xlsx("./data/raw/ucdp-term-acd-3-2021.xlsx") |>
    filter(type_of_conflict %in% 3:4, outcome %in% c(3, 4, 6)) |>
    select(conflict_id, year, confterm)

# Merged termination dataset
term.df <- full_join(pax.df, term, by = c("conflict_id", "year")) |>
    filter(between(year, 1989, 2021)) |>
    mutate(confterm = ifelse(is.na(confterm), 0, confterm))

###
# Battle related fatalities - Event dataset
ged <- readRDS("./data/raw/GEDEvent_v23_1.rds")

# We need the conflict_id for all civil conflict episodes
conflicts <- readRDS("./data/raw/UcdpPrioConflict_v23_1.rds") |>
    filter(type_of_conflict %in% 3:4) |>
    distinct(conflict_id) |>
    pull(conflict_id)

deaths.df <- filter(ged, conflict_new_id %in% conflicts) |>
    group_by(conflict_new_id, side_a, year) |>
    summarise(brd = sum(best),
              brd_low = sum(low),
              brd_high = sum(high),
              gwno_a = first(gwnoa),  # Why tf isn't UCDP consistent?
              side_b = unique(side_b) |> paste(collapse = ", ")) |>
    ungroup() |>
    select(conflict_id = conflict_new_id, gwno_a, side_a, side_b, year, matches("brd")) |>
    mutate(side_a = sub("Government of\\s*", "", side_a))

# Merge conflict terminations and BRD data --- Use BRD data as the
# master dataset since there are some conflicts in the peace
# agreements dataset that are not in the BRD dataset (ex: South Africa
# - ANC).
con.df <- filter(term.df, conflict_id %in% conflicts) |>
    right_join(deaths.df, by = c("conflict_id", "year")) |>
    mutate(confterm = replace_na(confterm, 0),
           full_pax = replace_na(full_pax, 0)) |>
    arrange(conflict_id, year)

###
# Define our sequences - terminate a conflict when one of the
# followings conditions are met:
#     - Comprehensive peace agreement (UCDP peace agreements)
#     - Military victory (UCDP terminations)
#     - Actor death (UCDP terminations)
#
# If there is no termination, we assume (for now) that the conflict is
# ongoing.
reduced.df <- group_by(con.df, conflict_id) |>
    arrange(desc(year)) |>
    mutate(terminated = confterm == 1 | full_pax == 1,
           idx = cumsum(terminated)) |>
    filter(idx == max(idx), year <= 2021)

# Expand out the full grid, so that we also include conflict-years where BRD == 0
seqs <- group_by(reduced.df, conflict_id) |>
    arrange(year) |>
    summarise(start = min(year),
              stop = ifelse(last(terminated) == 1, max(year), 2021))

grid <- lapply(1:nrow(seqs), \(i) data.frame(conflict_id = seqs$conflict_id[i],
                                             year = seqs$start[i]:seqs$stop[i])) |>
    bind_rows()

final.df <- full_join(reduced.df, grid, by = c("conflict_id", "year")) |>
    group_by(conflict_id) |>
    arrange(year) |>
    mutate(brd = replace_na(brd, 0),
           brd_low = replace_na(brd_low, 0),
           brd_high = replace_na(brd_high, 0),
           total = cumsum(brd),
           side_a = first(side_a, na_rm = T),
           side_b = first(side_b, na_rm = T),
           full_pax = replace_na(full_pax, 0),
           confterm = replace_na(confterm, 0),
           pax = ifelse(!is.na(pax), 1, 0),
           terminated = replace_na(terminated, F)) |>
    ungroup()

###
# Manually adjust conflict ends for several conflicts that have
# officially ended, but aren't picked up by our criteria.
candidates <- read.csv("./data/candidates.csv") |>
    filter(!is.na(terminated)) |>
    select(conflict_id, termination_year = terminated)

adjusted.df <- left_join(final.df, candidates, by = "conflict_id") |>
    filter(is.na(termination_year) | year <= termination_year)

saveRDS(adjusted.df, "data/sequences.rds")
