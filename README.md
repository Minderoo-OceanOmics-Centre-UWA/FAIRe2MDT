# FAIRe2MDT

FAIRe2MDT is an R-based conversion tool that transforms eDNA metabarcoding datasets from the FAIRe metadata format into the Metabarcoding Data Toolkit (MDT) format required for publication through the Global Biodiversity Information Facility (GBIF).

The tool automates metadata restructuring, data validation, taxonomy formatting, and OTU table preparation, reducing the manual effort required for MDT submissions and improving data consistency across projects.

Learn more about MDT:
https://www.gbif.org/metabarcoding

---

## Features

* Converts FAIRe-formatted datasets into MDT-compliant Excel workbooks
* Supports batch processing of multiple OceanOmics project files
* Automatically reformats project, sample, sequencing, taxonomy, and OTU data
* Detects duplicate ASV records and prevents invalid outputs
* Removes empty and unnecessary columns during processing
* Generates MDT-ready outputs with standardized sheet structures
* Produces processing summaries and reports skipped files

---

## Input Requirements

The script searches the working directory for files matching:

`OcOm_*final_faire_metadata.xlsx`

Required worksheets:

* `projectMetadata`
* `sampleMetadata`
* `experimentRunMetadata`
* `otuFinal`
* `taxaFinal`

---

## Output

For each valid input file, the script generates an MDT-formatted workbook:

`<project_id>_<assay_name>_<seq_run_id>_MDTfmt.xlsx`

Output worksheets:

* Study
* Samples
* Taxonomy
* OTU_table

---

## Changelog

All notable changes to FAIRe2MDT are documented below.

Older versions are archived in the `previous_versions` directory for reproducibility.

### [v1.2.0] - 2026-04-13 (Anushka S. Dissanayaka M.)

* Added automatic batch processing for all matching FAIRe metadata files
* Added duplicate ASV detection and validation checks
* Added automatic skipping of files containing duplicate OTU records
* Added processing summary for skipped files
* Added safe removal of unexpected taxonomy columns
* Added dynamic MDT output filename generation

### [v1.1.1] - 2025-11-06

* Added OceanOmics-specific project identifier handling
* Replaced legacy project identifiers with OcOm project codes
* Simplified filtering logic for OceanOmics workflows where each workbook contains a single assay

### [v1.1.0] - 2025-07-16

* Removed the `assay_name` column from the sample metadata sheet
* Renamed `samp_name` to `id` in the sample sheet
* Renamed `seq_id` to `id` in the taxonomy sheet

### [v1.0.0] - 2025-01-23

* Initial public release of the FAIRe2MDT conversion tool

---

## Versioning

The FAIRe2MDT tool is versioned independently from the FAIRe metadata checklist.

FAIRe checklist versions follow their own release cycle and semantic versioning scheme:

https://github.com/FAIR-eDNA/FAIRe_checklist

Changes to the FAIRe2MDT conversion workflow, validation logic, and output formatting are tracked separately through the FAIRe2MDT version history.
