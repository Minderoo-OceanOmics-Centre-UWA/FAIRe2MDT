### FAIRe2MDT.R
# Description: This script converts metabarcoding data in the FAIRe format for submission to GBIF via the Metabarcoding Data Toolkit (MDT) (https://www.gbif.org/metabarcoding).
# Script version: 1.2.0
# Last updated: 2026-04-13
# SOP Doc Number : OcOm_SOP_B227 (In OcOm_SOP_Q039-1 Document Register v1.1.0)
#
#
# ----------------------------------------------------------
# Script Version History (independent of checklist versions)
# ----------------------------------------------------------
#
# v1.2.0 - 2026-04-13
# * Added automatic batch processing for all files matching:
# * Skip files with duplicate OTU rows
# * Continue processing remaining files
# * Final summary report of skipped files
# * Added duplicate ASV detection with process stop
# * Added safe taxa column removal
# * Added dynamic output filename generation
#
# v1.1.1 - OcOm - 2025-11-6
# * Some minor changes to ensure that OceanOmics-generated FAIRe data fits
# i.e., renames project to the OcOm ID (RS19 becomes OcOm_1901)
# also removes some unnecessary filtering - as OcOm makes one Excel per assay, we don't need to remove ASVs/samples that are not included. they are all included.
#
# v1.1.0 - 2025-07-16
# * Removed the assay_name column from the sample metadata sheet, as it was duplicated in both the sample and study sheets. While the assay_name field is necessary in the FAIRe format to support multiple assays within a single dataset, the MDT format assumes each dataset corresponds to a single assay and therefore does not require this field in the sample sheet.
# * Renamed samp_name to id in the sample sheet
# * Renamed seq_id to id in the taxonomy sheet
#
# v1.0.0 - 2025-01-23
# * Initial public release of FAIRe2MDT tool
#
# Note: For projects with multiple assays or sequencing runs, users must execute this script separately for each assay or run. 
# The script generates an Excel file named <project_id>_<assay_name>_<seq_run_id>_MDTfmt.xlsx
#
# The below example input files are provided within the repository (https://github.com/FAIR-eDNA/FAIR-eDNA.github.io/tree/main/docs/examples/metabarcoding/IOT-eDNA). 
# OcOm_1901_MiFishU_asv_final_faire_metadata.xlsx
# otuFinal_IOT-eDNA_COILeray_Library_2021.xlsx
# taxaFinal_IOT-eDNA_COILeray_Library_2021.xlsx


# Install required packages if not already installed
packages <- c(
  "readxl",
  "openxlsx",
  "dplyr",
  "tibble"
)

for(i in packages){

  if(!require(i,character.only = TRUE)){
    install.packages(i,dependencies = TRUE)
  }

}

library(readxl)
library(openxlsx)
library(dplyr)
library(tibble)

###############################################################
# Load configuration
###############################################################
getwd()
source("config.R")

###############################################################
# Create output folder
###############################################################

if (!dir.exists(OUTPUT_FOLDER)) {

  dir.create(
    OUTPUT_FOLDER,
    recursive = TRUE
  )

}

###############################################################
# Find all FAIRe metadata files
###############################################################

input_files <- list.files(

  path = INPUT_FOLDER,

  pattern = FILE_PATTERN,

  recursive = RECURSIVE_SEARCH,

  full.names = TRUE

)

cat("\n=========================================\n")
cat("FAIRe2MDT Batch Processing\n")
cat("=========================================\n")

cat("\nInput folder:\n")
cat(INPUT_FOLDER,"\n")

cat("\nFiles found:",length(input_files),"\n\n")

print(input_files)

if (length(input_files) == 0) {

  stop(
    paste(
      "No files matching",
      FILE_PATTERN,
      "were found in",
      INPUT_FOLDER
    )
  )

}

###############################################################
# Skipped files
###############################################################

skipped_files <- c()

###############################################################
# Begin processing
###############################################################


