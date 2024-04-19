#' @export
consecutive <- function(years) {
    if (length(years) == 1)
        return(F)

    x <- (lead(years) - years) == 1

    tidyr::replace_na(lead(years) - years == 1, F)
}

#' @export
episodes <- function(v) {
    idx <- rev(v) |> cumsum() |> rev()
    max(idx) - idx
}

#' @export
window <- function(x, n) {
    x <- c(rep(NA, n - 1), x)
    lapply(1:(length(x) - n + 1), function(i) x[i:(i + n - 1)])
}

#' @export
roll_mean <- function(x, n) {
    window(x, n) |> lapply(mean, na.rm = T) |> unlist()
}

#' @export
normalize <- \(x) scale(x) |> as.vector()

#' @export
polynomial <- function(df, var, n) {
    m <- poly(df[[var]], n)
    colnames(m) <- paste(var, 1:n, sep = "_")
    df[[var]] <- NULL

    bind_cols(df, m)
}

#' @export
to_idx <- function(...) {
    allEqual <- \(x) length(unique(x)) == 1

    args <- list(...)
    if (!sapply(args, length) |> allEqual())
        stop("All arguments must have the same length")

    s <- do.call(paste, args)
    lvls <- unique(s)

    factor(s, levels = lvls) |> as.integer()
}
