#!/bin/bash

# Script: 01_data_structure.sh
# Purpose: Convert DICOM files to BIDS format and validate the dataset
# Dependencies: dcm2niix (latest), deno environment, conda
# Usage: bash 01_data_structure.sh

# Set up environment variables
export FMRISTUDY="connexin_bootcamp_analysis"  # Change this to your actual study name
export BIDSOUTPUT="BIDS_output"
export RAWDATA="RAWDATA"

# Define paths
STUDY_DIR="/neurodesktop-storage/$FMRISTUDY"
BIDS_DIR="$STUDY_DIR/$BIDSOUTPUT"
RAW_DIR="$STUDY_DIR/$RAWDATA"

# Read subject list
sub_list="${STUDY_DIR}/sub_list"

echo "=== DICOM to BIDS Conversion Pipeline ==="
echo "Study Directory: $STUDY_DIR"
echo "BIDS Output: $BIDS_DIR"
echo "Raw Data: $RAW_DIR"

# Check if subject list exists
if [ ! -f "$sub_list" ]; then
    echo "Error: Subject list file not found at $sub_list"
    echo "Please create a file with participant IDs (one per line, format: sub-01)"
    exit 1
fi

# Create output directory
echo "Creating BIDS output directory..."
mkdir -p "$BIDS_DIR"

# Check if dcm2niix is available
command -v dcm2niix >/dev/null 2>&1 || { 
    echo "Error: dcm2niix required but not installed"
    echo "Please install dcm2niix before running this script"
    exit 1
}

# Loop through each subject
while read -r subject; do
    if [ -n "$subject" ]; then
        echo "Processing $subject..."
        
        # Check if raw data exists for this subject
        if [ -d "$RAW_DIR/$subject" ]; then
            echo "Converting DICOM files for $subject..."
            
            # Run dcm2niix conversion
            dcm2niix -b y -z y -o "$BIDS_DIR" "$RAW_DIR/$subject"
            
            if [ $? -eq 0 ]; then
                echo "✓ Successfully converted $subject"
            else
                echo "✗ Error converting $subject"
                continue
            fi
        else
            echo "✗ Warning: Raw data directory not found for $subject"
            continue
        fi
    fi
done < "$sub_list"

# Create required BIDS files
echo "Creating BIDS descriptor files..."

# Create dataset_description.json
cat > "$BIDS_DIR/dataset_description.json" << EOF
{
    "Name": "$FMRISTUDY",
    "BIDSVersion": "1.8.0",
    "DatasetType": "raw",
    "Authors": [
        "Your Name",
        "Team Members"
    ],
    "ReferencesAndLinks": [
        "https://protocols.io/view/bids-quality-control-and-pre-processing-pipeline-f-g8hpbzt5p"
    ]
}
EOF

# Create participants.tsv
echo -e "participant_id\tage\tsex" > "$BIDS_DIR/participants.tsv"
while read -r subject; do
    if [ -n "$subject" ]; then
        echo -e "$subject\tn/a\tn/a" >> "$BIDS_DIR/participants.tsv"
    fi
done < "$sub_list"

echo "✓ Created dataset_description.json and participants.tsv"

# Install deno for BIDS validation if not already installed
echo "Checking deno installation..."
if ! command -v deno &> /dev/null; then
    echo "Installing deno environment..."
    conda install -c conda-forge deno -y
    
    if [ $? -eq 0 ]; then
        echo "✓ Deno installed successfully"
    else
        echo "✗ Error installing deno"
        exit 1
    fi
else
    echo "✓ Deno already installed"
fi

# Verify deno installation
deno --version

# Run BIDS validator
echo "Running BIDS validation..."
cd "$STUDY_DIR"

deno run -ERWN jsr:@bids/validator "$BIDSOUTPUT" --ignoreWarnings

if [ $? -eq 0 ]; then
    echo "✓ BIDS validation completed successfully"
else
    echo "✗ BIDS validation found issues - please review and fix before proceeding"
    exit 1
fi

echo "=== Data Structure Pipeline Completed ==="
echo "Next step: Run 02_quality_control.sh"
