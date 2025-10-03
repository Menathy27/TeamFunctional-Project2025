import numpy as np
import nibabel as nib
import pandas as pd
import pingouin as pg
from sklearn.linear_model import LinearRegression
from scipy.interpolate import interp1d
from scipy.optimize import minimize_scalar
from find_etco2_delay import interp_time

def voxelwise_cvr(func_file, etco2, wbsignal, mask_file, tr, motion=None, max_lag=20):
    """
    Compute voxel-wise CVR with CO2 lag correction.

    Parameters:
    func_file: str - 4D fMRI NIfTI file path (already preprocessed & aligned)       
    co2_data: ndarray - CO2 trace (resampled to TR of fMRI)
    wbsignal: ndarray - whole brain BOLD timecourse
    motion_file: str or None - Motion regressors file (T x 6) (optional)
    max_lag: int - Maximum lag to search (in TRs).

    Returns:
    cvr_map: ndarray - 3D array of CVR values.
    beta_map: ndarray - 3D array of CO2 regression coefficients.
    lag_map: ndarray - 3D array of voxel-wise lags (in TRs).
    """
    # Load data
    bold_img = nib.load(func_file)
    data = bold_img.get_fdata()
    T = data.shape[3]
    time = np.arange(T) * tr

    mask_img = nib.load(mask_file)
    mask = mask_img.get_fdata().astype(bool)
    masked_data = data[mask,:] # shape: (total_voxels, T)
    total_voxels = masked_data.shape[0]

    if etco2.shape[0] != T:
        raise ValueError("CO2 trace length does not match fMRI TRs")

    if wbsignal.shape[0] != T:
        raise ValueError("Signal length does not match fMRI TRs")

    if motion is not None:
        if motion.shape[0] != T:
            raise ValueError("Motion regressors length does not match fMRI TRs")
    else:
        motion = np.empty((T,0))  # empty design if no motion

    # Prepare output maps
    X_dim, Y_dim, Z_dim = data.shape[:3]
    beta_map = np.zeros((X_dim, Y_dim, Z_dim))
    cvr_map  = np.zeros((X_dim, Y_dim, Z_dim))
    lag_map  = np.zeros((X_dim, Y_dim, Z_dim))

    mask_idx = np.flatnonzero(mask)
    # Loop over voxels
    for i in range(masked_data.shape[0]):
        if i % max(total_voxels // 100, 1) == 0 or i == total_voxels - 1:
            percent = (i + 1) / total_voxels * 100
            print(f"Progress: {percent:.1f}% ({i+1}/{total_voxels} voxels)")
        
        # Estimate lag
        voxelsignal = masked_data[i,:]
        optdelay, shifted_wb = voxeldly(voxelsignal, wbsignal, tr, delay_range=[-10,30],motion=motion)

        # Shift CO2
        timecourse = np.column_stack([time, etco2])
        etco2_shifted = interp_time(timecourse,optdelay,T,tr)
        b_etco2 = np.mean(etco2_shifted[etco2_shifted < np.percentile(etco2_shifted, 25)])

        # Build design matrix
        X_design = np.column_stack([etco2_shifted, motion])

        # Fit GLM
        model = LinearRegression().fit(X_design, voxelsignal)
        beta_co2 = model.coef_[0]  
        voxel0 = model.intercept_

        beta_map.ravel()[mask_idx[i]] = beta_co2
        lag_map.ravel()[mask_idx[i]] = optdelay
        denom = voxel0 + beta_co2 * b_etco2
        if np.isnan(denom) or np.abs(denom) < 1e-6:
            cvr_map.ravel()[mask_idx[i]] = np.nan
        else:
            cvr_map.ravel()[mask_idx[i]] = 100 * beta_co2 / denom

    return beta_map, cvr_map, lag_map
    

def voxeldly (voxelsignal, wbsignal, tr, delay_range=[-10,30],motion=None):
    """
    Estimate optimal delay for a single voxel and compute GLM coefficient.
    
    voxelsignal: array (T,)
    wbsignal: array (T,)
    tr: repetition time in seconds
    delay_range: [min_delay, max_delay] in seconds
    stepdly: step size for fine search in seconds
    motion: optional motion regressors (T x n)
    
    Returns: opt_delay (s), shifted_wb
    """
    T = len(voxelsignal)
    time = np.arange(T) * tr

    # Coarse search over candidate delays (1 TR steps)
    delays = np.arange(delay_range[0], delay_range[1]+tr, tr)
    cc_list = []
    for d in delays:
        timecourse = np.column_stack([time, wbsignal])
        shifted_wb = interp_time(timecourse,d,T, tr)  

        df = pd.DataFrame({"voxel": voxelsignal, "wb": shifted_wb})
        if motion is not None:
            for i in range(motion.shape[1]):
                df["motion" + str(i)] = motion[:,i].astype(float)
    
            # Create list of motion column names for covariates
            covars = []
            for i in range(motion.shape[1]):
                covars.append("motion" + str(i))                   
                # Motion columns are covariates (skip first 2 columns: voxel, wb)
            covars = list(df.columns[2:])
        else:
            covars = None  
                
        # Compute partial correlation      
        res = pg.partial_corr(data=df, x="wb", y="voxel", covar=covars)
        cc_val = res["r"].values[0]
        cc_list.append(cc_val)

    cc_array = np.array(cc_list)

    # Polynomial fit to refine
    p = np.polyfit(delays, cc_array, 4)
    polyfun = lambda x: -np.polyval(p, x)
    res_opt = minimize_scalar(polyfun, bounds=delay_range, method='bounded')
    optdelay = res_opt.x

    # Shift WB signal with optimal delay
    timecourse = np.column_stack([time, wbsignal])
    shifted_wb = interp_time(timecourse, optdelay, T,tr)
    
    return optdelay, shifted_wb

def interp_time(timecourse, shift, dynnum, timestep):
    """
    Interpolate timecourse data with a time shift.
    
    Parameters:
    timecourse : Timecourse data with time in column 0, values in column 1 (2D array)      
    shift : Time shift value (positive shift means shift towards the right) (float)       
    dynnum : Number of output points (int)    
    timestep : Time step between points (float)
               
    Returns:
    interp_curve : Interpolated curve values (array)        
    """
    
    time = timecourse[:, 0]
    values = timecourse[:, 1]
    
    start = np.max(time)
    stop = np.min(time)
    
    # Create time points for interpolation - positive shift means shift towards to the right
    z = np.arange(dynnum) * timestep - shift
    
    # Initialize output array
    interp_curve = np.zeros(dynnum)
    
    # Find indices for different time regions
    ind1 = z < stop  # time values before timecourse start
    ind2 = (z >= stop) & (z <= start)  # time values within timecourse range
    ind3 = z > start  # time values after timecourse end
    
    # Set all time values < starting time to be the first value
    if np.any(ind1):
        interp_curve[ind1] = values[0]

    
    # Set all time values > ending time to be the last value
    if np.any(ind3):
        interp_curve[ind3] = values[-1]
    
    # Interpolate values within the timecourse range
    if np.any(ind2):
        f = interp1d(time, values, kind='linear', bounds_error=False)
        interp_curve[ind2] = f(z[ind2])
    
    return interp_curve
