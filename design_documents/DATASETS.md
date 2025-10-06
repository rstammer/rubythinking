

The original data files should reside in a data/ folder. 

# Load from built-in CSV file
howell = Rubythinking::Dataset.load("howell")

# Possibility of converting to Daru data frames
df = howell.to_df

# Convert to CSV
csv = howell.to_csv
