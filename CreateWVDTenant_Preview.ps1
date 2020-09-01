### CreateWVDTenant_Preview.ps1 ###

# Variables
$subId = "5eb083df-5ec3-4528-b375-cf65ac1c829d"
$aadTenantId = "5c054e7f-bb88-4410-9397-07bd0440ea70"
$wvdTenantName = "tc-wvd-demo-tenant02"
$outputFile = "C:\Users\getittwistd\OneDrive - Microsoft\Scripts\Azure\WVD\OuputWVDTenantInfo3.txt"

#Install modules
$repo = Get-PSRepository -Name "PSGallery"
$policy = $repo.InstallationPolicy

if ($policy -ne "Trusted")
    {
        Write-Host "Setting Installation Policy for PSGallery repo to Trusted..."
        Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
    }

if((Get-Module 'Microsoft.RDInfra.RDPowerShell' -ea 0) -eq $null)
    {
        Write-Host "Installing\Importing WVD Module..."
        Install-Module -Name Microsoft.RDInfra.RDPowerShell -Confirm:$false
        Import-Module -Name Microsoft.RDInfra.RDPowerShell
    }

if((Get-Module 'AzureAD' -ea 0) -eq $null)
    {
        Write-Host "Installing\Importing AAD Module..."
        Install-Module -Name AzureAD -Confirm:$false
        Import-Module -Name AzureAD
    }


#Create Tenant 
try
    {
        Write-Host 'Creating the WVD tenant...'
        Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com"
        New-RdsTenant -Name $wvdTenantName -AadTenantId $aadTenantId -AzureSubscriptionId $subId
    }
catch
    {
        $_ | Format-List * -Force
        $_.Exception.Message
    }

#Create Service Principal
try
    {
        Write-Host "Creating the Service Principal..."
        $aadContext = Connect-AzureAD
        $svcPrincipal = New-AzureADApplication -AvailableToOtherTenants $true -DisplayName "Windows Virtual Desktop Svc Principal"
        $svcPrincipalCreds = New-AzureADApplicationPasswordCredential -ObjectId $svcPrincipal.ObjectId
    }
catch
    {
        $_ | Format-List * -Force
        $_.Exception.Message
    }

#Create Role Assignment in WVD
try
    {
        Write-Host "Assigning the RDS Owner Role to the Service Principal..."
        New-RdsRoleAssignment -RoleDefinitionName "RDS Owner" -ApplicationId $svcPrincipal.AppId -TenantName $wvdTenantName
    }
catch
    {
        $_ | Format-List * -Force
        $_.Exception.Message
    }

#Output Creds
Write-Host "Outputting Creds, Tenant ID, AppId..."

$creds = $svcPrincipalCreds.Value
Write-Host $creds -ForegroundColor Yellow
$tenantID = $aadContext.TenantId.Guid
Write-Host $tenantID -ForegroundColor Yellow
$appId = $svcPrincipal.AppId
Write-Host $appId

$credArray = @()
$credArray += "Credentials: $creds"
$credArray += "Tenant ID: $tenantID"
$credArray += "App ID: $appid"

$credArray | Out-File $outputFile



