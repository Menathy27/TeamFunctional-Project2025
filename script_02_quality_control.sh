#!/bin/bash

# Script: 02_quality_control.sh
# Purpose: Run MRIQC quality control analysis on BIDS dataset
# Dependencies: MRIQC v24.0.2, FSL (for viewing)
# Usage: bash 02_quality_control.sh

# Set up environment variables
export FMRISTUDY="connexin_bootcamp_analysis"  # Change this to your actual study name
export BIDSOUTPUT="BIDS_output"
export MRIQCOUTPUT="MRIQC_output"

# Define paths
STUDY_DIR="/neurodesktop-storage/$FMRISTUDY"
BIDS_DIR="$STUDY_DIR/$BIDSOUTPUT"
MRIQC_DIR="$STUDY_DIR/$MRIQCOUTPUT"

echo "=== MRIQC Quality Control Pipeline ==="
echo "Study Directory: $STUDY_DIR"
echo "BIDS Directory: $BIDS_DIR"
echo "MRIQC Output: $MRIQC_DIR"

# Check if BIDS directory exists
if [ ! -d "$BIDS_DIR" ]; then
    echo "Error: BIDS directory not found at $BIDS_DIR"
    echo "Please run 01_data_structure.sh first"
    exit 1
fi

# Load MRIQC module
echo "Loading MRIQC module..."
ml mriqc/24.0.2

if [ $? -ne 0 ]; then
    echo "Error: Could not load MRIQC module"
    echo "Please ensure MRIQC v24.0.2 is available"
    exit 1
fi

# Create MRIQC output directory
echo "Creating MRIQC output directory..."
mkdir -p "$MRIQC_DIR"

# Set environment variables for MRIQC
export BIDSOUTPUT="$BIDS_DIR"
export MRIQCOUTPUT="$MRIQC_DIR"

echo "Running participant-level MRIQC analysis..."
mriqc "$BIDSOUTPUT" "$MRIQCOUTPUT" participant \
    --n_procs 4 \
    --mem_gb 16 \
    --verbose

if [ $? -eq 0 ]; then
    echo "✓ Participant-level MRIQC analysis completed"
else
    echo "✗ Error in participant-level MRIQC analysis"
    exit 1
fi

echo "Running group-level MRIQC analysis..."
mriqc "$BIDSOUTPUT" "$MRIQCOUTPUT" group \
    --n_procs 4 \
    --mem_gb 16 \
    --verbose

if [ $? -eq 0 ]; then
    echo "✓ Group-level MRIQC analysis completed"
else
    echo "✗ Error in group-level MRIQC analysis"
    exit 1
fi

# Check output files
echo "Checking MRIQC output files..."

if [ -f "$MRIQCOUTPUT/group_bold.tsv" ]; then
    echo "✓ Found group_bold.tsv"
    echo "Preview of BOLD QC metrics:"
    head -n 3 "$MRIQCOUTPUT/group_bold.tsv"
else
    echo "✗ Warning: group_bold.tsv not found"
fi

if [ -f "$MRIQCOUTPUT/group_T1w.tsv" ]; then
    echo "✓ Found group_T1w.tsv"
    echo "Preview of T1w QC metrics:"
    head -n 3 "$MRIQCOUTPUT/group_T1w.tsv"
else
    echo "✗ Warning: group_T1w.tsv not found"
fi

# List all generated files
echo "MRIQC output files generated:"
ls -la "$MRIQCOUTPUT"

# Generate QC summary
echo "Generating QC summary..."
echo "=== MRIQC Quality Control Summary ===" > "$MRIQC_DIR/QC_summary.txt"
echo "Date: $(date)" >> "$MRIQC_DIR/QC_summary.txt"
echo "BIDS Directory: $BIDS_DIR" >> "$MRIQC_DIR/QC_summary.txt"
echo "MRIQC Output: $MRIQC_DIR" >> "$MRIQC_DIR/QC_summary.txt"
echo "" >> "$MRIQC_DIR/QC_summary.txt"

# Count subjects processed
if [ -f "$MRIQCOUTPUT/group_bold.tsv" ]; then
    n_subjects=$(tail -n +2 "$MRIQCOUTPUT/group_bold.tsv" | wc -l)
    echo "Number of subjects with BOLD data: $n_subjects" >> "$MRIQC_DIR/QC_summary.txt"
fi

if [ -f "$MRIQCOUTPUT/group_T1w.tsv" ]; then
    n_subjects_t1=$(tail -n +2 "$MRIQCOUTPUT/group_T1w.tsv" | wc -l)
    echo "Number of subjects with T1w data: $n_subjects_t1" >> "$MRIQC_DIR/QC_summary.txt"
fi

echo "" >> "$MRIQC_DIR/QC_summary.txt"
echo "Files generated:" >> "$MRIQC_DIR/QC_summary.txt"
ls -1 "$MRIQCOUTPUT" >> "$MRIQC_DIR/QC_summary.txt"

echo "✓ QC summary saved to $MRIQC_DIR/QC_summary.txt"

# Instructions for visual inspection
echo ""
echo "=== Next Steps for Quality Control ==="
echo "1. Open the HTML reports in $MRIQC_DIR for visual inspection"
echo "2. Review group_bold.tsv and group_T1w.tsv for quantitative metrics"
echo "3. Check for:"
echo "   - High motion subjects (FD > 0.5mm)"
echo "   - Poor temporal SNR (tSNR < 50)"
echo "   - Signal dropout regions"
echo "   - Unusual intensity patterns"
echo ""
echo "4. Consider excluding subjects with poor quality metrics"
echo "5. Document any exclusions and reasoning"
echo ""

# Optional: Launch FSLeyes for manual inspection if available
if command -v fsleyes &> /dev/null; then
    echo "FSLeyes is available for visual inspection."
    echo "To inspect data manually, run:"
    echo "fsleyes \$BIDS_DIR/sub-*/anat/sub-*_T1w.nii.gz &"
    echo "fsleyes \$BIDS_DIR/sub-*/func/sub-*_task-*_bold.nii.gz &"
fi

echo "=== Quality Control Pipeline Completed ==="
echo "Next step: Review QC results, then run 03_preprocessing.sh"
