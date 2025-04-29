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

# Validate URL format in the input
while IFS= read -r url; do
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo "Error: Invalid URL format in $url_source: $url (must start with http:// or https://)."
        exit 1
    fi
done < "$url_source"

# Check for required tools
check_tools

# Define fixed results files
results_files=("katana.txt" "wayback.txt" "gospider.txt" "allurls.txt" "js.txt" "php.txt")

# Ask user whether to append to or overwrite existing results files
read -p "Append to existing results files or overwrite all? (a/o): " append_or_overwrite
if [[ "$append_or_overwrite" == 'o' ]]; then
    for file in "${results_files[@]}"; do
        if [[ -f "$file" ]]; then
            > "$file"
        fi
    done
    echo "Overwrote existing results files."
else
    echo "Appending to existing results files."
fi

# Additional options for bug hunters
read -p "Do you want to extract additional file types? (y/n): " extract_files
if [[ "$extract_files" == 'y' ]]; then
    read -p "Enter additional file extensions to extract (comma-separated, e.g., json,xml): " extensions
fi

read -p "Do you want to extract URLs matching specific patterns? (y/n): " extract_patterns
if [[ "$extract_patterns" == 'y' ]]; then
    read -p "Enter patterns to extract (comma-separated, e.g., /admin,/api): " patterns
fi

read -p "Keep raw output files? (y/n): " keep_raw

# Initialize array to track generated files
generated_files=()

# Function to filter URLs by domain
filter_urls() {
    local input_file="$1"
    local domain_file="$2"
    local output_file="$3"
    grep -oP '(?<=https?://)[^/]+' "$domain_file" | sort -u | while IFS= read -r domain; do
        domain_escaped=$(echo "$domain" | sed 's/\./\\./g')
        grep -E "https?://$domain_escaped(/|$)" "$input_file"
    done >> "$output_file" || echo "No matching URLs found in $input_file."
}

# Step 1: Gather URLs with katana and filter by target domain(s)
echo "Starting URL gathering with katana..."
katana -list "$url_source" -o katana_raw.txt -silent 2>/dev/null
echo "Filtering katana URLs..."
filter_urls "katana_raw.txt" "$url_source" "katana.txt"
generated_files+=("katana.txt")
if [[ "$keep_raw" == 'y' ]]; then
    generated_files+=("katana_raw.txt")
else
    rm -f katana_raw.txt
fi

# Step 2: Gather URLs with waybackurls and filter by target domain(s)
echo "Starting URL gathering with waybackurls..."
cat "$url_source" | waybackurls > wayback_raw.txt 2>/dev/null
echo "Filtering wayback URLs..."
filter_urls "wayback_raw.txt" "$url_source" "wayback.txt"
generated_files+=("wayback.txt")
if [[ "$keep_raw" == 'y' ]]; then
    generated_files+=("wayback_raw.txt")
else
    rm -f wayback_raw.txt
fi

# Step 3: Gather URLs with gospider and filter by target domain(s)
echo "Starting URL gathering with gospider..."
gospider -S "$url_source" --no-color | grep -oP 'https?://[^ ]+' > gospider_raw.txt 2>/dev/null
echo "Filtering gospider URLs..."
filter_urls "gospider_raw.txt" "$url_source" "gospider.txt"
generated_files+=("gospider.txt")
if [[ "$keep_raw" == 'y' ]]; then
    generated_files+=("gospider_raw.txt")
else
    rm -f gospider_raw.txt
fi

# Step 4: Combine all results and remove duplicates
echo "Combining URLs and removing duplicates..."
cat katana.txt wayback.txt gospider.txt | sort -u | anew allurls.txt > /dev/null
generated_files+=("allurls.txt")

# Step 5: Extract JavaScript files
echo "Extracting JavaScript files..."
grep -E '\.js(\?.*)?$' allurls.txt | sort -u > js.txt
generated_files+=("js.txt")

# Step 6: Extract PHP files
echo "Extracting PHP files..."
grep -E '\.php(\?.*)?$' allurls.txt | sort -u > php.txt
generated_files+=("php.txt")

# Extract additional file types if specified
if [[ "$extract_files" == 'y' ]]; then
    IFS=',' read -ra ext_array <<< "$extensions"
    for ext in "${ext_array[@]}"; do
        echo "Extracting .$ext files..."
        output_file="${ext}.txt"
        grep -E "\.$ext(\?.*)?\$" allurls.txt | sort -u > "$output_file"
        generated_files+=("$output_file")
    done
fi

# Extract URLs matching specific patterns if specified
if [[ "$extract_patterns" == 'y' ]]; then
    IFS=',' read -ra pattern_array <<< "$patterns"
    for pattern in "${pattern_array[@]}"; do
        echo "Extracting URLs containing '$pattern'..."
        output_file="${pattern//\//_}.txt"
        grep -E "$pattern" allurls.txt | sort -u > "$output_file"
        generated_files+=("$output_file")
    done
fi

# Cleanup
if [[ "$url_source" == "single_url.txt" ]]; then
    rm -f single_url.txt
fi

# Completion message with summary
echo "Script complete. Results saved in the following files:"
for file in "${generated_files[@]}"; do
    if [[ -f "$file" ]]; then
        line_count=$(wc -l < "$file")
        echo "  - $file: $line_count URLs"
    else
        echo "  - $file: 0 URLs (file not created)"
    fi
done
