#!/bin/bash

# Prompt for the target domain
read -p "Enter the target domain (e.g., example.com): " domain

# Check if httpx.txt exists
if [[ ! -f "httpx.txt" ]]; then
    echo "Error: httpx.txt not found. Please make sure the httpx.txt file is available."
    exit 1
fi

# Step 1: Gather URLs with katana and filter for the target domain
echo "Gathering URLs with katana..."
katana -list httpx.txt -o katana_raw.txt
grep "$domain" katana_raw.txt > katana.txt
rm -f katana_raw.txt

# Step 2: Gather URLs with waybackurls and filter for the target domain
echo "Gathering URLs with waybackurls..."
cat httpx.txt | waybackurls > wayback_raw.txt
grep "$domain" wayback_raw.txt > wayback.txt
rm -f wayback_raw.txt

# Step 3: Gather URLs with gospider and filter for the target domain
echo "Gathering URLs with gospider..."
gospider -S httpx.txt | sed -n 's/.*\(https:\/\/[^ ]*\)]*.*/\1/p' > gospider_raw.txt
grep "$domain" gospider_raw.txt > gospider.txt
rm -f gospider_raw.txt

# Step 4: Combine all results into one file and remove duplicates
echo "Combining all URLs and removing duplicates..."
cat katana.txt wayback.txt gospider.txt | anew > allurls.txt

# Step 5: Extract JavaScript files
echo "Extracting JavaScript files..."
grep -E "\.js$" allurls.txt > js.txt

# Step 6: Extract PHP files
echo "Extracting PHP files..."
grep -E "\.php$" allurls.txt > php.txt

# Completion message
echo "All steps are complete. Results saved in allurls.txt, js.txt, and php.txt."
