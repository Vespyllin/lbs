import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

# Load and prepare the data
df = pd.read_csv('./data/benchmark_5_100_high.csv')

# Create configuration labels
df['configuration'] = df.apply(lambda row: 
    'Scheduler'                 if row['is_schedule']   and not row['is_mask']    and not row['is_trim']    else
    'Scheduler + Mask'          if row['is_schedule']   and row['is_mask']        and not row['is_trim']    else
    'Scheduler + Mask + Trim'   if row['is_schedule']   and row['is_mask']        and row['is_trim']        else
    'Random Generation',
    axis=1)

opts = ['Random Generation', 'Scheduler', 'Scheduler + Mask', 'Scheduler + Mask + Trim']

sns.set(style="whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)
palette = sns.color_palette("husl", len(opts))

for function in df['function_name'].unique():
    plt.figure()
    func_df = df[df['function_name'] == function]
    
    for i, config in enumerate(opts):
        config_df = func_df[func_df['configuration'] == config].sort_values('iterations')
        if not config_df.empty:
            cumulative_bugs = np.arange(1, len(config_df)+1)
            plt.plot(config_df['iterations'], cumulative_bugs, 
                    label=config, color=palette[i], linewidth=2)
            plt.scatter(config_df['iterations'], cumulative_bugs, color=palette[i], alpha=0.7)
    
    plt.title(f'{function}: Cumulative Bugs Found Over Iterations - High Energy (5m Timeout)')
    plt.xlabel('Iterations')
    plt.ylabel('Bugs Found')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'./data/high_energy/{function}_iter_high.png', dpi=300)
    plt.close()



print("Analysis saved")
