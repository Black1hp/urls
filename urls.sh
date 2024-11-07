#!/bin/bash

# Prompt user for file or single domain
read -p "Enter the file name containing domains, or press Enter to search for a single domain: " file

# Check if the user entered a file or a single domain
if [[ -n "$file" && -f "$file" ]]; then
    # Use the file with multiple domains
    echo "Using domains from $file"
    domain_source="$file"
else
    # Prompt for a single domain
    read -p "Enter the domain to search for subdomains (e.g., example.com): " single_domain
    echo "$single_domain" > single_domain.txt
    domain_source="single_domain.txt"
fi

# Step 1: Gather URLs with katana and filter for the target domain
echo "Gathering URLs with katana..."
katana -list "$domain_source" -o katana_raw.txt
grep -f "$domain_source" katana_raw.txt > katana.txt
rm -f katana_raw.txt

# Step 2: Gather URLs with waybackurls and filter for the target domain
echo "Gathering URLs with waybackurls..."
cat "$domain_source" | waybackurls > wayback_raw.txt
grep -f "$domain_source" wayback_raw.txt > wayback.txt
rm -f wayback_raw.txt

# Step 3: Gather URLs with gospider and filter for the target domain
echo "Gathering URLs with gospider..."
gospider -S "$domain_source" | sed -n 's/.*\(https:\/\/[^ ]*\)]*.*/\1/p' > gospider_raw.txt
grep -f "$domain_source" gospider_raw.txt > gospider.txt
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

# Step 7: Fuzz each unique domain in httpx.txt for sensitive paths

# List of common paths to check
paths=(
    "/wp-json"
    "/post-sitemap.xml"
    "/wp/wp-admin"
    "/page-sitemap.xml"
    "/wp-admin"
    "/wp-admin/login.php"
    "/wp-admin/wp-login.php"
    "/wp-login.php"
    "/wp-login.php?action=register"
    "/wp-config.php"
    "/wp-admin/admin-ajax.php"
    "/wp-admin/upload.php"
    "/wp-content/"
    "/wp-content/uploads"
    "/wp-includes"
    "/wp-json/wp/v1"
    "/wp-json/wp/v2"
    "/wp-json/wp/v2/users"
    "/wp-json/?rest_route=/wp/v2/users"
    "/wp-json/?rest_route=/wp/v2/users/n"
    "/wp-config.php_"
    "/wp-content/debug.log"
    "/wp-content/plugins/mail-masta"
    "/wp-content/plugins/mail-masta/inc/campaign/count_of_send.php?pl=/etc/passwd"
    "/login.php"
    "/index.php?rest_route=/wp-json/wp/v2/users"
    "/index.php?rest_route=/wp/v2/users"
    "/author-sitemap.xml"
    "/tox.ini"
    "/author/admin"
    "/index.php/author/admin"
    "/license.txt"
    "/readme.html"
    "/robots.txt"
)

# Create a file to store successful responses
echo "Fuzzing each domain for sensitive paths..."
fuzz_results="fuzz_results.txt"
> "$fuzz_results"  # Empty the file if it exists

# Run httpx to collect accessible URLs for each domain
httpx -list "$domain_source" -o httpx.txt

# Loop through each unique domain in httpx.txt and fuzz for each path
while IFS= read -r domain_url; do
    for path in "${paths[@]}"; do
        full_url="${domain_url}${path}"
        # Use httpx to check each URL and log if successful
        httpx -silent -status-code -o "$fuzz_results" -mc 200,201,202,204,206,301,302,303,307,308 -path "$full_url"
    done
done < httpx.txt

# Cleanup
if [[ "$domain_source" == "single_domain.txt" ]]; then
    rm -f single_domain.txt
fi

# Completion message
echo "All steps are complete. Results saved in allurls.txt, js.txt, php.txt, and fuzz_results.txt."
