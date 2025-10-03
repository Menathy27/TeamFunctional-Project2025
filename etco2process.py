#!/usr/bin/env python
# coding: utf-8

# In[ ]:


import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.signal import find_peaks

# Example usage:
# timepeaks, co2envlp = etco2_process(etco2_data, 'co2_envelope.txt', 100, 90)

def etco2_process(co2data, etco2_chopped_filename, SR, min_prctile):
    """
    Extract CO2 envelope from physiological data by finding peaks.
    
    Parameters:
    co2data : DataFrame with columns ['time', 'co2_mmHg'] or 2D array
    etco2_chopped_filename : Output filename to save results (str)
    SR : Sampling rate in Hz (float)
    min_prctile : Minimum percentile threshold for peak detection (float)
    
    Returns:
    timepeaks : Time points of detected peaks (array)
    co2envlp : CO2 values at detected peaks (array)
    """
    
    # Extract data - handle both DataFrame and array inputs
    if isinstance(co2data, pd.DataFrame):
        if 'co2' in co2data.columns and 'time' in co2data.columns:
            co2 = co2data['co2'].values
            time = co2data['time'].values
        else:
            # Assume first column is CO2, second is time (like MATLAB)
            time = co2data.iloc[:, 0].values
            co2 = co2data.iloc[:, 1].values
    else:
        # Array input - assume MATLAB format [co2, time]
        time = co2data[:, 0]
        co2 = co2data[:, 1]
    
    # Calculate minimum peak distance (2.5 * sampling rate)
    dis = int(3 * SR)
    
    # Calculate height threshold as percentile
    height = np.percentile(co2, min_prctile)
    
    # Find peaks using scipy
    peaks, _ = find_peaks(co2, height=height, distance=dis)
    
    # Extract peak values and times
    co2envlp = co2[peaks]
    timepeaks = time[peaks]
    
    # Create the plot
    plt.figure(figsize=(15, 6))
    
    # Plot envelope (peaks connected with line)
    plt.plot(timepeaks, co2envlp, 'r-', linewidth=2, label='CO2 Envelope')
    
    # Plot peak markers
    plt.plot(timepeaks, co2envlp, 'r*', markersize=8)
    
    # Plot original signal in gray
    plt.plot(time, co2, '-', color=[0.5, 0.5, 0.5], linewidth=0.8, alpha=0.7, label='Raw CO2')
    
    plt.xlabel('Time (seconds)', fontsize=15)
    plt.ylabel('EtCO2 value (mmHg)', fontsize=15)
    plt.xlim([0, time[-1]])
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.title('CO2 Envelope Extraction')
    
    # Make figure larger (equivalent to MATLAB's Position setting)
    fig = plt.gcf()
    fig.set_size_inches(18, 7)
    
    plt.tight_layout()
    plt.show()
    
    # Save the results to file (timepeaks, co2envlp as columns)
    output_data = np.column_stack([timepeaks, co2envlp])
    np.savetxt(etco2_chopped_filename, output_data, delimiter='\t', 
               comments='')
    
    #print(f"Found {len(timepeaks)} peaks")
    #print(f"Results saved to: {etco2_chopped_filename}")
    #print(f"Peak CO2 range: {co2envlp.min():.2f} to {co2envlp.max():.2f} mmHg")
    
    return timepeaks, co2envlp



