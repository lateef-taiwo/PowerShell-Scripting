# PowerShell-Scripting
This repository contains PowerShell Scripts to automate daily IT administration tasks and is also useful for Cloud and DevOps Engineers 



https://we.tl/t-czEVliVweY



# Get current addresses
$addresses = (Get-ADUser 11052459 -Properties proxyAddresses).proxyAddresses

# Remove the specific address
$updatedAddresses = @()
foreach ($addr in $addresses) {
    if ($addr -ne "smtp:Weston.Davidson@seaworld.com") {
        $updatedAddresses += $addr
    }
}

# Set the updated addresses
Set-ADUser 11052459 -Replace @{proxyAddresses=$updatedAddresses}

# Verify the change
Get-ADUser 11052459 -Properties proxyAddresses | Select-Object -ExpandProperty proxyAddresses
