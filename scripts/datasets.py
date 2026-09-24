import pandas as pd

# 1. Your 40 EMEA countries list
emea_countries = [
    'Albania', 'Armenia', 'Austria', 'Azerbaijan', 'Bahrain', 'Belarus', 
    'Bosnia and Herzegovina', 'Bulgaria', 'Croatia', 'Czech Republic', 
    'Estonia', 'Georgia', 'Hungary', 'Iran, Islamic Rep.', 'Iraq', 'Israel', 'Jordan', 
    'Kazakhstan', 'Kyrgyz Republic', 'Lebanon', 'Lithuania', 'North Macedonia', 
    'Moldova', 'Mongolia', 'Montenegro', 'Poland', 'Qatar', 'Romania', 
    'Russian Federation', 'Saudi Arabia', 'Slovak Republic', 'Slovenia', 'Syrian Arab Republic', 'Tajikistan', 
    'Turkiye', 'Turkmenistan', 'Ukraine', 'United Arab Emirates', 
    'Uzbekistan', 'Yemen, Rep.'
]

# (Note: I slightly adjusted a few names above like "Russian Federation" and "Turkiye" 
# to perfectly match how the World Bank spells them, otherwise they get dropped!)

# 2. Define a reusable function to clean any World Bank file
def clean_wb_file(filename, metric_name):
    # Load the file, skip the 4 junk rows
    df = pd.read_csv(filename, skiprows=4)
    
    # Keep only the Country Name and our 4 years
    cols_to_keep = ['Country Name', '2011', '2012', '2013', '2014']
    df = df[cols_to_keep]
    
    # Filter for ONLY our EMEA countries
    df = df[df['Country Name'].isin(emea_countries)]
    
    # "Melt" the data from wide to long
    clean_df = df.melt(
        id_vars=['Country Name'], 
        var_name='Year', 
        value_name=metric_name
    )
    return clean_df

print("Cleaning and merging datasets...")

# 3. Process all three files using our function
gdp_clean = clean_wb_file("wb_gdp.csv", "GDP_per_Capita")
inflation_clean = clean_wb_file("wb_inflation.csv", "Inflation_Rate")
unemployment_clean = clean_wb_file("wb_unemployment.csv", "Unemployment_Rate")

# 4. Merge them all together into one master table
# First merge GDP and Inflation
master_external = pd.merge(gdp_clean, inflation_clean, on=['Country Name', 'Year'], how='inner')
# Then merge Unemployment into that
master_external = pd.merge(master_external, unemployment_clean, on=['Country Name', 'Year'], how='inner')

# 5. Save the final clean file for your R Shiny Dashboard!
master_external.to_csv("processed_external_data.csv", index=False)

# Show a sneak peek of the final result
print("\nSuccess! Here is a peek at your master external dataset:")
print(master_external.head(10).to_string(index=False))
print(f"\nTotal rows: {len(master_external)}")
print("Saved as 'processed_external_data.csv' in your folder.")