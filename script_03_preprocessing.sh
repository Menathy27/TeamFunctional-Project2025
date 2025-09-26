#!/bin/bash

# Script: 03_preprocessing.sh
# Purpose: Preprocess fMRI data using FSL tools
# Dependencies: FSL v6.0.7, FreeSurfer (optional for bbregister)
# Usage: bash 03_preprocessing.sh

# Ensure FSL v6.0.7 is loaded
if [ -z "$FSLDIR" ]; then
    echo "Error: FSL not found. Please load FSL v6.0.7"
    exit 1
fi

# Set up environment variables
export FMRISTUDY="your_study_name"  # Change this to your actual study name
export BIDSOUTPUT="BIDS_output"
export PREPROCOUTPUT="preprocessing_output"

# Define paths
STUDY_DIR="/neurodesktop-storage/$FMRISTUDY"
BIDS_DIR="$STUDY_DIR/$BIDSOUTPUT"
PREPROC_DIR="$STUDY_DIR/$PREPROCOUTPUT"

# Read subject list
sub_list="${STUDY_DIR}/sub_list"

echo "=== fMRI Preprocessing Pipeline ==="
echo "FSL Directory: $FSLDIR"
echo "FSL Version: $(cat $FSLDIR/etc/fslversion)"
echo "Study Directory: $STUDY_DIR"
echo "BIDS Directory: $BIDS_DIR"
echo "Preprocessing Output: $PREPROC_DIR"

# Check dependencies
command -v fsl >/dev/null 2>&1 || { echo "FSL required but not installed"; exit 1; }

# Check if BIDS directory exists
if [ ! -d "$BIDS_DIR" ]; then
    echo "Error: BIDS directory not found. Please run previous scripts first."
    exit 1
fi

# Check if subject list exists
if [ ! -f "$sub_list" ]; then
    echo "Error: Subject list file not found at $sub_list"
    exit 1
fi

# Create preprocessing output directory
mkdir -p "$PREPROC_DIR"

