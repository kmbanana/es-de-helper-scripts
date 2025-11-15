ENTIRELY VIBE CODED, ONLY USE IN SYSTEM FOLDERS OF ES-DE "ROMs" FOLDER.  DON'T EXECUTE SCRIPT WITHOUT A BACKUP OF YOUR DATA ELSEWHERE


Usage: Copy script file to the directory of a specific system of your ES-DE ROMs folder.  For example, /ROMs/PSX/
CD into that directory
Execute the script.  

.sh is for linux environments
.ps1 is a powershell script for windows systems
No mac script has been tested


"make-m3u" will look in subdirectories and find games with multiple disks.  If multiple disks are present it will generate an .m3u file for all disks and then rename the game folder to match the m3u file.  This will make ES-DE show the game folder as a single entry utilizing ES-DE's "Directory interpreted as file" mechanic.  
The script should be placed in and executed from the folder for a specific system within the ES-DE ROMs folder, for example "/ROMs/psx"
The script will not adjust folder names or create m3u files for folders with just a single disk inside
The script should work with chd, rvz, iso, and cue/bin based disks.  
The script will give a summary at the end of execution.  


"remove-unneeded-subdirectories" will look in subdirectories and if there is just one file, move it up a directory into the ES-DE systems folder and then remove the now empty subdirectory, reducing unnecessary clutter in your games list.  
The script should be placed in and executed from the folder for a specific system within the ES-DE ROMs folder, for example "/ROMs/psx"
