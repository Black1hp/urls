#!/bin/bash

# Ensure required tools are installed
check_tools() {
    local tools=("katana" "waybackurls" "gospider" "anew" "grep" "sed" "httpx")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            echo "Error: $tool is not installed. Please install it and try again."
            exit 1
        fi
    done
}

# Prompt for a file containing URLs or a single URL input
echo "Provide input for URL collection..."
read -p "Enter the file name containing URLs (from httpx), or press Enter to input a single URL: " file

# Check if the user entered a file or a single URL
if [[ -n "$file" && -f "$file" ]]; then
    echo "Using URLs from $file"
    url_source="$file"
elif [[ -n "$file" && ! -f "$file" ]]; then
    echo "Error: File '$file' does not exist."
    exit 1
else
    read -p "Enter a single URL (e.g., https://example.com): " single_url
    if [[ -z "$single_url" ]]; then
        echo "Error: No URL provided."
        exit 1
    fi
    echo "$single_url" > single_url.txt
    url_source="single_url.txt"
fi

# Validate URL format in the input (basic check for http/https)
while IFS= read -r url; do
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo "Error: Invalid URL format in $url_source: $url (must start with http:// or https://)."
        exit 1
    fi
done < "$url_source"

# Check for required tools
check_tools

# Ask user whether to append to or delete existing results files if they exist
results_files=("katana.txt" "wayback.txt" "gospider.txt" "allurls.txt" "js.txt" "php.txt")
for result_file in "${results_files[@]}"; do
    if [[ -f "$result_file" ]]; then
        read -p "File '$result_file' exists. Press Enter to append results, or type 'd' to delete and start fresh: " choice
        if [[ "$choice" == 'd' ]]; then
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
    local output_file="$3"
    # Extract domains from URLs in domain_file and create a pattern for grep
    grep -oP '(?<=https?://)[^/]+' "$domain_file" | sort -u | while IFS= read -r domain; do
        # Escape dots in domain for grep
        domain_escaped=$(echo "$domain" | sed 's/\./\\./g')
        grep -E "https?://$domain_escaped(/|$)" "$input_file"
    done >> "$output_file" || echo "No matching URLs found in $input_file."
}

# Step 1: Gather URLs with katana and filter by target domain(s)
echo "Gathering URLs with katana..."
katana -list "$url_source" -o katana_raw.txt -silent 2>/dev/null
filter_urls "katana_raw.txt" "$url_source" "katana.txt"
rm -f katana_raw.txt

# Step 2: Gather URLs with waybackurls and filter by target domain(s)
echo "Gathering URLs with waybackurls..."
cat "$url_source" | waybackurls > wayback_raw.txt 2>/dev/null
filter_urls "wayback_raw.txt" "$url_source" "wayback.txt"
rm -f wayback_raw.txt

# Step 3: Gather URLs with gospider and filter by target domain(s)
echo "Gathering URLs with gospider..."
gospider -S "$url_source" --no-color | grep -oP 'https?://[^ ]+' > gospider_raw.txt 2>/dev/null
filter_urls "gospider_raw.txt" "$url_source" "gospider.txt"
rm -f gospider_raw.txt

# Step 4: Combine all results and remove duplicates
echo "Combining URLs and removing duplicates..."
cat katana.txt wayback.txt gospider.txt | sort -u | anew allurls.txt > /dev/null

# Step 5: Extract JavaScript files
echo "Extracting JavaScript files..."
grep -E '\.js(\?.*)?$' allurls.txt | sort -u > js.txt

# Step 6: Extract PHP files
echo "Extracting PHP files..."
grep -E '\.php(\?.*)?$' allurls.txt | sort -u > php.txt

# Cleanup
if [[ "$url_source" == "single_url.txt" ]]; then
    rm -f single_url.txt
fi

# Completion message with summary
echo "Script complete. Results saved in the following files:"
for file in "${results_files[@]}"; do
    if [[ -f "$file" ]]; then
        line_count=$(wc -l < "$file")
        echo "  - $file: $line_count URLs"
    else
        echo "  - $file: 0 URLs (file not created)"
    fi
done
