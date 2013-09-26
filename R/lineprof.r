#' Line profiling.
#' 
#' @export
#' @examples
#' 
#' source(find_demo("read-delim.r"))
#' source(find_demo("read-table.r"))
#' wine <- find_demo("wine.csv")
#' 
#' lineprof(read.table2(wine, sep = ","), torture = TRUE)
#' lineprof(read_delim(wine), torture = TRUE)
#' @useDynLib lineprof
lineprof <- function(code, interval = 0.01, torture = FALSE) {
  path <- profile(code, interval, torture)
  on.exit(unlink(path))
  
  parse_prof(path)
}

is.lineprof <- function(x) inherits(x, "lineprof")

#' @S3method [ lineprof
"[.lineprof" <- function(x, ...) {
  out <- NextMethod()
  class(out) <- c("lineprof", "data.frame")
  out
}

#' @S3method format lineprof
format.lineprof <- function(x, digits = 3, depth = 3, ...) {
  max_depth <- max(vapply(x$ref, nrow, integer(1)))
  if (max_depth > depth) {
    message("Reducing depth to ", depth, " (from ", max_depth, ")")
    x <- reduce_depth(x, depth)
  }
  
  x$alloc <- round(x$alloc, digits)
  x$release <- round(x$release, digits)
  
  ref <- vapply(x$ref, function(x) paste(x$f, collapse = "/"), character(1))
  x$call <- format(ref, align = "left")
  x$ref <- NULL
  
  class(x) <- "data.frame"
  x
}

#' @S3method print lineprof
print.lineprof <- function(x, digits = 3, depth = 3,...) {
  print(format(x, digits = digits, depth = depth, ...))
}

paths <- function(x) {
  vapply(x$ref, FUN.VALUE = character(1), function(x) {
    if (length(x$path) == 0) NA_character_ else x$path[[1]]
  })
}

reduce_depth <- function(prof, i = 2) {
  prof$ref <- lapply(prof$ref, function(x) {
    x[seq_len(min(i, nrow(x))), , drop = FALSE]
  })
  collapse(prof)
}

collapse <- function(prof) {
  index <- c(FALSE, unlist(Map(identical, prof$ref[-1], prof$ref[-nrow(prof)])))
  group <- cumsum(!index)
  
  collapsed <- rowsum(prof[c("time", "alloc", "release", "dups")], group, 
    na.rm = TRUE, reorder = FALSE)
  collapsed$ref <- prof$ref[!duplicated(group)]
  
  class(collapsed) <- c("lineprof", "data.frame")
  collapsed
}
