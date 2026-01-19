# Triadic Elicitation Functions for RepGrid
# Implements Kelly's Repertory Grid triadic comparison method

#' Generate all possible triads from elements
#' @param elements Character vector of element names
#' @return Data frame with columns triad_id, elem1, elem2, elem3
generate_triads <- function(elements) {
  n <- length(elements)
  if (n < 3) {
    return(data.frame(
      triad_id = integer(),
      elem1 = character(),
      elem2 = character(),
      elem3 = character(),
      stringsAsFactors = FALSE
    ))
  }

  # Generate all combinations of 3 elements
  triads <- combn(elements, 3, simplify = FALSE)

  # Convert to data frame
  triad_df <- data.frame(
    triad_id = seq_along(triads),
    elem1 = sapply(triads, `[`, 1),
    elem2 = sapply(triads, `[`, 2),
    elem3 = sapply(triads, `[`, 3),
    stringsAsFactors = FALSE
  )

  return(triad_df)
}

#' Select next triad for elicitation
#' @param triads Data frame of all triads
#' @param completed_triads Integer vector of completed triad IDs
#' @return Single row data frame of next triad, or NULL if all complete
get_next_triad <- function(triads, completed_triads = integer()) {
  if (nrow(triads) == 0) return(NULL)

  remaining <- triads[!triads$triad_id %in% completed_triads, , drop = FALSE]

  if (nrow(remaining) == 0) return(NULL)

  return(remaining[1, , drop = FALSE])
}

#' Calculate elicitation progress
#' @param total_triads Total number of triads
#' @param completed_triads Number of completed triads
#' @return List with progress percentage and status message
get_elicitation_progress <- function(total_triads, completed_triads) {
  if (total_triads == 0) {
    return(list(
      percent = 0,
      message = "Add at least 3 elements to begin elicitation"
    ))
  }

  percent <- round((completed_triads / total_triads) * 100)

  if (completed_triads == 0) {
    message <- sprintf("Ready to begin: 0/%d triads completed", total_triads)
  } else if (completed_triads == total_triads) {
    message <- sprintf("Complete! All %d triads elicited", total_triads)
  } else {
    message <- sprintf("In progress: %d/%d triads completed (%d%%)",
                      completed_triads, total_triads, percent)
  }

  return(list(percent = percent, message = message))
}

#' Validate construct poles
#' @param left_pole Left pole label
#' @param right_pole Right pole label
#' @return List with valid (TRUE/FALSE) and message
validate_construct <- function(left_pole, right_pole) {
  if (is.null(left_pole) || left_pole == "" || is.na(left_pole)) {
    return(list(valid = FALSE, message = "Please enter a label for the similarity pole"))
  }

  if (is.null(right_pole) || right_pole == "" || is.na(right_pole)) {
    return(list(valid = FALSE, message = "Please enter a label for the contrast pole"))
  }

  if (left_pole == right_pole) {
    return(list(valid = FALSE, message = "Poles must be different"))
  }

  return(list(valid = TRUE, message = ""))
}

#' Check if all elements have been rated on a construct
#' @param elements Character vector of element names
#' @param ratings Data frame of ratings
#' @param construct_label Construct label to check
#' @return TRUE if all rated, FALSE otherwise
all_elements_rated <- function(elements, ratings, construct_label) {
  if (nrow(ratings) == 0) return(FALSE)

  rated_elements <- ratings$element[ratings$construct == construct_label]

  return(all(elements %in% rated_elements))
}
