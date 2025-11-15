# PowerShell script to remove unneeded subdirectories
# If a subdirectory contains only a single file, move that file up to the current directory
# and then remove the empty subdirectory.

# Error handling is done explicitly for each operation to prevent data loss

# Get the current working directory
$cwd = Get-Location

# Counter for processed directories
$processedCount = 0

# Array to track processed directories
$processedDirs = @()

# Array to track skipped files due to naming conflicts
$skippedFiles = @()

# Get all subdirectories (one level deep)
$subdirectories = Get-ChildItem -Path $cwd -Directory

foreach ($subdir in $subdirectories) {
    $subdirPath = $subdir.FullName
    
    # Get all items in the subdirectory (files and directories)
    $allItems = Get-ChildItem -Path $subdirPath -Force
    
    # Count visible files (non-hidden)
    $visibleFiles = Get-ChildItem -Path $subdirPath -File | Where-Object { -not $_.Attributes.HasFlag([System.IO.FileAttributes]::Hidden) }
    $visibleFileCount = ($visibleFiles | Measure-Object).Count
    
    # Count hidden files
    $hiddenFiles = Get-ChildItem -Path $subdirPath -File -Force | Where-Object { $_.Attributes.HasFlag([System.IO.FileAttributes]::Hidden) }
    $hiddenFileCount = ($hiddenFiles | Measure-Object).Count
    
    # Count subdirectories
    $subdirs = Get-ChildItem -Path $subdirPath -Directory
    $subdirCount = ($subdirs | Measure-Object).Count
    
    # Only process if there's exactly one visible file and nothing else
    if ($visibleFileCount -eq 1 -and $hiddenFileCount -eq 0 -and $subdirCount -eq 0) {
        # Get the single file
        $singleFile = $visibleFiles[0]
        $filename = $singleFile.Name
        $singleFilePath = $singleFile.FullName
        
        # Check if a file with the same name already exists in cwd
        # Do NOT overwrite existing files - skip this file and folder entirely
        $targetPath = Join-Path -Path $cwd -ChildPath $filename
        if (Test-Path -Path $targetPath -PathType Leaf) {
            Write-Host "Warning: File '$filename' already exists in '$cwd', skipping subdirectory '$subdirPath'"
            $skippedFiles += "$filename (in $subdirPath)"
            continue
        }
        
        # Move the file to the current directory
        Write-Host "Moving '$singleFilePath' to '$cwd/'"
        try {
            Move-Item -Path $singleFilePath -Destination $cwd -ErrorAction Stop
        }
        catch {
            Write-Host "Error: Failed to move '$singleFilePath', skipping directory removal"
            Write-Host "Error details: $_"
            continue
        }
        
        # Verify the directory is now empty before attempting to remove it
        $remainingItems = Get-ChildItem -Path $subdirPath -Force
        $remainingCount = ($remainingItems | Measure-Object).Count
        
        if ($remainingCount -eq 0) {
            # Remove the now-empty subdirectory
            Write-Host "Removing empty subdirectory '$subdirPath'"
            try {
                Remove-Item -Path $subdirPath -ErrorAction Stop
                $processedCount++
                $processedDirs += $subdirPath
            }
            catch {
                Write-Host "Warning: Failed to remove directory '$subdirPath' (may not be empty)"
                Write-Host "Error details: $_"
            }
        }
        else {
            Write-Host "Warning: Directory '$subdirPath' is not empty after moving file (contains $remainingCount item(s)), skipping removal"
        }
    }
}

# Print summary
Write-Host ""
Write-Host "=== Summary ==="
if ($processedCount -eq 0) {
    Write-Host "No subdirectories with a single file were processed."
}
else {
    Write-Host "Successfully processed $processedCount subdirectory(ies):"
    foreach ($dir in $processedDirs) {
        Write-Host "  - $dir"
    }
}

if ($skippedFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Files skipped due to naming conflicts (existing file in cwd):"
    foreach ($skipped in $skippedFiles) {
        Write-Host "  - $skipped"
    }
    Write-Host "Total skipped: $($skippedFiles.Count) file(s)"
}
else {
    Write-Host "No files were skipped due to naming conflicts."
}