for(current_file in input_files){

  tryCatch({

    cat("\n=========================================\n")
    cat("Processing: ", basename(current_file), "\n")
    cat("=========================================\n")

    #############################################################
    # Project ID
    #############################################################

    project_id <- regmatches(
      basename(current_file),
      regexpr("OcOm_[0-9]+", basename(current_file))
    )

    if(length(project_id) == 0 || project_id == ""){

      stop(
        paste(
          "Unable to determine project ID from",
          basename(current_file)
        )
      )

    }

    #############################################################
    # Assay
    #############################################################

    assay <- basename(
      dirname(
        dirname(current_file)
      )
    )

    if(assay == ""){

      stop(
        paste(
          "Unable to determine assay from",
          current_file
        )
      )

    }

    #############################################################
    # Read Excel files
    #############################################################

    Project <- read_excel(
      current_file,
      sheet = "projectMetadata",
      col_names = TRUE
    )

    Samples <- read_excel(
      current_file,
      sheet = "sampleMetadata",
      col_names = FALSE
    )

    expRun <- read_excel(
      current_file,
      sheet = "experimentRunMetadata",
      col_names = FALSE
    )

    otu <- read_excel(
      current_file,
      sheet = "otuFinal",
      col_names = TRUE
    )

    taxa <- read_excel(
      current_file,
      sheet = "taxaFinal",
      col_names = FALSE
    )

    #############################################################
# Replace project id
#############################################################

Project <- Project |>
  mutate(
    project_level = case_when(
      term_name == "project_id" ~ project_id,
      TRUE ~ project_level
    )
  )

#############################################################
# Project
#############################################################

Project <- Project %>%
  select(-(1:(which(names(Project) == "term_name") - 1))) %>%
  rename(
    term = term_name,
    value = project_level
  )

#############################################################
# Sample Metadata
#############################################################

Samples <- Samples %>%
  slice(-(1:(which(Samples[[1]] == "samp_name") - 1))) %>%
  rename_with(~ as.character(Samples[which(Samples[[1]] == "samp_name"), ])) %>%
  slice(-1) %>%
  rename(id = samp_name)

#############################################################
# Experiment Run
#############################################################

expRun <- expRun %>%
  slice(-(1:(which(expRun[[1]] == "samp_name") - 1))) %>%
  rename_with(~ as.character(expRun[which(expRun[[1]] == "samp_name"), ])) %>%
  slice(-1) %>%
  rename(id = samp_name)

#############################################################
# OTU
#############################################################

if ("ASV" %in% names(otu)) {

  otu <- otu %>%
    rename(seq_id = ASV)

} else {

  names(otu)[1] <- "seq_id"

}

#############################################################
# Duplicate ASV Detection
#############################################################

dup_count <- sum(duplicated(otu$seq_id))

if (dup_count > 0) {

  stop(
    paste0(
      basename(current_file),
      ": ",
      dup_count,
      " duplicate ASV rows detected."
    )
  )

}

otu <- otu %>%
  column_to_rownames(var = "seq_id")

#############################################################
# Taxonomy
#############################################################

taxa <- taxa %>%
  select(-any_of(c("...22", "...23"))) %>%
  slice(-(1:(which(taxa[[1]] == "seq_id") - 1)))

taxa <- taxa %>%
  rename_with(~ as.character(taxa[which(taxa[[1]] == "seq_id"), ])) %>%
  slice(-1) %>%
  rename(id = seq_id)

#############################################################
# Format Study
#############################################################

if (ncol(Project) > 2) {

  assay_col <- which(
    Project[
      which(Project$term == "assay_name"),
    ] == assay
  )

  Project$value <- ifelse(
    is.na(Project$value),
    Project[, assay_col][[1]],
    Project$value
  )

  Project[
    which(Project$term == "assay_name"),
    "value"
  ] <- assay

  Project <- Project[, c("term", "value")]

}

#############################################################
# Validate assay_name
#############################################################

if (!"assay_name" %in% names(expRun)) {

  stop(
    paste(
      "Missing required column 'assay_name' in",
      basename(current_file)
    )
  )

}

if (all(is.na(expRun$assay_name))) {

  stop(
    paste(
      "assay_name is missing for all samples in",
      basename(current_file)
    )
  )

}

#############################################################
# Validate seq_run_id
#############################################################

if (!"seq_run_id" %in% names(expRun)) {

  stop(
    paste(
      "Missing required column 'seq_run_id' in",
      basename(current_file)
    )
  )

}

if (all(is.na(expRun$seq_run_id))) {

  stop(
    paste(
      "seq_run_id is missing for all samples in",
      basename(current_file)
    )
  )

}

#############################################################
# Merge sample metadata
#############################################################

filtered_Samples <- Samples %>%
  filter(id %in% expRun$id)

filtered_Samples <- filtered_Samples %>%
  select(-any_of("assay_name"))

Samples_expRun <- filtered_Samples %>%
  inner_join(expRun, by = "id")

#############################################################
# Remove empty columns
#############################################################

Project <- Project %>%
  filter(!is.na(value))

Samples_expRun <- Samples_expRun %>%
  select(where(~ any(!is.na(.))))

taxa <- taxa %>%
  select(where(~ any(!is.na(.))))

Samples_expRun <- Samples_expRun %>%
  select(-any_of("assay_name"))

#############################################################
# Create output folder
#############################################################

project_output <- file.path(
  OUTPUT_FOLDER,
  project_id
)

if (!dir.exists(project_output)) {

  dir.create(
    project_output,
    recursive = TRUE
  )

}

#############################################################
# Output filename
#############################################################

output_filename <- file.path(
  project_output,
  sub(
    "_final_faire_metadata\\.xlsx$",
    "_MDTfmt.xlsx",
    basename(current_file)
  )
)

#############################################################
# Create workbook
#############################################################

MDT_File <- createWorkbook()

addWorksheet(MDT_File, "Study")
writeData(MDT_File, "Study", Project)

addWorksheet(MDT_File, "Samples")
writeData(MDT_File, "Samples", Samples_expRun)

addWorksheet(MDT_File, "Taxonomy")
writeData(MDT_File, "Taxonomy", taxa)

addWorksheet(MDT_File, "OTU_table")
writeData(
  MDT_File,
  "OTU_table",
  otu,
  rowNames = TRUE
)

#############################################################
# Save workbook
#############################################################

saveWorkbook(
  MDT_File,
  output_filename,
  overwrite = OVERWRITE_OUTPUT
)

cat("Saved: ", output_filename, "\n")



  }, error = function(e){

    cat("\n----------------------------------------\n")
    cat("ERROR PROCESSING FILE\n")
    cat("----------------------------------------\n")
    cat("File   : ", basename(current_file), "\n", sep = "")
    cat("Reason : ", conditionMessage(e), "\n\n", sep = "")

    skipped_files <<- c(
      skipped_files,
      paste(
        basename(current_file),
        "-",
        conditionMessage(e)
      )
    )

  })

}

