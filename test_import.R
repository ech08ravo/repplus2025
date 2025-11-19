txt <- readLines('test_yurungi.rgrid', warn=FALSE, encoding='UTF-8')

# Parse constructs
c_lines <- grep("^C\\d+\t", txt, value=TRUE)
cat('Construct lines found:', length(c_lines), '\n')
if(length(c_lines) > 0) {
  cat('First construct:', c_lines[1], '\n')
  toks <- strsplit(c_lines[1], '\t')[[1]]
  cat('Tokens:', length(toks), '\n')
  cat('Last two tokens:', toks[length(toks)-1], '|', toks[length(toks)], '\n\n')
}

# Parse elements
e_lines <- grep("^E\\d+\t", txt, value=TRUE)
cat('Element lines found:', length(e_lines), '\n')
if(length(e_lines) > 0) {
  cat('First element:', e_lines[1], '\n')
  toks <- strsplit(e_lines[1], '\t')[[1]]
  toks <- toks[nzchar(toks)]
  cat('Non-empty tokens:', length(toks), '\n')
  cat('Element name (last):', toks[length(toks)], '\n')
  n_c <- 3  # we have 3 constructs
  start <- (length(toks) - 1) - n_c + 1
  end <- length(toks) - 1
  cat('Ratings indices:', start, 'to', end, '\n')
  if(start >= 1 && end >= start) {
    cat('Ratings:', toks[start:end], '\n')
  }
}
