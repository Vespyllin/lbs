import pandas as pd

# Load the data
df = pd.read_csv('./data/benchmark_5_100_high.csv')

# Create configuration labels
df['configuration'] = df.apply(
    lambda row: f"Sched_{row['is_schedule']}_Mask_{row['is_mask']}_Trim_{row['is_trim']}",
    axis=1
)

# Calculate average input length by both configuration and function
avg_input_len = df.groupby(['function_name', 'configuration'])['input_len'].mean().unstack()

# Format the results
print("Average Input Length by Function and Configuration:")
print(avg_input_len.to_string(float_format="%.2f"))

# Optional: Save to CSV
avg_input_len.to_csv('./data/len_high.csv')
print("\nResults saved to './data/len_high.csv'")

# Alternative prettier print
print("\nFormatted Results:")
for function in avg_input_len.index:
    print(f"\nFunction: {function}")
    print(avg_input_len.loc[function].to_string(float_format="%.2f"))