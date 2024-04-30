test_that("consecutive", {
    expect_identical(consecutive(c(1900:1902, 1905, 1906)), c(T, T, F, T, F))
    expect_identical(consecutive(c(1900, 1904)), c(F, F))
    expect_identical(consecutive(1), F)

    # This function is not intended for unsorted vectors, but it
    # should still work.
    expect_identical(consecutive(c(3, 1, 2)), c(F, T, F))

    expect_error(consecutive(c(1, NA)))
    expect_error(consecutive(letters))
})

test_that("group_breaks", {
    expect_identical(group_breaks(c(T, F, F, T, F)), c(1, 2, 2, 2, 3))
    expect_identical(group_breaks(c(F, F, T, T)), c(1, 1, 1, 2))
    expect_identical(group_breaks(c(T, T)), c(1, 2))
    expect_identical(group_breaks(F), 1)
    expect_identical(group_breaks(T), 1)

    expect_error(group_breaks(c(T, NA)))
    expect_error(group_breaks(1))
})

test_that("min_max", {
    expect_identical(min_max(1:10), c(0, 1:8/9, 1))
    expect_error(min_max(letters))
})

test_that("roll_mean", {
    expect_identical(roll_mean(1:5, 3), c(1, 1.5, 2, 3, 4))
    expect_identical(roll_mean(1:5, 2), c(1, 1.5, 2.5, 3.5, 4.5))
    expect_identical(roll_mean(1:5, 1), as.numeric(1:5))

    expect_error(roll_mean(c(1, NA, 3), 2, permit.na = F))
    expect_identical(roll_mean(c(1, NA, 3), 2, permit.na = T), c(1, 1, 3))

    expect_error(roll_mean(1:5, 0))
    expect_error(roll_mean(1:5, c(1, 2)))
})

test_that("to_idx", {
    expect_equal(to_idx(c(1, 1, 2, 2)), c(1L, 1L, 2L, 2L))
    expect_equal(to_idx(c(1, 1, 2, 2), c(1, 1, 1, 1)), c(1L, 1L, 2L, 2L))
    expect_equal(to_idx(c(1, 1, 2, 2), c(1, 1, 2, 3)), c(1L, 1L, 2L, 3L))
    expect_equal(to_idx(c(2, 1, 2, 1), c(3, 1, 2, 1)), c(1L, 2L, 3L, 2L))
    expect_equal(to_idx(c(1, 1, 2, 2), c(1, 2, 1, 2)), c(1L, 2L, 3L, 4L))
    expect_equal(to_idx(c(1, 1, 1), c(2, 2, 3), c(3, 2, 1)), c(1L, 2L, 3L))
    expect_equal(to_idx(c(1, 1, 2), c("a", "a", "a")), c(1L, 1L, 2L))

    expect_equal(to_idx(c("a", "b", "b", "a"), c("q", "w", "w", "w")), c(1L, 2L, 2L, 3L))
    expect_equal(to_idx(c("a", "b", "b", "a"), c("q", "w", "w", "w"), sort = T), c(1L, 3L, 3L, 2L))

    expect_error(to_idx(1:3, 1:2))
})

test_that("window", {
    expect_identical(window(1:5, 3), list(c(NA, NA, 1L), c(NA, 1L, 2L), 1:3, 2:4, 3:5))
    expect_identical(window(1:5, 2), list(c(NA, 1L), 1:2, 2:3, 3:4, 4:5))
    expect_identical(window(1:5, 1), list(1L, 2L, 3L, 4L, 5L))

    expect_identical(window(c(1, NA, 3), 2), list(c(NA, 1), c(1, NA), c(NA, 3)))
    expect_identical(window(letters[1:3], 2), list(c(NA, "a"), c("a", "b"), c("b", "c")))

    expect_error(window(1:5, 0))
    expect_error(window(1:5, -1))
    expect_error(window(1:5, c(1, 2)))
    expect_error(window(1:5, "a"))
})
