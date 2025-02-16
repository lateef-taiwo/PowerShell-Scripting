# #Backup the app folder to a zip file with the current date
# $date = Get-Date -format "yyyy-MM-dd"
# Compress-Archive -Path './app' -CompressionLevel 'Fastest' -DestinationPath "./backup-$date"
# Write-Host "Created backup at $('./backup-' + $date + '.zip')"


#Use parameters for source and Destination paths to make the script more flexible

Param(
  [string]$Path = '../app',
  [string]$DestinationPath = '../'
)
$date = Get-Date -format "yyyy-MM-dd"
Compress-Archive -Path $Path -CompressionLevel 'Fastest' -DestinationPath "$($DestinationPath + 'backup-' + $date)"
Write-Host "Created backup at $($DestinationPath + 'backup-' + $date + '.zip')"