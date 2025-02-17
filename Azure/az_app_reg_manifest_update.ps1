# Define Variables
$tenantId = "<your-tenant-id>"
$subscriptionId = "<your-subscription-id>"
$resourceGroup = "<your-resource-group>"
$keyVaultName = "<your-keyvault-name>"
$appName = "<your-app-name>"
$scopeName = "access_as_user"

# Enable Error Handling
$ErrorActionPreference = "Stop"

function Log-Info($message) {
    Write-Host "[INFO] $message" -ForegroundColor Cyan
}

function Log-Error($message) {
    Write-Host "[ERROR] $message" -ForegroundColor Red
    exit 1  # Exit on failure
}

# Authenticate to Azure
try {
    Log-Info "Logging in to Azure..."
    Connect-AzAccount -TenantId $tenantId -SubscriptionId $subscriptionId -ErrorAction Stop
} catch {
    Log-Error "Failed to log in. $_"
}

# Create App Registration
try {
    Log-Info "Creating App Registration: $appName..."
    $app = New-AzADApplication -DisplayName $appName -ErrorAction Stop
    Log-Info "App created successfully. App ID: $($app.AppId)"
} catch {
    Log-Error "Failed to create App Registration. $_"
}

# Create Service Principal
try {
    Log-Info "Creating Service Principal..."
    $sp = New-AzADServicePrincipal -ApplicationId $app.AppId -ErrorAction Stop
    Log-Info "Service Principal created: $($sp.Id)"
} catch {
    Log-Error "Failed to create Service Principal. $_"
}

# Generate and Store Client Secret
try {
    Log-Info "Generating client secret..."
    $secret = New-AzADAppCredential -ApplicationId $app.AppId -EndDate (Get-Date).AddYears(1) -ErrorAction Stop
    $secretValue = ConvertTo-SecureString $secret.SecretText -AsPlainText -Force

    Log-Info "Storing secret in Key Vault..."
    Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "$appName-ClientSecret" -SecretValue $secretValue -ErrorAction Stop
    Log-Info "Client secret stored successfully in Key Vault."
} catch {
    Log-Error "Failed to generate/store client secret. $_"
}

# Update Manifest (Add API Scopes)
try {
    Log-Info "Updating app manifest with API scopes..."
    $manifest = Get-AzADApplication -ApplicationId $app.AppId
    $apiId = $app.AppId

    $updatedManifest = @{
        identifierUris = @("api://$apiId")
        api = @{
            oauth2PermissionScopes = @(
                @{
                    adminConsentDescription = "Allows access to the app"
                    adminConsentDisplayName = "Access $appName"
                    id = (New-Guid).Guid
                    isEnabled = $true
                    type = "User"
                    userConsentDescription = "Allows the app to act on your behalf."
                    userConsentDisplayName = "Access $appName"
                    value = $scopeName
                }
            )
        }
    }

    Update-AzADApplication -ApplicationId $app.AppId -Set $updatedManifest -ErrorAction Stop
    Log-Info "Manifest updated successfully."
} catch {
    Log-Error "Failed to update the manifest. $_"
}

# Assign API Permissions
try {
    Log-Info "Assigning API permissions..."
    $graphAppId = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph App ID
    $userReadPermissionId = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read permission ID

    New-AzADAppPermission -ApplicationId $app.AppId -ResourceAppId $graphAppId -PermissionId $userReadPermissionId -ErrorAction Stop
    Log-Info "API permissions assigned successfully."
} catch {
    Log-Error "Failed to assign API permissions. $_"
}

# Grant Admin Consent
try {
    Log-Info "Granting admin consent..."
    Start-Sleep -Seconds 5
    $sp = Get-AzADServicePrincipal -ApplicationId $app.AppId
    $spConsent = New-Object -TypeName Microsoft.Azure.Commands.ActiveDirectory.PSADServicePrincipal
    $spConsent.ObjectId = $sp.Id
    $spConsent.AppRoleAssignments = @(@{
        ResourceId = (Get-AzADServicePrincipal -ApplicationId $graphAppId).Id
        Id = $userReadPermissionId
    })
    Log-Info "Admin consent granted successfully."
} catch {
    Log-Error "Failed to grant admin consent. $_"
}

Log-Info "Automation completed successfully!"
