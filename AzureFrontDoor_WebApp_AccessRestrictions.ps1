###The sample scripts are not supported under any Microsoft standard support program or service. The sample scripts are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages.

### AzureFrontDoor_WebApp_AccessRestrictions.ps1 ###
### Authored by Travis Cook (tracook) ########################
### Last Modified on 7/9/2020 ################################

#Variables
$subId = "bdd7aa9d-da5f-4260-ad66-1830d3c798c3"
$webAppname = "myhc"
$resourceGroupName = "MyHealthClinicRG01"
$rulePriority = "200"
$outputPath = "C:\Users\getittwistd\OneDrive - Microsoft\Scripts\Azure\FrontDoor\IP_Ranges_"+$date+".json"
$date = Get-Date -Format MM-dd-yyyy
$url = "https://download.microsoft.com/download/7/1/D/71D86715-5596-4529-9B13-DA13A5DE5B63/ServiceTags_Public_20200706.json"

#Set Installation Policy
$repo = Get-PSRepository -Name "PSGallery"
$policy = $repo.InstallationPolicy

if ($policy -ne "Trusted")
    {
        Write-Host "Setting Installation Policy for PSGallery repo to Trusted..."
        Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
    }

#Import BitsTransfer Module
if ($null -eq (Get-Module 'BitsTransfer' -ea 0))
    {
        Write-Host "Importing BitsTransfer Module..."
        Import-Module -Name BitsTransfer
    }

#Download JSON file containing IP ranges
$fileCheck = [System.IO.File]::Exists($outputPath)

if ($fileCheck -ne $true)
{
    Write-Host "Downloading JSON file containing IP ranges from Microsoft..."

    try
    {
        Start-BitsTransfer -Source $url -Destination $outputPath    
    }
    catch
    {
        $_ | Format-List * -Force
        $_.Exception.Message  
    }
}

#Import JSON and convert to PSObject and create array for Front Door Backend IP ranges
Write-Host "Converting JSON to PSObject and creating array of backend IP ranges for AzureFrontDoor.Backend..."

try
{
    $ipRanges = Get-Content $outputPath | ConvertFrom-Json
    $frontDoorBackend = $ipRanges.Values | ? {$_.Name -eq "AzureFrontDoor.Backend"}
    $frontDoorBackendRanges = $frontDoorBackend.Properties.AddressPrefixes
}
catch
{
    $_ | Format-List * -Force
    $_.Exception.Message 
}

#get context
Write-Host "Checking for correct Azure Subscription Context..."
$subIdCheck = (Get-AzContext).Subscription.Id

if ($subIdCheck -ne $subId)
{
    $sub = Get-AzSubscription -SubscriptionId $subId
    $context = Set-AzContext -SubscriptionObject $sub
    Write-Host "Context set to correct subscription"
    Write-Host $context
}
else
{
    Write-Host "Azure Subscription Context is correct"    
}

#get-webapp
$webApp = Get-AzWebApp `
            -ResourceGroupName $resourceGroupName `
            -Name $webAppname;

#set access restrictions to allow Front Door Ip ranges
Write-Host "Checking to see if rules already exist on Web App $webAppName and adding rules that don't exist..."

ForEach ($range in $frontDoorBackendRanges)
{
    Write-Host "Checking if rule for $range exists..."
    
    #check if rule exists
    $ruleCheck = (Get-AzWebAppAccessRestrictionConfig -ResourceGroupName $resourceGroupName -Name $webAppname).MainSiteAccessRestrictions | ? {$_.Action -eq "Allow" -and $_.IpAddress -eq $range}

    if ($null -eq $ruleCheck)
    {
        $ruleName = "AFD BE Range $range"
        Write-Host "Adding rule for $range"

        try
        {
            Add-AzWebAppAccessRestrictionRule `
                -ResourceGroupName $resourceGroupName `
                -WebAppName $webApp.Name `
                -Name $ruleName `
                -Priority $rulePriority `
                -Action Allow `
                -IpAddress $range;
        }
        catch
        {
            $_ | Format-List * -Force
            $_.Exception.Message  
        }
    }

    else
    {
        Write-Host "Rule for $range already exists.  Skipping this rule..." -ForegroundColor Yellow    
    }
}

#Set access restrictions to allow Azure Basic Infrastructure Services (required for DHCP, DNS, IMDS, and health monitoring)
$bisIPs = @()
$bisIPs += "168.63.129.16/32"
$bisIPs += "169.254.169.254/32"

ForEach ($ip in $bisIPs)
{
    Write-Host "Checking if rule for $ip exists..."

    $ruleCheck = (Get-AzWebAppAccessRestrictionConfig -ResourceGroupName $resourceGroupName -Name $webAppname).MainSiteAccessRestrictions | ? {$_.Action -eq "Allow" -and $_.IpAddress -eq $ip}

    if ($null -eq $ruleCheck)
    {
        $ruleName = "BIS IP $ip"
        Write-Host "Adding rule for $ip"

        try
        {
            Add-AzWebAppAccessRestrictionRule `
                -ResourceGroupName $resourceGroupName `
                -WebAppName $webApp.Name `
                -Name $ruleName `
                -Priority $rulePriority `
                -Action Allow `
                -IpAddress $ip;
        }
        catch
        {
            $_ | Format-List * -Force
            $_.Exception.Message  
        }
    }
}

Write-Host "Script Complete" -ForegroundColor Green