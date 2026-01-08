# PowerShell-Scripting
This repository contains PowerShell Scripts to automate daily IT administration tasks and is also useful for Cloud and DevOps Engineers 



https://we.tl/t-czEVliVweY



# Clear any variables first
Remove-Variable user1, proxyList -ErrorAction SilentlyContinue

# Use the filtering approach - this is more reliable
$currentAddresses = (Get-ADUser 11052459 -Properties proxyAddresses).proxyAddresses

# Filter out the address we want to remove
$newAddresses = $currentAddresses | Where-Object {$_ -ne "smtp:Weston.Davidson@seaworld.com"}

# Apply the changes
Set-ADUser 11052459 -Replace @{proxyAddresses=$newAddresses}

# Verify it worked
Get-ADUser 11052459 -Properties proxyAddresses | Select-Object -ExpandProperty proxyAddresses



------ NEW CODE ------


# Get current addresses
$currentAddresses = (Get-ADUser 11052459 -Properties proxyAddresses).proxyAddresses

# Build new array manually
$newAddresses = @()
foreach ($addr in $currentAddresses) {
    if ($addr -ne "smtp:Weston.Davidson@seaworld.com") {
        $newAddresses += $addr
    }
}

# Apply the changes
Set-ADUser 11052459 -Clear proxyAddresses
Set-ADUser 11052459 -Add @{proxyAddresses=$newAddresses}

# Verify
Get-ADUser 11052459 -Properties proxyAddresses | Select-Object -ExpandProperty proxyAddresses














Hey,

can you give me a suitable draw.io Architectural diagram with appropriate images of the Azure Services for building a Document Management system using this Architecture sketch below.


[Document Ingestion Sources]
   |        |        |
   |        |        |
 Email    Fax     Borrower Portal
   |        |        |
   v        v        v
[Azure Web App]
           |
           v
    [Azure API Management]
           |
           v
     [Azure Functions]
           |
           v
[Azure Data Lake Storage Gen2]
 (Raw / Encrypted Documents)
           |
           v
   [Fabric OneLake Shortcut]
           |
           v
[Fabric Lakehouse (Bronze)]
           |
           v
[Doc IQ Extraction Engine]
           |
           v
[Fabric Lakehouse (Silver)]
           |
           v
[Fabric Warehouse (SQL)]
           |
           v
[Azure Web App / Power BI]