# Loop through each subject
while read -r subject; do
    if [ -n "$subject" ]; then
        echo ""
        echo "=== Processing $subject ==="
        
        # Define subject directories
        SUBJ_BIDS="$BIDS_DIR/$subject"
        SUBJ_PREPROC="$PREPROC_DIR/$subject"
        
        # Check if subject data exists
        if [ ! -d "$SUBJ_BIDS" ]; then
            echo "✗ Warning: No BIDS data found for $subject, skipping..."
            continue
        fi
        
        # Create subject preprocessing directory
        mkdir -p "$SUBJ_PREPROC"
        
        # Find functional and anatomical files
        FUNC_FILE=$(find "$SUBJ_BIDS/func" -name "*bold.nii.gz" | head -1)
        ANAT_FILE=$(find "$SUBJ_BIDS/anat" -name "*T1w.nii.gz" | head -1)
        
        if [ -z "$FUNC_FILE" ]; then
            echo "✗ No functional data found for $subject, skipping..."
            continue
        fi
        
        if [ -z "$ANAT_FILE" ]; then
            echo "✗ No anatomical data found for $subject, skipping..."
            continue
        fi
        
        echo "Functional file: $FUNC_FILE"
        echo "Anatomical file: $ANAT_FILE"
        
        # Copy original files to preprocessing directory
        cp "$FUNC_FILE" "$SUBJ_PREPROC/functional_orig.nii.gz"
        cp "$ANAT_FILE" "$SUBJ_PREPROC/structural_orig.nii.gz"
        
        # Navigate to subject preprocessing directory
        cd "$SUBJ_PREPROC"
        
        # Step 1: Motion Correction
        echo "Step 1: Motion correction..."
        if [ ! -f "functional_mcf.nii.gz" ]; then
            mcflirt -in functional_orig -out functional_mcf -plots -rmsrel -rmsabs -stats
            if [ $? -eq 0 ]; then
                echo "✓ Motion correction completed"
            else
                echo "✗ Motion correction failed for $subject"
                continue
            fi
        else
            echo "✓ Motion correction already completed"
        fi
        
        # Step 2: Slice Timing Correction
        echo "Step 2: Slice timing correction..."
        if [ ! -f "functional_stc.nii.gz" ]; then
            # Note: Adjust TR and slice order parameters based on your data
            slicetimer -i functional_mcf -o functional_stc --tr=2.0 --odd --verbose
            if [ $? -eq 0 ]; then
                echo "✓ Slice timing correction completed"
            else
                echo "✗ Slice timing correction failed for $subject"
                continue
            fi
        else
            echo "✓ Slice timing correction already completed"
        fi
        
        # Step 3: Brain Extraction - Functional
        echo "Step 3: Brain extraction (functional)..."
        if [ ! -f "functional_brain.nii.gz" ]; then
            bet functional_stc functional_brain -F -m
            if [ $? -eq 0 ]; then
                echo "✓ Functional brain extraction completed"
            else
                echo "✗ Functional brain extraction failed for $subject"
                continue
            fi
        else
            echo "✓ Functional brain extraction already completed"
        fi
        
        # Step 3b: Brain Extraction - Structural
        echo "Step 3b: Brain extraction (structural)..."
        if [ ! -f "structural_brain.nii.gz" ]; then
            bet structural_orig structural_brain -R -f 0.5 -g 0
            if [ $? -eq 0 ]; then
                echo "✓ Structural brain extraction completed"
            else
                echo "✗ Structural brain extraction failed for $subject"
                continue
            fi
        else
            echo "✓ Structural brain extraction already completed"
        fi
        
        # Step 4: Spatial Smoothing
        echo "Step 4: Spatial smoothing..."
        if [ ! -f "functional_smooth.nii.gz" ]; then
            susan functional_brain 500 2.12 3 1 1 functional_smooth
            if [ $? -eq 0 ]; then
                echo "✓ Spatial smoothing completed"
            else
                echo "✗ Spatial smoothing failed for $subject"
                continue
            fi
        else
            echo "✓ Spatial smoothing already completed"
        fi
        
        # Step 5: Temporal Filtering
        echo "Step 5: Temporal filtering..."
        if [ ! -f "functional_filtered.nii.gz" ]; then
            # High-pass: 100s (25 TRs for TR=2s), Low-pass: 2.5 TRs
            fslmaths functional_smooth -bptf 25 2.5 functional_filtered
            if [ $? -eq 0 ]; then
                echo "✓ Temporal filtering completed"
            else
                echo "✗ Temporal filtering failed for $subject"
                continue
            fi
        else
            echo "✓ Temporal filtering already completed"
        fi
        
        # Step 6: Functional to Structural Coregistration
        echo "Step 6: Functional to structural coregistration..."
        if [ ! -f "func2struct.mat" ]; then
            # Create white matter mask for BBR (optional - requires segmentation)
            # For now, use standard correlation ratio
            flirt -in functional_filtered -ref structural_brain \
                  -out func2struct -omat func2struct.mat \
                  -cost corratio -dof 6 -searchrx -90 90 \
                  -searchry -90 90 -searchrz -90 90
            if [ $? -eq 0 ]; then
                echo "✓ Functional to structural coregistration completed"
            else
                echo "✗ Coregistration failed for $subject"
                continue
            fi
        else
            echo "✓ Coregistration already completed"
        fi
        
        # Step 7: Structural to Standard Space Registration
        echo "Step 7: Structural to standard space registration..."
        if [ ! -f "struct2standard_warp.nii.gz" ]; then
            # Linear pre-registration
            flirt -in structural_brain \
                  -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain \
                  -out struct2standard \
                  -omat struct2standard_init.mat \
                  -dof 12
            
            # Nonlinear registration
            fnirt --in=structural_brain \
                  --ref=$FSLDIR/data/standard/MNI152_T1_2mm_brain \
                  --aff=struct2standard_init.mat \
                  --cout=struct2standard_warp \
                  --config=T1_2_MNI152_2mm
                  
            if [ $? -eq 0 ]; then
                echo "✓ Standard space registration completed"
            else
                echo "✗ Standard space registration failed for $subject"
                continue
            fi
        else
            echo "✓ Standard space registration already completed"
        fi
        
        # Step 8: Apply Transformations
        echo "Step 8: Applying transformations to functional data..."
        if [ ! -f "functional_standard.nii.gz" ]; then
            applywarp --ref=$FSLDIR/data/standard/MNI152_T1_2mm_brain \
                      --in=functional_filtered \
                      --warp=struct2standard_warp \
                      --premat=func2struct.mat \
                      --out=functional_standard \
                      --interp=trilinear
            if [ $? -eq 0 ]; then
                echo "✓ Transformation to standard space completed"
            else
                echo "✗ Transformation failed for $subject"
                continue
            fi
        else
            echo "✓ Transformation already completed"
        fi
        
        # Step 9: Intensity Normalization
        echo "Step 9: Intensity normalization..."
        if [ ! -f "functional_norm.nii.gz" ]; then
            fslmaths functional_standard -ing 10000 functional_norm -odt float
            if [ $? -eq 0 ]; then
                echo "✓ Intensity normalization completed"
            else
                echo "✗ Intensity normalization failed for $subject"
                continue
            fi
        else
            echo "✓ Intensity normalization already completed"
        fi
        
        # Step 10: Artifact/Noise Removal (ICA)
        echo "Step 10: Running ICA for artifact detection..."
        if [ ! -d "functional_ica.ica" ]; then
            melodic -i functional_norm \
                    -o functional_ica.ica \
                    --nobet \
                    --mmthresh=0.5 \
                    --report
            if [ $? -eq 0 ]; then
                echo "✓ ICA analysis completed"
                echo "  → Review components in functional_ica.ica/report.html"
                echo "  → Manual classification of noise components required"
            else
                echo "✗ ICA analysis failed for $subject"
                continue
            fi
        else
            echo "✓ ICA analysis already completed"
        fi
        
        # Generate preprocessing summary for this subject
        echo "Generating preprocessing summary for $subject..."
        cat > "preprocessing_summary_${subject}.txt" << EOF
