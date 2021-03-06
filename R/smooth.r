#' Smooth a condensed data frame.
#'
#' @param x a condensed summary
#' @param h numeric vector of bandwidths, one for each grouping variable in
#'   \code{x}
#' @param var variable to smooth
#' @param grid a data frame with the grouping colums as x.  In order for the
#'   factored version of \code{smooth_nd} to work, this grid must be a superset
#'   of \code{x}.
#' @param type type of smoothing to use.  Current options are \code{"mean"},
#'   a kernel weighted mean; \code{"regression"}, a kernel weighted local
#'   regression; and \code{"robust_regression"}, robust kernel weighted local
#'   regression in the style of \code{\link{loess}}.  Unique prefixes are also
#'   acceptable.
#' @param factor if \code{TRUE} compute the n-dimensional smooth by a sequence
#'   of 1d smoothes. For \code{type = "mean"} the results are always the same
#    as \code{FALSE}; for \code{type = "regress"} they will be equal if the
#'   grid values are uncorrelated (e.g. the grid is complete at every location);
#'   and is very approximate for \code{type = "robust"}.
#' @export
#' @examples
#' x <- runif(1e5)
#' xsum <- condense(bin(x, 1 / 100))
#' xsmu1 <- smooth(xsum, 5 / 100)
#' xsmu2 <- smooth(xsum, 5 / 100, factor = FALSE)
#'
#' # More challenging distribution
#' x <- rchallenge(1e4)
#' xsum <- condense(bin(x, 0.1))
#' xsmu <- smooth(xsum, 1)
#'
#' plot(xsum$x, xsum$.count, type = "l")
#' lines(xsmu$x, xsmu$.count, col = "red")
#'
#' xsmu2 <- smooth(xsum, 1, type = "regress")
#' plot(xsmu$x, xsmu$.count, type = "l", xlim = c(0, 50))
#' lines(xsmu2$x, xsmu2$.count, col = "red")
#' # Note difference in tails
smooth <- function(x, h, var = summary_vars(x)[1], grid = NULL, type = "mean",
                   factor = TRUE) {
  stopifnot(is.condensed(x))
  stopifnot(is.numeric(h), all(h > 0))
  type <- match.arg(type, c("mean", "regression", "robust_regression"))

  if (type != "mean" && !factor) {
    stop("Only factored approximations available for types other than mean",
      call. = FALSE)
  }

  grid_in <- as.matrix(x[group_vars(x)])
  grid_out <- grid %||% grid_in
  stopifnot(is.matrix(grid_out), is.numeric(grid_out),
    ncol(grid_out) == ncol(grid_in), nrow(grid_out) > 0)

  z <- x[[var]]
  w <- if (var != ".count" && x %contains% ".count") x$.count else numeric()

  if (factor) {
    for(i in 1:ncol(grid_in)) {
      # smooth_nd_1 is a C++ function, so var is 0 indexed
      z <- smooth_nd_1(grid_in, z, w, grid_out, var = i - 1, h = h[i],
        type = type)
    }
  } else {
    z <- smooth_nd(grid_in, z, w, grid_out, h)
  }

  out <- data.frame(grid_out)
  out[[var]] <- z
  structure(out, class = c("condensed", class(out)))
}

complete_grid <- function(df) {
  stopifnot(is.data.frame(df))

  breaks <- function(width, origin, nbins) {
    origin + width * seq.int(nbins)
  }

  cols <- lapply(df, function(x) do.call(breaks, attributes(x)))
  expand.grid(cols, KEEP.OUT.ATTRS = FALSE)
}
