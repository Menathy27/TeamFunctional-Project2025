# TeamFunctional-Project2025

Mercy Nathaniel - \[Ahmadu Bello University], \[Zaria], \[Nigeria]

Kimberley Clare Williams - \[Neuroscience Institute], \[University of Cape Town], \[Cape Town], \[South Africa]

Usman Mohammed Mahmud - \[Federal Teaching Hospital], \[Gombe], \[Nigeria]

Musbau Mubarak Remilekun - \[University of maiduguri], \[Maiduguri], \[Nigeria]

Nuwe Bryant Nyero - \[Mbarara University of Science and Technology], \[Mbarara], \[Uganda]

Wirba Amabel Ginjeh -\[Cameroon Baptist Convention], \[Douala], \[Cameroon]


# fMRI Preprocessing and Analysis Pipeline

## Overview
This repository contains a complete pipeline for fMRI data preprocessing and analysis, developed for CONNExIN 2025 Assignment 6. The pipeline follows BIDS standards and uses FSL tools for robust neuroimaging analysis.

## Scripts

### 01_data_structure.sh
- **Purpose**: Convert DICOM files to BIDS format and validate dataset
- **Dependencies**: dcm2niix, deno environment, conda
- **Output**: BIDS-formatted dataset with validation

### 02_quality_control.sh  
- **Purpose**: Generate quality control metrics using MRIQC
- **Dependencies**: MRIQC v24.0.2
- **Output**: HTML reports and quantitative QC metrics

### 03_preprocessing.sh
- **Purpose**: Complete fMRI preprocessing pipeline
- **Dependencies**: FSL v6.0.7, FreeSurfer (optional)
- **Steps**: Motion correction, slice timing, brain extraction, smoothing, filtering, registration, normalization

### 04_analysis.sh
- **Purpose**: Statistical analysis and results generation
- **Dependencies**: FSL v6.0.7
- **Output**: Activation maps, ROI analysis, group statistics

## Usage

### Prerequisites
- FSL v6.0.7 installed and configured
- MRIQC v24.0.2 available
- Neurodesk environment (or equivalent)
- Subject list file (`sub_list`) with participant IDs

### Running the Pipeline
```bash
# 1. Convert DICOM to BIDS
bash 01_data_structure.sh

# 2. Quality control
bash 02_quality_control.sh

# 3. Preprocessing
bash 03_preprocessing.sh

# 4. Statistical analysis
bash 04_analysis.sh
