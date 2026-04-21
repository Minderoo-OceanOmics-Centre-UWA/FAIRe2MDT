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
packages <- c("readxl", "openxlsx", "dplyr", "tibble")

for (i in packages) {
  if (!require(i, character.only = TRUE)) {
    install.packages(i, dependencies = TRUE)
  }
}

library(readxl)
library(openxlsx)
library(dplyr)
library(tibble)

setwd(".")

input_files <- list.files(
  path = ".",
  pattern = "^OcOm_.*final_faire_metadata\\.xlsx$",
  full.names = TRUE
)

print("Matching files found:")
print(input_files)

# Track skipped files
skipped_files <- c()

for (current_file in input_files) {
  
  cat("\n=====================================\n")
  cat("Processing:", basename(current_file), "\n")
  cat("=====================================\n")
  
  assay <- "MiFish-U"
  
  seq_run <- regmatches(
    basename(current_file),
    regexpr("OcOm_[0-9]+", basename(current_file))
  )
  
  Project <- read_excel(current_file, sheet = "projectMetadata", col_names = TRUE)
  Samples <- read_excel(current_file, sheet = "sampleMetadata", col_names = FALSE)
  expRun <- read_excel(current_file, sheet = "experimentRunMetadata", col_names = FALSE)
  otu <- read_excel(current_file, sheet = "otuFinal", col_names = TRUE)
  taxa <- read_excel(current_file, sheet = "taxaFinal", col_names = FALSE)
  
  # OceanOmics-specific - replace project_id with OcOm code
  Project <- Project |>
    mutate(project_level = case_when(
      term_name == "project_id" ~ seq_run,
      TRUE ~ project_level
    ))
  
  ## Project
  Project <- Project %>%
    select(-(1:(which(names(Project) == "term_name") - 1))) %>%
    rename("term" = "term_name", "value" = "project_level")
  
  ## Samples
  Samples <- Samples %>%
    slice(-(1:(which(Samples[[1]] == "samp_name") - 1))) %>%
    rename_with(~ as.character(Samples[which(Samples[[1]] == "samp_name"), ])) %>%
    slice(-1) %>%
    rename("id" = "samp_name")
  
  ## expRun
  expRun <- expRun %>%
    slice(-(1:(which(expRun[[1]] == "samp_name") - 1))) %>%
    rename_with(~ as.character(expRun[which(expRun[[1]] == "samp_name"), ])) %>%
    slice(-1) %>%
    rename("id" = "samp_name")
  
  ## OTU
  if ("ASV" %in% names(otu)) {
    otu <- otu %>%
      rename(seq_id = ASV)
  } else {
    names(otu)[1] <- "seq_id"
  }
  
  dup_count <- sum(duplicated(otu$seq_id))
  
  if (dup_count > 0) {
    cat("\nWARNING: Duplicate ASV rows detected.\n")
    cat("Skipping file:", basename(current_file), "\n")
    cat("Duplicates found:", dup_count, "\n")
    
    skipped_files <- c(skipped_files, basename(current_file))
    
    next
  }
  
  otu <- otu %>%
    column_to_rownames(var = "seq_id")
  
  ## taxa
  taxa <- taxa %>%
    select(-any_of(c("...22", "...23"))) %>%
    slice(-(1:(which(taxa[[1]] == "seq_id") - 1)))
  
  taxa <- taxa %>%
    rename_with(~ as.character(taxa[which(taxa[[1]] == "seq_id"), ])) %>%
    slice(-1) %>%
    rename("id" = "seq_id")
  
  ## Format project
  if (ncol(Project) > 2) {
    assay_col <- which(Project[which(Project$term == "assay_name"), ] == assay)
    
    Project$value <- ifelse(
      is.na(Project$value),
      Project[, assay_col][[1]],
      Project$value
    )
    
    Project[which(Project$term == "assay_name"), "value"] <- assay
    Project <- Project[, c("term", "value")]
  }
  
  if (all(is.na(expRun$assay_name))) {
    expRun$assay_name <- assay
  }
  
  if (all(is.na(expRun$seq_run_id))) {
    expRun$seq_run_id <- seq_run
  }
  
  filtered_Samples <- Samples %>%
    filter(id %in% expRun$id)
  
  filtered_Samples$assay_name <- NULL
  
  Samples_expRun <- filtered_Samples %>%
    inner_join(expRun, by = "id")
  
  Project <- Project %>%
    filter(!is.na(value))
  
  Samples_expRun <- Samples_expRun %>%
    select(where(~ any(!is.na(.))))
  
  expRun <- expRun %>%
    select(where(~ any(!is.na(.))))
  
  taxa <- taxa %>%
    select(where(~ any(!is.na(.))))
  
  Samples_expRun <- Samples_expRun %>%
    select(-"assay_name")
  
  output_filename <- sub(
    "_final_faire_metadata\\.xlsx$",
    "_MDTfmt.xlsx",
    basename(current_file)
  )
  
  MDT_File <- createWorkbook()
  
  addWorksheet(MDT_File, "Study")
  writeData(MDT_File, "Study", Project)
  
  addWorksheet(MDT_File, "Samples")
  writeData(MDT_File, "Samples", Samples_expRun)
  
  addWorksheet(MDT_File, "Taxonomy")
  writeData(MDT_File, "Taxonomy", taxa)
  
  addWorksheet(MDT_File, "OTU_table")
  writeData(MDT_File, "OTU_table", otu, rowNames = TRUE)
  
  saveWorkbook(MDT_File, output_filename, overwrite = TRUE)
  
  cat("Saved output:", output_filename, "\n")
}

# Final skipped file summary
if (length(skipped_files) > 0) {
  cat("\n=====================================\n")
  cat("FILES SKIPPED DUE TO DUPLICATE DATA ROWS\n")
  cat("=====================================\n")
  
  for (f in skipped_files) {
    cat(
      "- ", f,
      " : This file has not been processed due to duplicate data rows.\n",
      "Please review and fix the source file.\n",
      sep = ""
    )
  }
} else {
  cat("\nAll files processed successfully.\n")
}