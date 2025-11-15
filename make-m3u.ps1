# PowerShell script to generate .m3u playlist files for multi-disc games in ES-DE

# Function to get the base game name (without disc number, rev/ver info, and extension)
function Get-Basename {
    param(
        [string]$Filename
    )
    
    # Remove extension first
    $filename = $Filename -replace '\.(chd|rvz|iso|cue|bin)$', ''
    
    # Remove (Disc/Disk/CD N) patterns - handle with or without spaces, fully case insensitive
    # Also handle patterns without parentheses/brackets (e.g., "Disk1" or "Disk 1")
    # Also handle patterns with descriptive text after the number (e.g., "Disc 1 - Description")
    # Match disc/Disc/DISC and disk/Disk/DISK (all case combinations)
    # Pattern with parentheses: (Disc 1), (Disc1), (DISK 2), (Disc 1 - Description), etc.
    $filename = $filename -replace '\s*\([Dd][Ii][Ss][Cc]\s*\d+[^)]*\)\s*', ''
    $filename = $filename -replace '\s*\([Dd][Ii][Ss][Kk]\s*\d+[^)]*\)\s*', ''
    # Pattern with square brackets: [Disc 1], [Disc1], [DISK 2], [Disc 1 - Description], etc.
    $filename = $filename -replace '\s*\[[Dd][Ii][Ss][Cc]\s*\d+[^\]]*\]\s*', ''
    $filename = $filename -replace '\s*\[[Dd][Ii][Ss][Kk]\s*\d+[^\]]*\]\s*', ''
    # Pattern without parentheses: Disk 1, Disk1, DISK 2, etc.
    $filename = $filename -replace '\s+[Dd][Ii][Ss][Cc]\s*\d+\s*', ''
    $filename = $filename -replace '\s+[Dd][Ii][Ss][Kk]\s*\d+\s*', ''
    # Match cd/CD/Cd/cD (all case combinations) with parentheses (including descriptive text)
    $filename = $filename -replace '\s*\([Cc][Dd]\s*\d+[^)]*\)\s*', ''
    # Match cd/CD/Cd/cD with square brackets (including descriptive text)
    $filename = $filename -replace '\s*\[[Cc][Dd]\s*\d+[^\]]*\]\s*', ''
    # Match cd/CD/Cd/cD without parentheses/brackets
    $filename = $filename -replace '\s+[Cc][Dd]\s*\d+\s*', ''
    # Remove (Rev N) patterns - handle with or without spaces (including descriptive text)
    $filename = $filename -replace '\s*\([Rr]ev\s*\d+[^)]*\)\s*', ''
    # Remove [Rev N] patterns with square brackets
    $filename = $filename -replace '\s*\[[Rr]ev\s*\d+[^\]]*\]\s*', ''
    # Remove (Ver N) patterns - handle with or without spaces (including descriptive text)
    $filename = $filename -replace '\s*\([Vv]er\s*\d+[^)]*\)\s*', ''
    # Remove [Ver N] patterns with square brackets
    $filename = $filename -replace '\s*\[[Vv]er\s*\d+[^\]]*\]\s*', ''
    # Clean up trailing spaces and dots
    $filename = $filename -replace '\s+$', ''
    $filename = $filename -replace '\.+$', ''
    
    return $filename
}

