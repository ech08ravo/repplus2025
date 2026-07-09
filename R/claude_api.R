# Claude API Integration for RepPlus
# Requires ANTHROPIC_API_KEY environment variable

library(httr2)

# Load all documentation files into memory for RAG
load_repplus_docs <- function() {
  docs_dir <- file.path(getwd(), "RepPlusDocs")
  txt_files <- list.files(docs_dir, pattern = "\\.txt$", full.names = TRUE)

  docs <- list()
  for (f in txt_files) {
    doc_name <- tools::file_path_sans_ext(basename(f))
    docs[[doc_name]] <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }

  docs
}

# Find relevant documentation sections based on visualization type
get_relevant_docs <- function(docs, viz_type) {
  # Map visualization types to relevant doc sections
  relevant_keywords <- list(
    "PCA Biplot" = c("PrinGrid", "biplot", "principal component", "spatial"),
    "Crossplot" = c("Crossplot", "orthogonal axes", "plotting elements"),
    "Synopsis" = c("Synopsis", "Histogram", "scree plot", "distribution"),
    "Heatmap" = c("Display", "matrix", "ratings"),
    "Element Dendrogram" = c("Focus", "cluster", "hierarchical", "element", "similarity"),
    "Construct Dendrogram" = c("Focus", "cluster", "hierarchical", "construct", "similarity"),
    "Focus Cluster" = c("Focus", "cluster", "hierarchical", "sorting", "similarity", "Shaw"),
    "Statistics" = c("statistics", "mean", "variance", "standard deviation")
  )

  keywords <- relevant_keywords[[viz_type]]
  if (is.null(keywords)) keywords <- c(viz_type)

  # Search through docs for relevant sections
  relevant_sections <- c()

  for (doc_name in names(docs)) {
    doc_text <- docs[[doc_name]]

    # Check if any keyword appears in this doc
    for (kw in keywords) {
      if (grepl(kw, doc_text, ignore.case = TRUE)) {
        # Extract a relevant chunk (up to 2000 chars around the keyword)
        matches <- gregexpr(kw, doc_text, ignore.case = TRUE)[[1]]
        if (matches[1] != -1) {
          for (pos in matches[1:min(2, length(matches))]) {
            start <- max(1, pos - 500)
            end <- min(nchar(doc_text), pos + 1500)
            chunk <- substr(doc_text, start, end)
            relevant_sections <- c(relevant_sections, paste0("[From ", doc_name, "]\n", chunk))
          }
        }
        break  # Only one chunk per doc
      }
    }
  }

  # Limit total context size
  combined <- paste(relevant_sections, collapse = "\n\n---\n\n")
  if (nchar(combined) > 8000) {
    combined <- substr(combined, 1, 8000)
  }

  combined
}

# Check if API key is configured
has_api_key <- function() {
  api_key <- Sys.getenv("ANTHROPIC_API_KEY")
  return(api_key != "")
}

# Generate context for copy-to-clipboard (when no API key)
generate_claude_context <- function(viz_type, question, grid_summary, extra_context = "") {
  docs <- tryCatch(load_repplus_docs(), error = function(e) list())
  doc_context <- get_relevant_docs(docs, viz_type)

  paste0(
    "I'm using RepPlus to analyze a repertory grid and I'm viewing the ", viz_type, " visualization.\n\n",
    "=== MY GRID DATA ===\n", grid_summary, "\n\n",
    extra_context,
    "=== RELEVANT REPPLUS DOCUMENTATION ===\n", doc_context, "\n\n",
    "=== MY QUESTION ===\n", question, "\n\n",
    "Please help me understand this in the context of Personal Construct Theory and Repertory Grid analysis."
  )
}

# Call Claude API
call_claude_api <- function(prompt, system_prompt = NULL) {
  api_key <- Sys.getenv("ANTHROPIC_API_KEY")

  if (api_key == "") {
    return(list(
      success = FALSE,
      error = "NO_API_KEY",
      message = "No API key configured. Use the 'Copy to Clipboard' button to paste into Claude.ai instead."
    ))
  }

  messages <- list(
    list(role = "user", content = prompt)
  )

  body <- list(
    model = "claude-sonnet-4-6",
    max_tokens = 2000,
    messages = messages
  )

  if (!is.null(system_prompt)) {
    body$system <- system_prompt
  }

  tryCatch({
    resp <- request("https://api.anthropic.com/v1/messages") |>
      req_headers(
        "x-api-key" = api_key,
        "anthropic-version" = "2023-06-01",
        "content-type" = "application/json"
      ) |>
      req_body_json(body) |>
      req_timeout(60) |>
      req_perform()

    result <- resp_body_json(resp)

    if (!is.null(result$content) && length(result$content) > 0) {
      return(list(
        success = TRUE,
        response = result$content[[1]]$text
      ))
    } else {
      return(list(
        success = FALSE,
        error = "Empty response from Claude API"
      ))
    }
  }, error = function(e) {
    return(list(
      success = FALSE,
      error = "API request failed. Please check your API key and try again."
    ))
  })
}

