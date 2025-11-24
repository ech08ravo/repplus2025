# Convert Contact Lens CSV data to .rgrid format for RepPlusApp
# This script reads the categorical contact lens data and converts it to
# numeric ratings on a 1-7 scale suitable for repertory grid analysis

library(uuid)

# Read the CSV data
data <- read.csv("dataExamples/contact_lens_data.csv", stringsAsFactors = FALSE)

# Define the conversion mappings
# Each categorical value is mapped to a numeric rating (1-7 scale)

convert_age <- function(x) {
  ifelse(x == "young", 1,
         ifelse(x == "pre-presbyopic", 4, 7))
}

convert_prescription <- function(x) {
  ifelse(x == "myope", 1, 7)
}

convert_astigmatism <- function(x) {
  ifelse(x == "no", 1, 7)
}

convert_tear <- function(x) {
  ifelse(x == "reduced", 1, 7)
}

# Apply conversions
age_ratings <- convert_age(data$age)
prescription_ratings <- convert_prescription(data$spectacle_prescription)
astigmatism_ratings <- convert_astigmatism(data$astigmatism)
tear_ratings <- convert_tear(data$tear_production)

# Combine into scores matrix (elements × constructs)
# Rows = elements (24 cases), Columns = constructs (4 attributes)
scores_mat <- cbind(
  age_ratings,
  prescription_ratings,
  astigmatism_ratings,
  tear_ratings
)

# Define constructs (bipolar)
constructs <- data.frame(
  left = c("young", "myope", "no", "reduced"),
  right = c("presbyopic", "hypermetrope", "yes", "normal"),
  stringsAsFactors = FALSE
)

# Define elements
elements <- paste0("Case ", data$case_id)

# Number of elements and constructs
n_e <- nrow(scores_mat)
n_c <- ncol(scores_mat)

# Create .rgrid file
output_file <- "dataExamples/contact_lens.rgrid"
con <- file(output_file, open = "w", encoding = "UTF-8")

# Write header
# Format: [empty] Grid nE nC nR Title [empty] 1 Date Time local RepVersion GridType
now <- Sys.time()
hdr <- paste(
  "", "Grid", n_e, n_c, n_e * n_c, "ContactLensDataset", "", "1",
  format(Sys.Date(), "%d-%b-%Y"), format(now, "%H:%M"),
  "local", "Rep IV 2.00", "RepGrid",
  sep = "\t"
)
writeLines(hdr, con)

# Write constructs
# Format: C[id] R 100 0 1 1 5 [left_pole] [right_pole] [empty]
for (i in seq_len(n_c)) {
  L <- constructs$left[i]
  R <- constructs$right[i]
  writeLines(paste0(
    "C", i - 1, "\tR\t100\t0\t1\t1\t5\t", L, "\t", R, "\t"
  ), con)
}

# Write elements
# Format: E[id] 100 0 1 1 4 [score1] [score2] ... [scoreN] [element_name]
for (e in seq_len(n_e)) {
  row <- paste0(
    "E", e - 1, "\t100\t0\t1\t1\t4\t",
    paste(scores_mat[e, ], collapse = "\t"), "\t",
    elements[e]
  )
  writeLines(row, con)
}

# Write metadata
writeLines(paste("_UID", uuid::UUIDgenerate(), sep = "\t"), con)
writeLines(paste("_Date", format(Sys.Date(), "%d-%b-%Y"), sep = "\t"), con)
writeLines(paste("_Time", format(now, "%H:%M"), sep = "\t"), con)

close(con)

cat("Conversion complete!\n")
cat("Output file:", output_file, "\n")
cat("Elements:", n_e, "\n")
cat("Constructs:", n_c, "\n")
cat("Total ratings:", n_e * n_c, "\n\n")

cat("Conversion mapping used:\n")
cat("  age: young=1, pre-presbyopic=4, presbyopic=7\n")
cat("  spectacle_prescription: myope=1, hypermetrope=7\n")
cat("  astigmatism: no=1, yes=7\n")
cat("  tear_production: reduced=1, normal=7\n\n")

cat("To load in RepPlusApp:\n")
cat("1. Run shiny::runApp()\n")
cat("2. Click 'Choose File' under Import .rgrid\n")
cat("3. Select 'dataExamples/contact_lens.rgrid'\n")
cat("4. Click 'Load Grid'\n")
