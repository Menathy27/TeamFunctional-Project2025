#!/bin/bash

# Script: 04_analysis.sh
# Purpose: Statistical analysis of preprocessed fMRI data
# Dependencies: FSL v6.0.7
# Usage: bash 04_analysis.sh

# Ensure FSL is loaded
if [ -z "$FSLDIR" ]; then
    echo "Error: FSL not found. Please load FSL v6.0.7"
    exit 1
fi

# Set up environment variables
export FMRISTUDY="connexin_bootcamp_analysis"  # Change this to your actual study name
export PREPROCOUTPUT="preprocessing_output"
export ANALYSISOUTPUT="analysis_output"

# Define paths
STUDY_DIR="/neurodesktop-storage/$FMRISTUDY"
PREPROC_DIR="$STUDY_DIR/$PREPROCOUTPUT"
ANALYSIS_DIR="$STUDY_DIR/$ANALYSISOUTPUT"

# Read subject list
sub_list="${STUDY_DIR}/sub_list"

echo "=== fMRI Statistical Analysis Pipeline ==="
echo "FSL Directory: $FSLDIR"
echo "Study Directory: $STUDY_DIR"
echo "Preprocessing Directory: $PREPROC_DIR"
echo "Analysis Output: $ANALYSIS_DIR"

# Check dependencies
command -v feat >/dev/null 2>&1 || { echo "FSL FEAT required but not installed"; exit 1; }

# Check if preprocessing directory exists
if [ ! -d "$PREPROC_DIR" ]; then
    echo "Error: Preprocessing directory not found. Please run 03_preprocessing.sh first."
    exit 1
fi

# Check if subject list exists
if [ ! -f "$sub_list" ]; then
    echo "Error: Subject list file not found at $sub_list"
    exit 1
fi

# Create analysis output directories
mkdir -p "$ANALYSIS_DIR"
mkdir -p "$ANALYSIS_DIR/first_level"
mkdir -p "$ANALYSIS_DIR/group_level"
mkdir -p "$ANALYSIS_DIR/roi_analysis"
mkdir -p "$ANALYSIS_DIR/results"

echo ""
echo "=== FIRST LEVEL ANALYSIS ==="

# Loop through each subject for first-level analysis
while read -r subject; do
    if [ -n "$subject" ]; then
        echo ""
        echo "Processing first-level analysis for $subject..."
        
        # Define subject directories
        SUBJ_PREPROC="$PREPROC_DIR/$subject"
        SUBJ_ANALYSIS="$ANALYSIS_DIR/first_level/$subject"
        
        # Check if preprocessed data exists
        if [ ! -f "$SUBJ_PREPROC/functional_norm.nii.gz" ]; then
            echo "✗ No preprocessed data found for $subject, skipping..."
            continue
        fi
        
        # Create subject analysis directory
        mkdir -p "$SUBJ_ANALYSIS"
        
        # Create basic FEAT design file (you'll need to customize this)
        # This is a template - modify according to your experimental design
        cat > "$SUBJ_ANALYSIS/design_${subject}.fsf" << EOF
# FEAT version number
set fmri(version) 6.00

# Basic setup
set fmri(level) 1
set fmri(analysis) 1
set fmri(relative_yn) 0
set fmri(help_yn) 1
set fmri(featwatcher_yn) 1
set fmri(sscleanup_yn) 0

# Data
set fmri(outputdir) "$SUBJ_ANALYSIS/${subject}_task.feat"
set fmri(tr) 2.0
set fmri(npts) \$(fslnvols "$SUBJ_PREPROC/functional_norm.nii.gz")
set feat_files(1) "$SUBJ_PREPROC/functional_norm.nii.gz"

# Delete volumes (leave as 0 unless you need to delete initial volumes)
set fmri(ndelete) 0

# Perfusion tag/control order (leave as 1 for task-based fMRI)
set fmri(tagfirst) 1

# High pass filter cutoff (seconds)
set fmri(paradigm_hp) 100

# Apply motion correction (0 = no, 1 = yes) - already done in preprocessing
set fmri(mc) 0

# Slice timing correction (0 = no, 1 = yes) - already done in preprocessing  
set fmri(st) 0

# BET brain extraction (0 = no, 1 = yes) - already done in preprocessing
set fmri(bet_yn) 0

# Spatial smoothing FWHM (mm) - already done in preprocessing
set fmri(smooth) 0

# Intensity normalization (0 = no, 1 = yes) - already done in preprocessing
set fmri(norm_yn) 0

# High-pass temporal filtering (0 = no, 1 = yes) - already done in preprocessing
set fmri(temphp_yn) 0

