# #Backup the app folder to a zip file with the current date
# $date = Get-Date -format "yyyy-MM-dd"
# Compress-Archive -Path './app' -CompressionLevel 'Fastest' -DestinationPath "./backup-$date"
# Write-Host "Created backup at $('./backup-' + $date + '.zip')"


##Use parameters for source and Destination paths to make the script more flexible

# Param(
#   [string]$Path = '../app',
#   [string]$DestinationPath = '../'
# )
# $date = Get-Date -format "yyyy-MM-dd"
# Compress-Archive -Path $Path -CompressionLevel 'Fastest' -DestinationPath "$($DestinationPath + 'backup-' + $date)"
# Write-Host "Created backup at $($DestinationPath + 'backup-' + $date + '.zip')"


Param(
  [string]$Path = './app',
  [string]$DestinationPath = './'
)

#Add a check for the $Path parameter to ensure it is a valid directory 
If (-Not (Test-Path $Path)) 
{
  Throw "The source directory $Path does not exist, please specify an existing directory"
}
$date = Get-Date -format "yyyy-MM-dd"
$DestinationFile = "$($DestinationPath + 'backup-' + $date + '.zip')"

#Use If Else to ensure the backup is created only if no other backup zip file from the current day exists
If (-Not (Test-Path $DestinationFile)) 
{
  Compress-Archive -Path $Path -CompressionLevel 'Fastest' -DestinationPath "$($DestinationPath + 'backup-' + $date)"
  Write-Host "Created backup at $($DestinationPath + 'backup-' + $date + '.zip')"
} Else {
  Write-Error "Today's backup already exists"
}