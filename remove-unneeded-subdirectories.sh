#!/bin/bash

# Script to remove unneeded subdirectories
# If a subdirectory contains only a single file, move that file up to the current directory
# and then remove the empty subdirectory.

# Error handling is done explicitly for each operation to prevent data loss

# Get the current working directory
cwd=$(pwd)

# Counter for processed directories
processed_count=0

# Array to track processed directories
processed_dirs=()

# Array to track skipped files due to naming conflicts
skipped_files=()

# Find all subdirectories (one level deep)
while IFS= read -r -d '' subdir; do
    # Skip if not a directory
    [ ! -d "$subdir" ] && continue
    
    # Count ALL items (files, directories, hidden files) in the subdirectory
    # We need to verify the directory is truly empty after moving
    total_items=$(find "$subdir" -maxdepth 1 -mindepth 1 | wc -l)
    
    # Count only visible files (non-hidden, non-directory)
    visible_file_count=$(find "$subdir" -maxdepth 1 -type f ! -name ".*" | wc -l)
    
    # Count hidden files
    hidden_file_count=$(find "$subdir" -maxdepth 1 -type f -name ".*" | wc -l)
    
    # Count subdirectories
    subdir_count=$(find "$subdir" -maxdepth 1 -mindepth 1 -type d | wc -l)
    
    # Only process if there's exactly one visible file and nothing else
    if [ "$visible_file_count" -eq 1 ] && [ "$hidden_file_count" -eq 0 ] && [ "$subdir_count" -eq 0 ]; then
        # Get the single file
        single_file=$(find "$subdir" -maxdepth 1 -type f ! -name ".*" | head -n 1)
        filename=$(basename "$single_file")
        
        # Check if a file with the same name already exists in cwd
        # Do NOT overwrite existing files - skip this file and folder entirely
        if [ -f "$cwd/$filename" ]; then
            echo "Warning: File '$filename' already exists in '$cwd', skipping subdirectory '$subdir'"
            skipped_files+=("$filename (in $subdir)")
            continue
        fi
        
        # Move the file to the current directory
        echo "Moving '$single_file' to '$cwd/'"
        if ! mv "$single_file" "$cwd/"; then
            echo "Error: Failed to move '$single_file', skipping directory removal"
            continue
        fi
        
        # Verify the directory is now empty before attempting to remove it
        remaining_items=$(find "$subdir" -maxdepth 1 -mindepth 1 | wc -l)
        if [ "$remaining_items" -eq 0 ]; then
            # Remove the now-empty subdirectory
            echo "Removing empty subdirectory '$subdir'"
            if rmdir "$subdir"; then
                processed_count=$((processed_count + 1))
                processed_dirs+=("$subdir")
            else
                echo "Warning: Failed to remove directory '$subdir' (may not be empty)"
            fi
        else
            echo "Warning: Directory '$subdir' is not empty after moving file (contains $remaining_items item(s)), skipping removal"
        fi
    fi
done < <(find . -maxdepth 1 -mindepth 1 -type d -print0)

# Print summary
echo ""
echo "=== Summary ==="
if [ "$processed_count" -eq 0 ]; then
    echo "No subdirectories with a single file were processed."
else
    echo "Successfully processed $processed_count subdirectory(ies):"
    for dir in "${processed_dirs[@]}"; do
        echo "  - $dir"
    done
fi

if [ ${#skipped_files[@]} -gt 0 ]; then
    echo ""
    echo "Files skipped due to naming conflicts (existing file in cwd):"
    for skipped in "${skipped_files[@]}"; do
        echo "  - $skipped"
    done
    echo "Total skipped: ${#skipped_files[@]} file(s)"
else
    echo "No files were skipped due to naming conflicts."
fi