# Main function to ask Claude about RepGrid data
ask_claude_about_grid <- function(viz_type, question, grid_summary, docs = NULL, extra_context = "") {
  # Load docs if not provided
  if (is.null(docs)) {
    docs <- tryCatch(load_repplus_docs(), error = function(e) list())
  }

  # Get relevant documentation
  doc_context <- get_relevant_docs(docs, viz_type)

  # Build system prompt with documentation context
  system_prompt <- paste0(
    "You are an expert in Personal Construct Theory and Repertory Grid analysis. ",
    "You are helping a user understand their RepGrid data using the RepPlus application.\n\n",
    "RELEVANT DOCUMENTATION FROM REPPLUS:\n",
    doc_context, "\n\n",
    "Use this documentation to provide accurate, contextual answers about RepGrid analysis. ",
    "Be specific about what patterns mean in the context of Personal Construct Theory. ",
    "If the user asks about specific elements or constructs, reference their actual data."
  )

  # Build user prompt
  user_prompt <- paste0(
    "I'm analyzing a repertory grid and viewing the ", viz_type, " visualization.\n\n",
    "MY GRID DATA:\n", grid_summary, "\n\n",
    extra_context,
    "MY QUESTION: ", question
  )

  call_claude_api(user_prompt, system_prompt)
}

#' Generate structured FOCUS data for FOCI interpretation
#' @param focus_result Output from focus_cluster()
#' @param element_names Original element names
#' @param construct_labels Original construct labels ("left - right")
#' @param cutoff Similarity cutoff for reporting matches
#' @return Character string with structured data for Claude prompt
generate_focus_interpretation_context <- function(focus_result, element_names, construct_labels,
                                                    cutoff = 80) {
  elem_sim <- focus_result$element_similarities
  const_sim <- focus_result$construct_similarities

  lines <- character()
  lines <- c(lines, "=== FOCUS CLUSTER ANALYSIS DATA ===\n")

  # Element clusters
  lines <- c(lines, "ELEMENT SIMILARITY PAIRS (above cutoff):")
  for (i in 1:(nrow(elem_sim) - 1)) {
    for (j in (i + 1):ncol(elem_sim)) {
      if (elem_sim[i, j] >= cutoff) {
        lines <- c(lines, sprintf("  %s <-> %s: %.1f%% match",
                                  element_names[i], element_names[j], elem_sim[i, j]))
      }
    }
  }

  # Construct clusters
  lines <- c(lines, "\nCONSTRUCT SIMILARITY PAIRS (above cutoff):")
  for (i in 1:(nrow(const_sim) - 1)) {
    for (j in (i + 1):ncol(const_sim)) {
      if (const_sim[i, j] >= cutoff) {
        lines <- c(lines, sprintf("  %s <-> %s: %.1f%% match",
                                  construct_labels[i], construct_labels[j], const_sim[i, j]))
      }
    }
  }

  # Dendrogram structure
  lines <- c(lines, "\nELEMENT CLUSTER ORDER (from Focus sorting):")
  lines <- c(lines, paste("  ", paste(focus_result$sorted_elements, collapse = " | ")))

  lines <- c(lines, "\nCONSTRUCT CLUSTER ORDER (from Focus sorting):")
  lines <- c(lines, paste("  ", paste(focus_result$sorted_constructs, collapse = " | ")))

  # Merge heights indicate cluster tightness
  lines <- c(lines, "\nELEMENT DENDROGRAM MERGE HEIGHTS (lower = more similar):")
  eh <- focus_result$element_hclust$height
  lines <- c(lines, paste("  ", paste(round(eh, 1), collapse = ", ")))

  lines <- c(lines, "\nCONSTRUCT DENDROGRAM MERGE HEIGHTS:")
  ch <- focus_result$construct_hclust$height
  lines <- c(lines, paste("  ", paste(round(ch, 1), collapse = ", ")))

  # Sorted matrix
  lines <- c(lines, "\nSORTED RATING MATRIX:")
  mat <- focus_result$sorted_matrix
  header <- paste("", paste(focus_result$sorted_constructs, collapse = "\t"))
  lines <- c(lines, header)
  for (i in seq_len(nrow(mat))) {
    row_str <- paste(focus_result$sorted_elements[i], "\t",
                     paste(round(mat[i, ], 0), collapse = "\t"))
    lines <- c(lines, row_str)
  }

  paste(lines, collapse = "\n")
}
