# CreateFile.ps1
Param (
  $Path
)
New-Item $Path # Creates a new file at $Path.
Write-Host "File $Path was created"


#Use If/Else construct to check the value of a parameter and then decide what to do.
Param(
   $Path
)
If (-Not $Path -eq '') {
   New-Item $Path
   Write-Host "File created at path $Path"
} Else {
   Write-Error "Path cannot be empty"
}


#Use the Parameter[] decorator. A better way, which requires less typing,
# is to use the Parameter[] decorator:

Param(
   [Parameter(Mandatory)]
   $Path
)
New-Item $Path
Write-Host "File created at path $Path"

#OR 
#improve the decorator by providing a Help message users will see when they run the script:

Param(
   [Parameter(Mandatory, HelpMessage = "Please provide a valid path")]
   $Path
)
New-Item $Path
Write-Host "File created at path $Path"

# Assign a type. If you assign a type to a parameter, 
#you can say, for example, that the parameter accepts only strings, not Booleans.
Param(
   [string]$Path
)