# Low-pass temporal filtering (0 = no, 1 = yes)
set fmri(templp_yn) 0

# MELODIC ICA data exploration (0 = no, 1 = yes)
set fmri(melodic_yn) 0

# Carry out main stats (0 = no, 1 = yes)
set fmri(stats_yn) 1

# Carry out prewhitening (0 = no, 1 = yes)
set fmri(prewhiten_yn) 1

# Number of EVs (experimental variables)
set fmri(evs_orig) 2
set fmri(evs_real) 2
set fmri(evs_vox) 0

# Number of contrasts
set fmri(ncon_orig) 1
set fmri(ncon_real) 1

# EV 1: Task condition (customize for your task)
set fmri(evtitle1) "Task"
set fmri(shape1) 2
set fmri(convolve1) 2
set fmri(convolve_phase1) 0
set fmri(tempfilt_yn1) 1
set fmri(deriv_yn1) 1
set fmri(custom1) "dummy"

# EV 2: Motion parameters (confound)
set fmri(evtitle2) "Motion"
set fmri(shape2) 2
set fmri(convolve2) 0
set fmri(convolve_phase2) 0
set fmri(tempfilt_yn2) 0
set fmri(deriv_yn2) 0
set fmri(custom2) "$SUBJ_PREPROC/functional_mcf.par"

# Contrast 1: Task vs Rest
set fmri(conname_real.1) "Task > Rest"
set fmri(con_real1.1) 1
set fmri(con_real1.2) 0

# Registration
set fmri(reginitial_highres_yn) 0
set fmri(reghighres_yn) 0
set fmri(regstandard_yn) 0
EOF

        echo "✓ Created design file for $subject"
        
        # Run FEAT first-level analysis
        echo "Running FEAT first-level analysis for $subject..."
        if [ ! -d "$SUBJ_ANALYSIS/${subject}_task.feat" ]; then
            feat "$SUBJ_ANALYSIS/design_${subject}.fsf"
            
            if [ $? -eq 0 ]; then
                echo "✓ First-level analysis completed for $subject"
            else
                echo "✗ First-level analysis failed for $subject"
                continue
            fi
        else
            echo "✓ First-level analysis already completed for $subject"
        fi
        
    fi
done < "$sub_list"

echo ""
echo "=== GROUP LEVEL ANALYSIS ==="

# Count completed first-level analyses
completed_subjects=()
while read -r subject; do
    if [ -n "$subject" ] && [ -d "$ANALYSIS_DIR/first_level/$subject/${subject}_task.feat" ]; then
        completed_subjects+=("$subject")
    fi
done < "$sub_list"

