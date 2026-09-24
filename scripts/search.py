import pandas as pd

# 1. Load the dataset
superstore = pd.read_excel("superstore.xlsx")

# 2. Filter for only the EMEA market
emea_data = superstore[superstore['Market'] == 'EMEA']

# 3. Extract the unique list of countries and sort them alphabetically
emea_countries = sorted(emea_data['Country'].dropna().unique())

# 4. Print the list clearly
print("=========================================")
print(f"  EMEA COUNTRIES ({len(emea_countries)} total)")
print("=========================================\n")
for country in emea_countries:
    print(f"- {country}")