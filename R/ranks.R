#!/usr/bin/env Rscript

library(parallel)

usage <- function(...) {
    print("Usage: pp.R [--cores n] DIRECTORY")
    stop(sprintf(...), call. = F)
}

parse_args <- function(args) {
    idx <- grep("--cores", args)
    if (length(idx) == 0)
        return(args)

    if (length(args) == idx)
        usage("Missing cores argument")

    options(mc.cores = as.numeric(args[idx + 1]))
    args[-c(idx, idx+1)]
}

filter_lines <- function(f) {
    cmd <- sprintf("grep -v '^#' %s", f)
    system(cmd, intern = T)
}

process <- function(df) {
    parameters <- grep("_lt", colnames(df), value = T) |> sort()
    apply(df[, parameters], 2, sum)
}

args <- commandArgs(trailingOnly = T)
dir <- parse_args(args)

if (length(dir) != 1)
    usage("Invalid commandline argument")

if (!dir.exists(dir))
    usage("Directory %s does not exist", dir)

files <- list.files(dir, pattern = "output.csv", recursive = T, full.names = T)
if (length(files) == 0)
    usage("Could not find any output.csv files in %s", dir)

ll <- mclapply(files, \(f) filter_lines(f) |> read.csv(text = _) |> process())
ma <- do.call(rbind, ll)

write.csv(ma, "ranks.csv", row.names = F)