#############################################################
# Processing Summary
#############################################################

cat("\n")
cat("=============================================\n")
cat("         BATCH PROCESSING COMPLETE\n")
cat("=============================================\n")

cat("Input Folder:\n")
cat(INPUT_FOLDER,"\n\n")

cat("Output Folder:\n")
cat(OUTPUT_FOLDER,"\n\n")

cat("Files Found : ",length(input_files),"\n")
cat("Files Skipped : ",length(skipped_files),"\n")
cat("Files Processed : ",length(input_files)-length(skipped_files),"\n\n")

#############################################################
# Skipped Files
#############################################################

if(length(skipped_files)>0){

  cat("---------------------------------------------\n")
  cat("Skipped Files\n")
  cat("---------------------------------------------\n")

  for(f in skipped_files){

    cat("• ",f,"\n",sep="")

  }

}

#############################################################
# Write Processing Report
#############################################################

report_file <- file.path(

  OUTPUT_FOLDER,

  "Processing_Report.txt"

)

sink(report_file)

cat("FAIRe2MDT Batch Processing Report\n")
cat("---------------------------------\n\n")

cat("Date: ",Sys.time(),"\n\n")

cat("Input Folder:\n")
cat(INPUT_FOLDER,"\n\n")

cat("Output Folder:\n")
cat(OUTPUT_FOLDER,"\n\n")

cat("Files Found: ",length(input_files),"\n")
cat("Files Processed: ",length(input_files)-length(skipped_files),"\n")
cat("Files Skipped: ",length(skipped_files),"\n\n")

if(length(skipped_files)>0){

  cat("Skipped Files\n")
  cat("----------------------------\n")

  for(f in skipped_files){

    cat(f,"\n")

  }

}else{

  cat("No skipped files.\n")

}

sink()

cat("\n")
cat("Processing report saved to:\n")
cat(report_file,"\n")

cat("\nAll processing completed successfully.\n")  