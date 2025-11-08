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
