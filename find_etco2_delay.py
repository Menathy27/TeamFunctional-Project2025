#!/usr/bin/env python
# coding: utf-8

# In[ ]:


import numpy as np
from scipy.interpolate import interp1d
from scipy.stats import pearsonr

# Example usage:
# opt_delay, opt_etco2 = find_etco2_delay(bold_curve, etco2_timecourse, tr, [-10, 10])

def find_etco2_delay(bold_curve, etco2_timecourse, tr, delay_range):
    """
    Find optimal delay between BOLD signal and EtCO2 timecourse.
    
    Parameters:
    bold_curve : BOLD signal data (array-like)
    etco2_timecourse : EtCO2 timecourse data with time in column 0, values in column 1 (2D array)
    tr : Repetition time (float)
    delay_range : [min_delay, max_delay] range to search (list or tuple)
        
    Returns:
    opt_delay : Optimal delay value (float)      
    opt_etco2 : Interpolated EtCO2 at optimal delay (array)   
    """
    
    step = 0.01  # units: s
    samples = 100
    dyn_num = len(bold_curve)
    
    # Create delay arrays
    delays1 = np.linspace(delay_range[0], delay_range[1], samples)
    delays2 = np.arange(delay_range[0], delay_range[1] + step, step)
    
    # Initialize correlation coefficient array
    cc = np.zeros(samples)
    
    # Calculate correlation for each delay in delays1
    for i in range(samples):
        etco2_tmp = interp_time(etco2_timecourse, delays1[i], dyn_num, tr)
        # Using scipy.stats.pearsonr - returns (correlation, p-value)
        cc[i] = pearsonr(etco2_tmp, bold_curve)[0]
    
    # Interpolate to find maximum correlation with finer resolution
    f = interp1d(delays1, cc, kind='cubic', bounds_error=False, fill_value='extrapolate')
    V = f(delays2)
    
    # Find maximum correlation and corresponding delay
    max_cc = np.max(V)
    ind_etco2 = np.argmax(V)
    opt_delay = delays2[ind_etco2]
    
    # Get optimal EtCO2 timecourse
    opt_etco2 = interp_time(etco2_timecourse, opt_delay, dyn_num, tr)
    
    return opt_delay, opt_etco2


def interp_time(timecourse, shift, dyn_num, timestep):
    """
    Interpolate timecourse data with a time shift.
    
    Parameters:
    timecourse : Timecourse data with time in column 0, values in column 1 (2D array)      
    shift : Time shift value (positive shift means shift towards the right) (float)       
    dyn_num : Number of output points (int)    
    timestep : Time step between points (float)
               
    Returns:
    interp_curve : Interpolated curve values (array)        
    """
    
    time = timecourse[:, 0]
    values = timecourse[:, 1]
    
    start = np.max(time)
    stop = np.min(time)
    
    # Create time points for interpolation - positive shift means shift towards to the right
    z = np.arange(dyn_num) * timestep - shift
    
    # Initialize output array
    interp_curve = np.zeros(dyn_num)
    
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

