import pandas as pd
from itertools import product

# Load the data
df = pd.read_csv('./data/benchmark_5_100_high.csv')

# Create configuration labels
df['configuration'] = df.apply(
    lambda row: f"S{"1" if row['is_schedule'] else "0"}_M{"1" if row['is_mask'] else "0"}_T{"1" if row['is_trim'] else "0"}",
    axis=1
)

# Create pivot table counting queue status per function and configuration
result = pd.pivot_table(
    df,
    index=['function_name', 'configuration'],
    columns='queue',
    values='time',  # We just need counts, so any column would work
    aggfunc='count',
    fill_value=0
).reset_index()

# Reorder columns to show successful, discard, random
result = result[['function_name', 'configuration', 'successful', 'discard']]

# Print the table
print("Bug Status Counts by Function and Configuration:")
print(result.to_string(index=False))

# Optional: Save to CSV
result.to_csv('./data/quality_high.csv', index=False)
print("\nResults saved to './data/quality_high.csv'")