# Function to process files in a given directory
function Process-Directory {
    param(
        [string]$Dir,
        [ref]$ProcessedGames,
        [ref]$IsoCueGames
    )
    
    $originalDirName = Split-Path -Leaf $Dir
    $parentDir = Split-Path -Parent $Dir
    $originalCwd = Get-Location
    
    Write-Host "Processing directory: $Dir"
    Write-Host "----------------------------------------"
    
    # Change to the directory
    Set-Location $Dir
    
    # Check if there are any .chd, .rvz, .iso, or .cue files in the current directory
    # Note: We exclude .bin files from counting as they are paired with .cue files
    $files = Get-ChildItem -Path $Dir -File | Where-Object {
        $_.Extension -match '\.(chd|rvz|iso|cue)$'
    } | Select-Object -ExpandProperty Name
    
    if ($files.Count -eq 0) {
        Write-Host "No .chd, .rvz, .iso, or .cue files found in $Dir."
        Set-Location $originalCwd
        return
    }
    
    # If there's only one file, it's definitely a single-disc game - skip processing
    if ($files.Count -eq 1) {
        Write-Host "Only one .chd, .rvz, .iso, or .cue file found in $Dir - skipping (single disc game)."
        Set-Location $originalCwd
        return
    }
    
    # Process each .chd, .rvz, .iso, or .cue file and group by base name
    $games = @{}
    foreach ($file in $files) {
        $basename = Get-Basename -Filename $file
        Write-Host "Processing file: '$file' (Base name: '$basename')"  # Debugging output
        if (-not $games.ContainsKey($basename)) {
            $games[$basename] = @()
        }
        $games[$basename] += $file
    }
    
    # Determine how many unique games we have
    $numGames = $games.Keys.Count
    
    # Process each game - create .m3u file for multi-disc games
    # Track if we've already created an .m3u file to ensure only one per directory
    $m3uFilename = $null
    $m3uCreated = $false
    
    foreach ($game in $games.Keys) {
        # Count actual files in the directory that match this game's basename
        # This is the most reliable way to count discs
        $matchingFiles = @()
        foreach ($file in $files) {
            $fileBasename = Get-Basename -Filename $file
            if ($fileBasename -eq $game) {
                $matchingFiles += $file
            }
        }
        
        # Sort the disk list
        $matchingFiles = $matchingFiles | Sort-Object
        
        $numDisks = $matchingFiles.Count
        
        Write-Host "Game: '$game', Number of Discs: $numDisks"  # Debugging output
        
        # Only create .m3u file if there is more than one disc AND we haven't created one yet
        if ($numDisks -gt 1 -and -not $m3uCreated) {
            # Clean up game name for file creation
            $cleanGameName = $game -replace '\s+$', ''
            $cleanGameName = $cleanGameName -replace '\.(chd|rvz|iso|cue|bin)$', ''
            
            # Check if this game uses .iso or .cue files
            $hasIsoOrCue = $false
            foreach ($file in $files) {
                $fileBasename = Get-Basename -Filename $file
                if ($fileBasename -eq $game) {
                    if ($file -match '\.(iso|ISO|cue|CUE)$') {
                        $hasIsoOrCue = $true
                        break
                    }
                }
            }
            
            # Create the .m3u file in the current directory (don't move any files)
            $m3uFilename = "${cleanGameName}.m3u"
            # Use just the filename since we're already in the directory
            $m3uFile = $m3uFilename
            
            # Write the full filenames (with extensions) to the .m3u file
            # Note: .cue files reference their .bin files internally, so we only list .cue files
            # Use -LiteralPath to handle filenames with special characters like square brackets
            $matchingFiles | Where-Object { $_ } | ForEach-Object {
                Add-Content -LiteralPath $m3uFile -Value $_
            }
            
            $m3uCreated = $true
            
            # Track this processed game
            $ProcessedGames.Value += $cleanGameName
            
            # Track if it uses .iso or .cue
            if ($hasIsoOrCue) {
                $IsoCueGames.Value += $cleanGameName
            }
            
            $fullM3uPath = Join-Path (Get-Location) $m3uFile
            Write-Host "Created $fullM3uPath with the following discs:"
            Get-Content -LiteralPath $m3uFile | ForEach-Object { Write-Host $_ }
        }
        elseif ($numDisks -gt 1 -and $m3uCreated) {
            Write-Host "Skipping ${game} - .m3u file already created for this directory."
        }
        else {
            Write-Host "Skipping ${game} - only one disc found."
        }
    }
    
    # Rename the subdirectory to match the .m3u file if exactly one .m3u file was created
    if ($null -ne $m3uFilename -and $numGames -eq 1) {
        # Only rename if the current directory name doesn't already match the .m3u filename
        if ($originalDirName -ne $m3uFilename) {
            Write-Host "Renaming directory from '$originalDirName' to '$m3uFilename'"
            Set-Location $parentDir
            # Use -LiteralPath to handle directory names with special characters like square brackets
            Rename-Item -LiteralPath $originalDirName -NewName $m3uFilename
        }
    }
    
    # Return to the original directory (cwd before processing)
    Set-Location $originalCwd
    Write-Host ""
}

# Main script: process each subdirectory
$cwd = Get-Location
$foundDirs = $false
$skippedDirs = 0
$processedGames = @()
$isoCueGames = @()

# Find all subdirectories in the current working directory
$subdirs = Get-ChildItem -Path $cwd -Directory

foreach ($dir in $subdirs) {
    # Skip directories that already end in .m3u (already processed)
    $dirBasename = $dir.Name
    if ($dirBasename -match '\.m3u$') {
        Write-Host "Skipping '$dirBasename' - directory already ends in .m3u (already processed)."
        $skippedDirs++
        continue
    }
    $foundDirs = $true
    Process-Directory -Dir $dir.FullName -ProcessedGames ([ref]$processedGames) -IsoCueGames ([ref]$isoCueGames)
}

# Print summary
Write-Host "========================================"
Write-Host "SUMMARY"
Write-Host "========================================"
Write-Host "Directories skipped (already processed): $skippedDirs"

if ($processedGames.Count -eq 0) {
    Write-Host "No games were processed (no multi-disc games found)."
}
else {
    Write-Host ""
    Write-Host "Processed games (created .m3u files):"
    foreach ($game in $processedGames) {
        Write-Host "  - $game"
    }
    
    if ($isoCueGames.Count -gt 0) {
        Write-Host ""
        Write-Host "WARNING: The following games use .iso or .cue format:"
        foreach ($game in $isoCueGames) {
            Write-Host "  - $game"
        }
        Write-Host ""
        Write-Host "Recommendation: Consider compressing these games to .chd format"
        Write-Host "for better space efficiency and performance."
    }
}

if (-not $foundDirs) {
    Write-Host ""
    Write-Host "No unprocessed subdirectories found (all directories already end in .m3u or no subdirectories exist)."
}

# Exit the script
exit 0

