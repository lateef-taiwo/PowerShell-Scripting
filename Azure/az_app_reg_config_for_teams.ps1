#Automate the App registration configuration for Teams Tabs SSO

[CmdletBinding()]
 param(
     [Parameter(Mandatory=$true, HelpMessage='Object identifier of application on which you want to configure the Teams Tab SSO')]
     [string] $applicationObjectId,
     [Parameter(Mandatory=$true, HelpMessage='Custom domain where you site hosting the teams tab is accessible.')]
     [string] $customDomainName
 )
 
 <#.Description
     This function configures the SSO on an existing app registration in Active Directory
 #>  
 function ConfigureSSOOnApplication([string] $tenantId, [string] $applicationObjectId)
 {
     $app = Get-AzureADMSApplication -ObjectId $applicationObjectId
     
     # Do nothing if the app has already been configured
     if ($app.IdentifierUris.Count -gt 0) {
         Write-Host "Exiting, application already configured."
         return
     }
 
     # Expose an API
     $appId = $app.AppId
     Set-AzureADMSApplication -ObjectId $app.Id -IdentifierUris "api://$customDomainName/$appId"
     Write-Host "App URI set."
 
     # Create Service Principal from Application
     New-AzureADServicePrincipal -AppId $app.AppId -Tags {WindowsAzureActiveDirectoryIntegratedApp}
     Write-Host "Service Principal created."
 
     # Create access_as_user scope
     # Add all existing scopes first
     $scopes = New-Object System.Collections.Generic.List[Microsoft.Open.MsGraph.Model.PermissionScope]
     $app.Api.Oauth2PermissionScopes | foreach-object { $scopes.Add($_) }
     $scope = CreateScope -value "access_as_user"  `
         -userConsentDisplayName "Teams can access the user’s profile"  `
         -userConsentDescription "Allows Teams to call the app’s web APIs as the current user."  `
         -adminConsentDisplayName "Teams can access your user profile and make requests on your behalf"  `
         -adminConsentDescription "Enable Teams to call this app’s APIs with the same rights that you have"
     $scopes.Add($scope)
     $app.Api.Oauth2PermissionScopes = $scopes
     Set-AzureADMSApplication -ObjectId $app.Id -Api $app.Api
     Write-Host "Scope access_as_user added."
 
     # Authorize Teams mobile/desktop client and Teams web client to access API
     $preAuthorizedApplications = New-Object 'System.Collections.Generic.List[Microsoft.Open.MSGraph.Model.PreAuthorizedApplication]'
     $teamsRichClienPreauthorization = CreatePreAuthorizedApplication `
         -applicationIdToPreAuthorize '1fec8e78-bce4-4aaf-ab1b-5451cc387264' `
         -scopeId $scope.Id
     $teamsWebClienPreauthorization = CreatePreAuthorizedApplication `
         -applicationIdToPreAuthorize '5e3ce6c0-2b1f-4285-8d4b-75ee78787346' `
         -scopeId $scope.Id
     $preAuthorizedApplications.Add($teamsRichClienPreauthorization)
     $preAuthorizedApplications.Add($teamsWebClienPreauthorization)   
     $app = Get-AzureADMSApplication -ObjectId $applicationObjectId
     $app.Api.PreAuthorizedApplications = $preAuthorizedApplications
     Set-AzureADMSApplication -ObjectId $app.Id -Api $app.Api
     Write-Host "Teams mobile/desktop and web clients applications pre-authorized."
 
     # Add API permissions needed
     $requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Open.MsGraph.Model.RequiredResourceAccess]
     $requiredPermissions = GetRequiredPermissions `
         -applicationDisplayName 'Microsoft Graph' `
         -requiredDelegatedPermissions "User.Read|email|offline_access|openid|profile"
     $requiredResourcesAccess.Add($requiredPermissions)   
     Set-AzureADMSApplication -ObjectId $app.Id -RequiredResourceAccess $requiredPermissions
     Write-Host "Microsoft Graph permissions added."
 }
 
 <#.Description
    This function creates a new Azure AD scope (OAuth2Permission) with default and provided values
 #>  
 function CreateScope(
     [string] $value,
     [string] $userConsentDisplayName,
     [string] $userConsentDescription,
     [string] $adminConsentDisplayName,
     [string] $adminConsentDescription)
 {
     $scope = New-Object Microsoft.Open.MsGraph.Model.PermissionScope
     $scope.Id = New-Guid
     $scope.Value = $value
     $scope.UserConsentDisplayName = $userConsentDisplayName
     $scope.UserConsentDescription = $userConsentDescription
     $scope.AdminConsentDisplayName = $adminConsentDisplayName
     $scope.AdminConsentDescription = $adminConsentDescription
     $scope.IsEnabled = $true
     $scope.Type = "User"
     return $scope
 }
 
 <#.Description
    This function creates a new PreAuthorized application on a specified scope
 #>  
 function CreatePreAuthorizedApplication(
     [string] $applicationIdToPreAuthorize,
     [string] $scopeId)
 {
     $preAuthorizedApplication = New-Object 'Microsoft.Open.MSGraph.Model.PreAuthorizedApplication'
     $preAuthorizedApplication.AppId = $applicationIdToPreAuthorize
     $preAuthorizedApplication.DelegatedPermissionIds = @($scopeId)
     return $preAuthorizedApplication
 }
 
 #
 # Example: GetRequiredPermissions "Microsoft Graph"  "Graph.Read|User.Read"
 # See also: http://stackoverflow.com/questions/42164581/how-to-configure-a-new-azure-ad-application-through-powershell
 function GetRequiredPermissions(
     [string] $applicationDisplayName,
     [string] $requiredDelegatedPermissions,
     [string]$requiredApplicationPermissions,
     $servicePrincipal)
 {
     # If we are passed the service principal we use it directly, otherwise we find it from the display name (which might not be unique)
     if ($servicePrincipal)
     {
         $sp = $servicePrincipal
     }
     else
     {
         $sp = Get-AzureADServicePrincipal -Filter "DisplayName eq '$applicationDisplayName'"
     }
 
     $requiredAccess = New-Object Microsoft.Open.MsGraph.Model.RequiredResourceAccess
     $requiredAccess.ResourceAppId = $sp.AppId 
     $requiredAccess.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.MsGraph.Model.ResourceAccess]
 
     # $sp.Oauth2Permissions | Select Id,AdminConsentDisplayName,Value: To see the list of all the Delegated permissions for the application:
     if ($requiredDelegatedPermissions)
     {
         AddResourcePermission $requiredAccess -exposedPermissions $sp.Oauth2Permissions -requiredAccesses $requiredDelegatedPermissions -permissionType "Scope"
     }
     
     # $sp.AppRoles | Select Id,AdminConsentDisplayName,Value: To see the list of all the Application permissions for the application
     if ($requiredApplicationPermissions)
     {
         AddResourcePermission $requiredAccess -exposedPermissions $sp.AppRoles -requiredAccesses $requiredApplicationPermissions -permissionType "Role"
     }
     return $requiredAccess
 }
 
 # Adds the requiredAccesses (expressed as a pipe separated string) to the requiredAccess structure
 # The exposed permissions are in the $exposedPermissions collection, and the type of permission (Scope | Role) is 
 # described in $permissionType
 function AddResourcePermission(
     $requiredAccess,
     $exposedPermissions,
     [string]$requiredAccesses,
     [string]$permissionType)
 {
         foreach($permission in $requiredAccesses.Trim().Split("|"))
         {
             foreach($exposedPermission in $exposedPermissions)
             {
                 if ($exposedPermission.Value -eq $permission)
                 {
                     $resourceAccess = New-Object Microsoft.Open.MsGraph.Model.ResourceAccess
                     $resourceAccess.Type = $permissionType # Scope = Delegated permissions | Role = Application permissions
                     $resourceAccess.Id = $exposedPermission.Id # Read directory data
                     $requiredAccess.ResourceAccess.Add($resourceAccess)
                 }
             }
         }
 }
 
 # Pre-requisites
 if ($null -eq (Get-Module -ListAvailable -Name "AzureAD")) { 
     Install-Module -Name "AzureAD" -Force
 }
 
 Import-Module AzureAD
 
 $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
 $graphToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.microsoft.com").AccessToken
 $aadToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.windows.net").AccessToken
 Connect-AzureAD -AadAccessToken $aadToken -MsAccessToken $graphToken -AccountId $context.Account.Id -TenantId $context.tenant.id
 
 # Comment the 4 above lines and uncomment the line below for local debugging
 # Connect-AzureAD -TenantId '********-****-****-****-************'
 
 Connect-AzureAD
 $token = [Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens['AccessToken']
 
 ConfigureSSOOnApplication -applicationObjectId $applicationObjectId -tenantId $context.tenant.id

 #https://learn.microsoft.com/en-us/answers/questions/29893/azure-ad-teams-dev-how-to-automate-the-app-registr?orderBy=Oldest