Preprocessing Summary for $subject
Generated: $(date)

Input Files:
- Functional: $FUNC_FILE
- Anatomical: $ANAT_FILE

Processing Steps Completed:
1. ✓ Motion Correction (mcflirt)
2. ✓ Slice Timing Correction (slicetimer)
3. ✓ Brain Extraction (bet)
4. ✓ Spatial Smoothing (susan)
5. ✓ Temporal Filtering (fslmaths)
6. ✓ Coregistration (flirt)
7. ✓ Standard Space Registration (fnirt)
8. ✓ Apply Transformations (applywarp)
9. ✓ Intensity Normalization (fslmaths)
10. ✓ ICA Artifact Detection (melodic)

Output Files:
- Final preprocessed data: functional_norm.nii.gz
- ICA components: functional_ica.ica/
- Motion parameters: functional_mcf.par
- Transformation matrices: func2struct.mat, struct2standard_warp.nii.gz

Next Steps:
- Review ICA components and remove artifacts
- Proceed to statistical analysis
EOF
        
        echo "✓ $subject preprocessing completed successfully"
        
    fi
done < "$sub_list"

# Generate overall preprocessing summary
echo ""
echo "Generating overall preprocessing summary..."
cat > "$PREPROC_DIR/preprocessing_summary.txt" << EOF
fMRI Preprocessing Pipeline Summary
Generated: $(date)

Study: $FMRISTUDY
FSL Version: $(cat $FSLDIR/etc/fslversion)

Processing Parameters:
- TR: 2.0s (adjust if different)
- Slice Order: Odd (adjust if different)
- Smoothing: 5mm FWHM (2.12 sigma)
- High-pass filter: 100s (0.01 Hz)
- Standard space: MNI152 2mm

Subjects Processed:
EOF

# Count completed subjects
completed_count=0
total_count=0
while read -r subject; do
    if [ -n "$subject" ]; then
        total_count=$((total_count + 1))
        if [ -f "$PREPROC_DIR/$subject/functional_norm.nii.gz" ]; then
            echo "✓ $subject - Completed" >> "$PREPROC_DIR/preprocessing_summary.txt"
            completed_count=$((completed_count + 1))
        else
            echo "✗ $subject - Failed or incomplete" >> "$PREPROC_DIR/preprocessing_summary.txt"
        fi
    fi
done < "$sub_list"

echo "" >> "$PREPROC_DIR/preprocessing_summary.txt"
echo "Summary: $completed_count/$total_count subjects completed successfully" >> "$PREPROC_DIR/preprocessing_summary.txt"

echo ""
echo "=== Preprocessing Pipeline Completed ==="
echo "Successfully processed: $completed_count/$total_count subjects"
echo "Summary saved to: $PREPROC_DIR/preprocessing_summary.txt"
echo ""
echo "Next steps:"
echo "1. Review ICA components for each subject"
echo "2. Remove identified artifacts if necessary"
echo "3. Run 04_analysis.sh for statistical analysis"