n_subjects=${#completed_subjects[@]}
echo "Found $n_subjects subjects with completed first-level analysis"

if [ $n_subjects -gt 1 ]; then
    echo "Setting up group-level analysis..."
    
    GROUP_DIR="$ANALYSIS_DIR/group_level"
    
    # Create group-level design matrix (one-sample t-test)
    cat > "$GROUP_DIR/design.mat" << EOF
/NumWaves 1
/NumPoints $n_subjects
/PPheights 1

/Matrix
EOF
    
    # Add ones for each subject (one-sample t-test)
    for ((i=1; i<=n_subjects; i++)); do
        echo "1" >> "$GROUP_DIR/design.mat"
    done
    
    # Create contrast file
    cat > "$GROUP_DIR/design.con" << EOF
/ContrastName1 Group_Mean
/NumWaves 1
/NumContrasts 1
/PPheights 1 0
/RequiredEffect 0

/Matrix
1
EOF
    
    # Create group structure file
    cat > "$GROUP_DIR/design.grp" << EOF
/NumWaves 1
/NumPoints $n_subjects

/Matrix
EOF
    
    for ((i=1; i<=n_subjects; i++)); do
        echo "1" >> "$GROUP_DIR/design.grp"
    done
    
    # Create mask from first subject
    FIRST_SUBJ=${completed_subjects[0]}
    cp "$ANALYSIS_DIR/first_level/$FIRST_SUBJ/${FIRST_SUBJ}_task.feat/mask.nii.gz" "$GROUP_DIR/mask.nii.gz"
    
    # Collect cope images
    mkdir -p "$GROUP_DIR/copes"
    i=1
    for subject in "${completed_subjects[@]}"; do
        cp "$ANALYSIS_DIR/first_level/$subject/${subject}_task.feat/stats/cope1.nii.gz" \
           "$GROUP_DIR/copes/cope${i}.nii.gz"
        ((i++))
    done
    
    # Run group analysis using FLAME
    echo "Running group-level analysis..."
    cd "$GROUP_DIR"
    
    # Merge copes
    fslmerge -t all_copes copes/cope*.nii.gz
    
    # Run FLAME1
    flameo --cope=all_copes \
           --mask=mask \
           --ld=stats \
           --dm=design.mat \
           --tc=design.con \
           --cs=design.grp \
           --runmode=flame1
    
    if [ $? -eq 0 ]; then
        echo "✓ Group-level analysis completed"
    else
        echo "✗ Group-level analysis failed"
    fi
    
else
    echo "⚠ Not enough subjects for group analysis (need >1)"
fi

echo ""
echo "=== MULTIPLE COMPARISONS CORRECTION ==="

if [ -f "$ANALYSIS_DIR/group_level/stats/zstat1.nii.gz" ]; then
    echo "Applying cluster correction..."
    cd "$ANALYSIS_DIR/group_level/stats"
    
    cluster --in=zstat1 \
            --thresh=2.3 \
            --oindex=cluster_index \
            --olmax=lmax.txt \
            --osize=cluster_size \
            --pthresh=0.05 \
            --peakdist=5.0
    
    if [ $? -eq 0 ]; then
        echo "✓ Cluster correction completed"
        echo "Results saved in: $ANALYSIS_DIR/group_level/stats/"
    else
        echo "✗ Cluster correction failed"
    fi
else
    echo "⚠ No group-level z-statistics found, skipping cluster correction"
fi

echo ""
echo "=== ROI ANALYSIS ==="

# Create standard ROI masks (you can customize these)
ROI_DIR="$ANALYSIS_DIR/roi_analysis"

echo "Creating standard ROI masks..."

# Motor cortex ROI from Harvard-Oxford atlas
if [ -f "$FSLDIR/data/atlases/HarvardOxford/HarvardOxford-cortl-maxprob-thr25-2mm.nii.gz" ]; then
    # Extract precentral gyrus (motor cortex) - region 6
    fslroi "$FSLDIR/data/atlases/HarvardOxford/HarvardOxford-cortl-maxprob-thr25-2mm.nii.gz" \
           "$ROI_DIR/motor_mask.nii.gz" 6 1
    
    # Create gray matter mask
    fslmaths "$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz" \
             -thr 0.1 -bin "$ROI_DIR/GM_mask.nii.gz"
    
    echo "✓ Created ROI masks"
else
    echo "⚠ Harvard-Oxford atlas not found, creating simple masks"
    # Create simple whole-brain mask
    fslmaths "$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz" \
             -thr 0.1 -bin "$ROI_DIR/GM_mask.nii.gz"
fi

# Extract ROI values for each subject
echo "Extracting ROI values..."

# Create CSV header
echo "SubjectID,MeanActivation_GM,MeanActivation_Motor" > "$ANALYSIS_DIR/results/activation_values.csv"

# Extract values for each subject
for subject in "${completed_subjects[@]}"; do
    if [ -f "$ANALYSIS_DIR/first_level/$subject/${subject}_task.feat/stats/cope1.nii.gz" ]; then
        
        COPE_FILE="$ANALYSIS_DIR/first_level/$subject/${subject}_task.feat/stats/cope1.nii.gz"
        
        # Extract mean from gray matter
        if [ -f "$ROI_DIR/GM_mask.nii.gz" ]; then
            gm_mean=$(fslstats "$COPE_FILE" -k "$ROI_DIR/GM_mask.nii.gz" -M)
        else
            gm_mean="N/A"
        fi
        
        # Extract mean from motor cortex
        if [ -f "$ROI_DIR/motor_mask.nii.gz" ]; then
            motor_mean=$(fslstats "$COPE_FILE" -k "$ROI_DIR/motor_mask.nii.gz" -M)
        else
            motor_mean="N/A"
        fi
        
        # Add to CSV
        echo "${subject},${gm_mean},${motor_mean}" >> "$ANALYSIS_DIR/results/activation_values.csv"
        
        echo "✓ Extracted ROI values for $subject"
    fi
done

echo "✓ ROI analysis completed"
echo "Results saved to: $ANALYSIS_DIR/results/activation_values.csv"

echo ""
echo "=== CONNECTIVITY ANALYSIS (Optional) ==="

# Basic seed-based connectivity analysis
if [ ${#completed_subjects[@]} -gt 0 ]; then
    echo "Running seed-based connectivity analysis..."
    
    CONN_DIR="$ANALYSIS_DIR/connectivity"
    mkdir -p "$CONN_DIR"
    
    # Use motor cortex as seed region
    if [ -f "$ROI_DIR/motor_mask.nii.gz" ]; then
        
        for subject in "${completed_subjects[@]}"; do
            FUNC_FILE="$PREPROC_DIR/$subject/functional_norm.nii.gz"
            SUBJ_CONN="$CONN_DIR/$subject"
            mkdir -p "$SUBJ_CONN"
            
            if [ -f "$FUNC_FILE" ]; then
                # Extract seed time series
                fslmeants -i "$FUNC_FILE" \
                          -o "$SUBJ_CONN/seed_timeseries.txt" \
                          -m "$ROI_DIR/motor_mask.nii.gz"
                
                # Compute correlation maps
                fsl_glm -i "$FUNC_FILE" \
                        -d "$SUBJ_CONN/seed_timeseries.txt" \
                        -o "$SUBJ_CONN/seed_connectivity" \
                        --out_z="$SUBJ_CONN/seed_connectivity_z"
                
                if [ $? -eq 0 ]; then
                    echo "✓ Connectivity analysis completed for $subject"
                else
                    echo "✗ Connectivity analysis failed for $subject"
                fi
            fi
        done
        
    else
        echo "⚠ No motor mask found, skipping connectivity analysis"
    fi
else
    echo "⚠ No subjects available for connectivity analysis"
fi

echo ""
echo "=== GENERATING ANALYSIS SUMMARY ==="

# Generate comprehensive analysis summary
cat > "$ANALYSIS_DIR/analysis_summary.txt" << EOF
fMRI Statistical Analysis Summary
Generated: $(date)

Study: $FMRISTUDY
FSL Version: $(cat $FSLDIR/etc/fslversion)

Analysis Completed:
- First-level analysis: ${#completed_subjects[@]} subjects
- Group-level analysis: $([ -f "$ANALYSIS_DIR/group_level/stats/zstat1.nii.gz" ] && echo "Yes" || echo "No")
- Multiple comparisons correction: $([ -f "$ANALYSIS_DIR/group_level/stats/cluster_index.nii.gz" ] && echo "Yes" || echo "No")
- ROI analysis: $([ -f "$ANALYSIS_DIR/results/activation_values.csv" ] && echo "Yes" || echo "No")
- Connectivity analysis: $([ -d "$ANALYSIS_DIR/connectivity" ] && echo "Yes" || echo "No")

Subjects Analyzed:
EOF

for subject in "${completed_subjects[@]}"; do
    echo "✓ $subject" >> "$ANALYSIS_DIR/analysis_summary.txt"
done

echo "" >> "$ANALYSIS_DIR/analysis_summary.txt"
echo "Output Directories:" >> "$ANALYSIS_DIR/analysis_summary.txt"
echo "- First-level results: $ANALYSIS_DIR/first_level/" >> "$ANALYSIS_DIR/analysis_summary.txt"
echo "- Group-level results: $ANALYSIS_DIR/group_level/" >> "$ANALYSIS_DIR/analysis_summary.txt"
echo "- ROI analysis: $ANALYSIS_DIR/roi_analysis/" >> "$ANALYSIS_DIR/analysis_summary.txt"
echo "- Final results: $ANALYSIS_DIR/results/" >> "$ANALYSIS_DIR/analysis_summary.txt"

if [ -f "$ANALYSIS_DIR/results/activation_values.csv" ]; then
    echo "" >> "$ANALYSIS_DIR/analysis_summary.txt"
    echo "Sample ROI Results:" >> "$ANALYSIS_DIR/analysis_summary.txt"
    head -5 "$ANALYSIS_DIR/results/activation_values.csv" >> "$ANALYSIS_DIR/analysis_summary.txt"
fi

echo ""
echo "=== Statistical Analysis Pipeline Completed ==="
echo "Successfully analyzed: ${#completed_subjects[@]} subjects"
echo "Summary saved to: $ANALYSIS_DIR/analysis_summary.txt"
echo ""
echo "Key output files:"
echo "- Group activation map: $ANALYSIS_DIR/group_level/stats/zstat1.nii.gz"
echo "- Cluster corrected results: $ANALYSIS_DIR/group_level/stats/cluster_index.nii.gz"
echo "- ROI values: $ANALYSIS_DIR/results/activation_values.csv"
echo "- Analysis summary: $ANALYSIS_DIR/analysis_summary.txt"
echo ""
echo "Next steps:"
echo "1. Visualize results using FSLeyes"
echo "2. Export activation values for statistical testing"
echo "3. Create figures and tables for publication"
echo "4. Interpret results in context of your research hypotheses"
