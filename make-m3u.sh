#!/bin/bash

# Function to get the base game name (without disc number, rev/ver info, and extension)
get_basename() {
    local filename="$1"
    # Remove extension first
    filename="${filename%.chd}"
    filename="${filename%.rvz}"
    filename="${filename%.iso}"
    filename="${filename%.cue}"
    filename="${filename%.bin}"
    # Remove (Disc/Disk/CD N) patterns - handle with or without spaces, fully case insensitive
    # Also handle patterns without parentheses/brackets (e.g., "Disk1" or "Disk 1")
    # Also handle patterns with descriptive text after the number (e.g., "Disc 1 - Description")
    # Match disc/Disc/DISC and disk/Disk/DISK (all case combinations)
    # Pattern with parentheses: (Disc 1), (Disc1), (DISK 2), (Disc 1 - Description), etc.
    filename=$(echo "$filename" | sed -E 's/[[:space:]]*\([Dd][Ii][Ss][Cc][[:space:]]*[0-9]+[^)]*\)[[:space:]]*//g')
    filename=$(echo "$filename" | sed -E 's/[[:space:]]*\([Dd][Ii][Ss][Kk][[:space:]]*[0-9]+[^)]*\)[[:space:]]*//g')
    # Pattern with square brackets: [Disc 1], [Disc1], [DISK 2], [Disc 1 - Description], etc.
    filename=$(echo "$filename" | sed -E 's/[[:space:]]*\[[Dd][Ii][Ss][Cc][[:space:]]*[0-9]+[^\]]*\][[:space:]]*//g')
    filename=$(echo "$filename" | sed -E 's/[[:space:]]*\[[Dd][Ii][Ss][Kk][[:space:]]*[0-9]+[^\]]*\][[:space:]]*//g')
    # Pattern without parentheses: Disk 1, Disk1, DISK 2, etc.
    filename=$(echo "$filename" | sed -E 's/[[:space:]]+[Dd][Ii][Ss][Cc][[:space:]]*[0-9]+[[:space:]]*//g')
    filename=$(echo "$filename" | sed -E 's/[[:space:]]+[Dd][Ii][Ss][Kk][[:space:]]*[0-9]+[[:space:]]*//g')
    # Match cd/CD/Cd/cD (all case combinations) with parentheses (including descriptive text)
    filename=$(echo "$filename" | sed -E 's/[[:space:]]*\([Cc][Dd][[:space:]]*[0-9]+[^)]*\)[[:space:]]*//g')
    # Match cd/CD/Cd/cD with square brackets (including descriptive text)
    filename=$(echo "$filename" | sed -E 's/[[:space:]]*\[[Cc][Dd][[:space:]]*[0-9]+[^\]]*\][[:space:]]*//g')
    # Match cd/CD/Cd/cD without parentheses/brackets
    filename=$(echo "$filename" | sed -E 's/[[:space:]]+[Cc][Dd][[:space:]]*[0-9]+[[:space:]]*//g')
    # Remove (Rev N) patterns - handle with or without spaces (including descriptive text)
    filename=$(echo "$filename" | sed -E 's/[[:space:]]*\([Rr]ev[[:space:]]*[0-9]+[^)]*\)[[:space:]]*//g')
    # Remove [Rev N] patterns with square brackets
    filename=$(echo "$filename" | sed -E 's/[[:space:]]*\[[Rr]ev[[:space:]]*[0-9]+[^\]]*\][[:space:]]*//g')
    # Remove (Ver N) patterns - handle with or without spaces (including descriptive text)
    filename=$(echo "$filename" | sed -E 's/[[:space:]]*\([Vv]er[[:space:]]*[0-9]+[^)]*\)[[:space:]]*//g')
    # Remove [Ver N] patterns with square brackets
    filename=$(echo "$filename" | sed -E 's/[[:space:]]*\[[Vv]er[[:space:]]*[0-9]+[^\]]*\][[:space:]]*//g')
    # Clean up trailing spaces and dots
    filename=$(echo "$filename" | sed 's/[[:space:]]*$//' | sed 's/\.\.\.*$//')
    echo "$filename"
}

