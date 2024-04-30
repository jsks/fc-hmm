#' Find consective elements
#'
#' Given a numeric vector, returns a logical vector indicating whether
#' each vector element is consecutive with the next element.
#'
#' This is used to as part of the process to identify if a termination
#' in the form of a coded military victory or peace agreement is
#' followed by continued violence in the next year.
#'
#' Note, the last element in the vector is always considered to be
#' non-consecutive. Also, `consecutive` does not sort the argument
#' vector.
#'
#' @param x Numeric vector
#'
#' @return Logical vector indicating non-consecutive breaks
#'
#' @examples
#' consecutive(c(1900, 1901, 1903, 1904))
#'
#' @export
consecutive <- function(x) UseMethod("consecutive")

#' @export
consecutive.numeric <- function(x) {
    if (anyNA(x))
        stop("NA values found in input vector")

    if (length(x) == 1)
        return(F)

    v <- (dplyr::lead(x) - x) == 1
    ifelse(is.na(v), F, v)
}

#' Grouping indices by boolean breaks
#'
#' Given a logical vector, return a vector of the same length with the
#' indices for each group of of consecutive FALSE values terminated by
#' the first TRUE value.
#'
#' This is used to identify conflict episodes given a vector
#' indicating whether a conflict-year has experienced a termination.
#'
#' @param x Logical vector indicating breaks
#'
#' @return Integer vector of grouping indices
#'
#' @examples
#' group_breaks(c(TRUE, FALSE, FALSE, TRUE, FALSE))
#'
#' @export
group_breaks <- function(x) UseMethod("group_breaks")

#' @export
group_breaks.logical <- function(x) {
    if (anyNA(x))
        stop("Unexpected NA values in input")

    idx <- rev(x) |> cumsum() |> rev()
    1 + max(idx) - idx
}

#' Min-max normalization
#'
#' This function applies min-max normalization to constrain a numeric
#' vector between [0, 1].
#'
#' @param x Numeric vector to re-scale
#'
#' @details The transformation is defined as \eqn{\frac{(x - min(x))}{(max(x) - min(x))}}
#' @return Re-scaled numeric vector
#'
#' @seealso [normalize()]
#' @export
min_max <- \(x) (x - min(x)) / (max(x) - min(x))

#' Standard score normalization
#'
#' Convenience wrapper to `scale` that returns a numeric vector after
#' applying standard score normalization.
#'
#' @param x Numeric vector to re-scale
#'
#' @details The transformation is defined as \eqn{\frac{(x - \text{mean}(x))}{\text{sd}(x)}}
#' @return Re-scaled numeric vector
#'
#' @seealso [min_max()], [scale()]
#' @export
normalize <- \(x) scale(x) |> as.vector()

#' Polynomial transformation
#'
#' Convenience wrapper to the `poly` function that adds `n` polynomial
#' terms to a data frame for variable `var`. Note, this function does
#' not use non-standard evaluation so the variable name must be
#' quoted.
#'
#' @param df Data frame
#' @param var Character name of the variable to transform
#' @param n Integer number of polynomial terms
#'
#' @return A data frame with `n` additional columns.
#'
#' @export
polynomial <- function(df, var, n) UseMethod("polynomial")

#' @export
polynomial.data.frame <- function(df, var, n) {
    if (length(var) != 1)
        stop("Variable name must be a single string")

    if (!var %in% names(df))
        stop("Variable not found in data frame")

    m <- stats::poly(df[[var]], n)
    colnames(m) <- paste(var, 1:n, sep = "_")
    df[[var]] <- NULL

    dplyr::bind_cols(df, m)
}

#' Rolling mean
#'
#' Calculate the left-inclusive rolling mean with a `n` size window.
#'
#' @param x Numeric vector for rolling mean
#' @param n Window size
#' @param permit.na Logical indicating whether to permit NA values in `x`
#'
#' @examples
#' roll_mean(1:10, 3)
#'
#' @seealso [window()]
#' @export
roll_mean <- function(x, n, permit.na = T) UseMethod("roll_mean")

#' @export
roll_mean.numeric <- function(x, n, permit.na = T) {
    if (isFALSE(permit.na) & anyNA(x))
        stop("Unexpected NA values found in input")

    window(x, n) |> lapply(mean, na.rm = T) |> unlist()
}

#' Unique integer indices
#'
#' Create a unique index for the combination of vector arguments.
#'
#' This is used to create an index variable based on `conflict_id` and
#' `episode_id` in order to uniquely identify years within a specific
#' conflict-episode.
#'
#' @param ... Input vectors of the same length
#' @param sort Logical, whether to sort unique levels prior to indexing
#'
#' @return Integer vector of the same length as vector arguments.
#'
#' @examples
#' to_idx(c(1, 1, 2, 2), c(1, 2, 1, 2))
#'
#' @export
to_idx <- function(..., sort = F) {
    allEqual <- \(x) length(unique(x)) == 1

    args <- list(...)
    if (!sapply(args, length) |> allEqual())
        stop("All arguments must have the same length")

    s <- do.call(paste, args)
    lvls <- unique(s)
    if (isTRUE(sort))
        lvls <- sort(lvls)

    factor(s, levels = lvls) |> as.integer()
}

#' Windowing function
#'
#' Returns the list of moving windows of size `n` for a vector. For
#' each element in `x`, a window is defined as a vector of the
#' previous `(n-1)` elements and the current element.
#'
#' When there are fewer than (n-1) elements to the left of the current
#' element in `x`, the window is padded with `NA`.
#'
#' @param x Vector
#' @param n Window size
#'
#' @return A list of size `length(x)` where each element is an `n`
#'     length vector.
#'
#' @examples
#' window(1:10, 5)
#'
#' @export
window <- function(x, n) {
    if (!is.numeric(n) | length(n) != 1 | n < 1)
        stop("Expected a single positive window size")

    x <- c(rep(NA, n - 1), x)
    lapply(1:(length(x) - n + 1), function(i) x[i:(i + n - 1)])
}
