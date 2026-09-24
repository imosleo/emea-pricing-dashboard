import pandas as pd

# 1. Load the dataset (using read_excel since we fixed that earlier!)
superstore = pd.read_excel("superstore.xlsx")

# Ensure Sales is treated as a numeric value
superstore['Sales'] = pd.to_numeric(superstore['Sales'], errors='coerce')

print("=========================================")
print("      SUPERSTORE DATASET BREAKDOWN       ")
print("=========================================\n")

# --- A. THE BIG PICTURE ---
print("1. TOTAL SIZE:")
print(f"Total Rows (Transactions): {len(superstore)}")
print(f"Total Columns: {len(superstore.columns)}\n")

# --- B. THE MARKETS & COUNTRIES ---
print("2. GEOGRAPHIC BREAKDOWN:")
print(f"Total Unique Countries: {superstore['Country'].nunique()}\n")
print("Transactions per Market:")
# value_counts() automatically counts how many times each market appears
print(superstore['Market'].value_counts().to_string())
print("\n")

# --- C. THE DISCOUNT BEHAVIOR ---
print("3. DISCOUNT BEHAVIOR:")
print(f"Average Discount applied: {round(superstore['Discount'].mean() * 100, 2)}%")
print(f"Maximum Discount applied: {superstore['Discount'].max() * 100}%\n")

# --- D. THE PROFIT CRISIS (Finding the problem) ---
print("4. PROFIT & DISCOUNT BY MARKET (Finding the weakest link):")
# Group by Market, then calculate sum of Sales/Profit and average of Discount
profit_by_market = superstore.groupby('Market').agg(
    Total_Sales=('Sales', 'sum'),
    Total_Profit=('Profit', 'sum'),
    Average_Discount_Pct=('Discount', lambda x: round(x.mean() * 100, 2))
).reset_index()

# Sort the final table from the worst profit to the best profit
profit_by_market = profit_by_market.sort_values(by='Total_Profit')

# Print without the row index numbers for a cleaner look
print(profit_by_market.to_string(index=False))