# Function to process files in a given directory
# Global arrays: processed_games, iso_cue_games (declared in main script)
process_directory() {
    local dir="$1"
    local original_dir_name=$(basename "$dir")
    local parent_dir=$(dirname "$dir")
    local original_cwd=$(pwd)
    echo "Processing directory: $dir"
    echo "----------------------------------------"
    
    # Change to the directory
    cd "$dir" || return 1
    
    # Check if there are any .chd, .rvz, .iso, or .cue files in the current directory
    # Note: We exclude .bin files from counting as they are paired with .cue files
    shopt -s nullglob
    files=(*.chd *.rvz *.iso *.cue)
    shopt -u nullglob
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "No .chd, .rvz, .iso, or .cue files found in $dir."
        cd "$original_cwd" || return 1
        return 0
    fi
    
    # If there's only one file, it's definitely a single-disc game - skip processing
    if [ ${#files[@]} -eq 1 ]; then
        echo "Only one .chd, .rvz, .iso, or .cue file found in $dir - skipping (single disc game)."
        cd "$original_cwd" || return 1
        return 0
    fi
    
    # Process each .chd, .rvz, .iso, or .cue file and group by base name
    declare -A games
    for file in "${files[@]}"; do
        basename=$(get_basename "$file")
        echo "Processing file: '$file' (Base name: '$basename')"  # Debugging output
        games["$basename"]+="$file"$'\n'
    done
    
    # Determine how many unique games we have
    num_games=${#games[@]}
    
    # Process each game - create .m3u file for multi-disc games
    # Track if we've already created an .m3u file to ensure only one per directory
    m3u_filename=""
    m3u_created=0
    
    for game in "${!games[@]}"; do
        # Count actual files in the directory that match this game's basename
        # This is the most reliable way to count discs
        matching_files=0
        disk_list=""
        for file in "${files[@]}"; do
            file_basename=$(get_basename "$file")
            if [ "$file_basename" = "$game" ]; then
                ((matching_files++))
                disk_list+="$file"$'\n'
            fi
        done
        
        # Sort the disk list
        disk_list=$(echo "$disk_list" | sort | grep -v '^$')
        
        num_disks=$matching_files
        
        echo "Game: '$game', Number of Discs: $num_disks"  # Debugging output
        
        # Only create .m3u file if there is more than one disc AND we haven't created one yet
        if [ "$num_disks" -gt 1 ] && [ "$m3u_created" -eq 0 ]; then
            # Clean up game name for file creation
            clean_game_name=$(echo "$game" | sed 's/[[:space:]]$//' | sed 's/\.[cC][hH][dD]$//' | sed 's/\.[rR][vV][zZ]$//' | sed 's/\.[iI][sS][oO]$//' | sed 's/\.[cC][uU][eE]$//' | sed 's/\.[bB][iI][nN]$//')
            
            # Check if this game uses .iso or .cue files
            has_iso_or_cue=0
            for file in "${files[@]}"; do
                file_basename=$(get_basename "$file")
                if [ "$file_basename" = "$game" ]; then
                    if [[ "$file" == *.iso || "$file" == *.ISO || "$file" == *.cue || "$file" == *.CUE ]]; then
                        has_iso_or_cue=1
                        break
                    fi
                fi
            done
            
            # Create the .m3u file in the current directory (don't move any files)
            m3u_filename="${clean_game_name}.m3u"
            m3u_file="${m3u_filename}"
            
            # Write the full filenames (with extensions) to the .m3u file
            # Note: .cue files reference their .bin files internally, so we only list .cue files
            echo "$disk_list" | while IFS= read -r line; do
                if [ -n "$line" ]; then
                    echo "$(basename "$line")" >> "$m3u_file"
                fi
            done
            
            m3u_created=1
            
            # Track this processed game
            processed_games+=("$clean_game_name")
            
            # Track if it uses .iso or .cue
            if [ "$has_iso_or_cue" -eq 1 ]; then
                iso_cue_games+=("$clean_game_name")
            fi
            
            echo "Created $m3u_file with the following discs:"
            cat "$m3u_file"
        elif [ "$num_disks" -gt 1 ] && [ "$m3u_created" -eq 1 ]; then
            echo "Skipping ${game} - .m3u file already created for this directory."
        else
            echo "Skipping ${game} - only one disc found."
        fi
    done
    
    # Rename the subdirectory to match the .m3u file if exactly one .m3u file was created
    if [ -n "$m3u_filename" ] && [ "$num_games" -eq 1 ]; then
        # Only rename if the current directory name doesn't already match the .m3u filename
        if [ "$original_dir_name" != "$m3u_filename" ]; then
            echo "Renaming directory from '$original_dir_name' to '$m3u_filename'"
            cd "$parent_dir" || return 1
            mv -- "$original_dir_name" "$m3u_filename"
        fi
    fi
    
    # Return to the original directory (cwd before processing)
    cd "$original_cwd" || return 1
    echo ""
}

# Main script: process each subdirectory
cwd=$(pwd)
found_dirs=0
skipped_dirs=0
declare -a processed_games=()
declare -a iso_cue_games=()

# Find all subdirectories in the current working directory
while IFS= read -r -d '' dir; do
    # Skip directories that already end in .m3u (already processed)
    dir_basename=$(basename "$dir")
    if [[ "$dir_basename" == *.m3u ]]; then
        echo "Skipping '$dir_basename' - directory already ends in .m3u (already processed)."
        ((skipped_dirs++))
        continue
    fi
    found_dirs=1
    process_directory "$dir"
done < <(find "$cwd" -mindepth 1 -maxdepth 1 -type d -print0)

# Print summary
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo "Directories skipped (already processed): $skipped_dirs"

if [ ${#processed_games[@]} -eq 0 ]; then
    echo "No games were processed (no multi-disc games found)."
else
    echo ""
    echo "Processed games (created .m3u files):"
    for game in "${processed_games[@]}"; do
        echo "  - $game"
    done
    
    if [ ${#iso_cue_games[@]} -gt 0 ]; then
        echo ""
        echo "WARNING: The following games use .iso or .cue format:"
        for game in "${iso_cue_games[@]}"; do
            echo "  - $game"
        done
        echo ""
        echo "Recommendation: Consider compressing these games to .chd format"
        echo "for better space efficiency and performance."
    fi
fi

if [ $found_dirs -eq 0 ]; then
    echo ""
    echo "No unprocessed subdirectories found (all directories already end in .m3u or no subdirectories exist)."
    exit 0
fi

# Exit the script
exit 0