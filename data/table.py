import pandas as pd

# Load the data
df = pd.read_csv('./data/benchmark_5_100.csv')

# Define the configuration mapping and order
config_mapping = {
    (False, False, False): 'Random Generation',
    (True, False, False): 'Scheduler',
    (True, True, False): 'Scheduler + Mask',
    (True, True, True): 'Scheduler + Mask + Trim'
}

# Apply configuration labels
df['configuration'] = df.apply(
    lambda row: config_mapping[(row['is_schedule'], row['is_mask'], row['is_trim'])], 
    axis=1
)


# Get all unique functions and configurations
all_functions = df['function_name'].unique()
all_configs = list(config_mapping.values())

# Create a complete multi-index for all combinations
index = pd.MultiIndex.from_product(
    [all_functions, all_configs],
    names=['Function', 'Configuration']
)

# Count bugs per function and configuration
bug_counts = (df.groupby(['function_name', 'configuration'])
              .size()
              .reindex(index, fill_value=0)
              .unstack())

# Display the results
print("Bugs Found per Function and Configuration:")
print(bug_counts)

# Optional: Save to CSV
bug_counts.to_csv('bug_counts_summary.csv')
print("\nResults saved to 'bug_counts_summary.csv'")