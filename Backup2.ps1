#Implement a business requirement by using Try/Catch
#Assume your company mostly builds web apps. 
#These apps consist of HTML, CSS, and JavaScript files. 
#You decide to optimize the script to recognize web apps.
#If the script detects that the source directory contains only HTML, CSS, and JavaScript files, it should continue.
#If the source directory does not contain these files, the script should throw an error.
#Use a Try/Catch block to implement this requirement.
#Add a switch parameter to the script to indicate whether the source directory is a web app.
#If the switch is present, the script should check the source directory for HTML, CSS, and JavaScript files.

Param(
     [string]$Path = './app',
     [string]$DestinationPath = './',
     [switch]$PathIsWebApp
   )

If ($PathIsWebApp -eq $True) {
   Try 
   {
     $ContainsApplicationFiles = "$((Get-ChildItem $Path).Extension | Sort-Object -Unique)" -match  '\.js|\.html|\.css'

If ( -Not $ContainsApplicationFiles) {
       Throw "Not a web app"
     } Else {
       Write-Host "Source files look good, continuing"
     }
   } Catch {
    Throw "No backup created due to: $($_.Exception.Message)"
   }
}

If(-Not (Test-Path $Path)) 
{
   Throw "The source directory $Path does not exist, please specify an existing directory"
}

$date = Get-Date -format "yyyy-MM-dd"

$DestinationFile = "$($DestinationPath + 'backup-' + $date + '.zip')"
If (-Not (Test-Path $DestinationFile)) 
{
  Compress-Archive -Path $Path -CompressionLevel 'Fastest' -DestinationPath "$($DestinationPath + 'backup-' + $date)"
  Write-Host "Created backup at $($DestinationPath + 'backup-' + $date + '.zip')"
} Else {
  Write-Error "Today's backup already exists"
}