#!/bin/bash

# Prompt for a file or a single URL input
read -p "Enter the file name containing URLs (from httpx), or press Enter to input a single URL: " file

# Check if the user entered a file or a single URL
if [[ -n "$file" && -f "$file" ]]; then
    echo "Using URLs from $file"
    url_source="$file"
else
    read -p "Enter a single URL (e.g., https://example.com): " single_url
    echo "$single_url" > single_url.txt
    url_source="single_url.txt"
fi

# Handle existing result files
for result_file in katana.txt wayback.txt gospider.txt allurls.txt js.txt php.txt fuzz_results.txt; do
    if [[ -f $result_file ]]; then
        read -p "File '$result_file' exists. Press Enter to append results, or type 'd' to delete and start fresh: " choice
        if [[ $choice == 'd' ]]; then
            rm "$result_file"
            echo "Deleted $result_file."
        else
            echo "Appending to $result_file."
        fi
    fi
done

# Function to filter URLs by domain
filter_urls() {
    local input_file="$1"
    local domain_file="$2"
    grep -iFf "$domain_file" "$input_file" || echo "No matching URLs found in $input_file."
}

# Step 1: Gather URLs with katana and filter by target domain(s)
echo "Gathering URLs with katana..."
katana -list "$url_source" -o katana_raw.txt 2>/dev/null
filter_urls "katana_raw.txt" "$url_source" >> katana.txt
rm -f katana_raw.txt

# Step 2: Gather URLs with waybackurls and filter by target domain(s)
echo "Gathering URLs with waybackurls..."
cat "$url_source" | waybackurls > wayback_raw.txt 2>/dev/null
filter_urls "wayback_raw.txt" "$url_source" >> wayback.txt
rm -f wayback_raw.txt

# Step 3: Gather URLs with gospider and filter by target domain(s)
echo "Gathering URLs with gospider..."
gospider -S "$url_source" | sed -n 's/.*\(https:\/\/[^ ]*\)]*.*/\1/p' > gospider_raw.txt 2>/dev/null
filter_urls "gospider_raw.txt" "$url_source" >> gospider.txt
rm -f gospider_raw.txt

# Step 4: Combine all results and remove duplicates
echo "Combining URLs and removing duplicates..."
cat katana.txt wayback.txt gospider.txt | anew >> allurls.txt

# Step 5: Extract JavaScript files
echo "Extracting JavaScript files..."
grep -E "\.js$" allurls.txt >> js.txt

# Step 6: Extract PHP files
echo "Extracting PHP files..."
grep -E "\.php$" allurls.txt >> php.txt

# Step 7: Fuzzing for sensitive paths
echo "Fuzzing each original URL for sensitive paths..."

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

# Create file to store fuzzing results
fuzz_results="fuzz_results.txt"

# Sanitize URLs and perform fuzzing
while IFS= read -r url; do
    # Remove trailing slashes from the URL if present
    sanitized_url=$(echo "$url" | sed 's:/*$::')
    
    # Loop through each path and check for valid responses
    for path in "${paths[@]}"; do
        full_url="${sanitized_url}${path}"
        echo "$full_url" | httpx -silent -status-code -mc 200,201,202,204,206,301,302,303,307,308 >> "$fuzz_results" 2>/dev/null
    done
done < "$url_source"

# Cleanup
if [[ "$url_source" == "single_url.txt" ]]; then
    rm -f single_url.txt
fi

# Completion message
echo "Script complete. Results saved in allurls.txt, js.txt, php.txt, and fuzz_results.txt."
