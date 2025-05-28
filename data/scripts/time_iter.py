import pandas as pd

# Load data from the specified path
df = pd.read_csv('./data/benchmark_5_100.csv')

# Configuration mapping
config_mapping = {
    (False, False, False): 'Random Generation',
    (True, False, False): 'Scheduler',
    (True, True, False): 'Scheduler + Mask',
    (True, True, True): 'Scheduler + Mask + Trim'
}

# Add configuration labels
df['configuration'] = df.apply(
    lambda row: config_mapping[(row['is_schedule'], row['is_mask'], row['is_trim'])],
    axis=1
)

# Calculate average time per iteration in milliseconds
results = (df.groupby(['function_name', 'configuration'])
           .apply(lambda x: (x['time'].sum() / x['iterations'].sum()) * 1000)
           .unstack()
           .fillna(0))

# Reorder columns to match desired configuration order
results = results[['Random Generation', 'Scheduler', 'Scheduler + Mask', 'Scheduler + Mask + Trim']]

# Print results
print("Average Time per Iteration (ms) by Function and Configuration:")
print(results.to_string(float_format="%.3f"))