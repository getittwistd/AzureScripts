### The sample scripts are not supported under any Microsoft standard support program or service. The sample scripts are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages. ###
### GetFunctionMetrics.ps1 ###
### tracook@microsoft.com ####
### 09/01/2018 ###############

#Edit these variables to reflect the start and end times of the period for which you wish to collect metrics
$startTime = "2020-08-01T00:00:00Z"
$endTime = "2020-08-31T23:59:59Z"
$timeGrain = "12:00:00"

#Edit this variable to match the name of the subscription you wish to run the script against
$subName = "Microsoft Azure Internal Consumption"

#Get the context of the susbcription
$sub = Get-AzSubscription | ? {$_.Name -eq $subName}
$context = Set-AzContext -SubscriptionObject $sub
Write-Host "Checking metrics for all Function Apps in subscription:" $context.name

#Create initial arrays for metric data
$counts = @()
$units = @()

#Get the list of function apps in the subscription
$functions = Get-AzFunctionApp

#Iterate against the function apps in the subscription and collect metrics
forEach ($fn in $functions)
{
    $metric1 = Get-AzMetric -ResourceId $fn.id -MetricName "FunctionExecutionCount" -StartTime $startTime -EndTime $endTime -TimeGrain $timeGrain -WarningAction SilentlyContinue
    $metric2 = Get-AzMetric -ResourceId $fn.id -MetricName "FunctionExecutionUnits" -StartTime $startTime -EndTime $endTime -TimeGrain $timeGrain -WarningAction SilentlyContinue
    $feCount = $metric1.data.total
    $feUnits = $metric2.data.total

    $counts += $feCount
    $units += $feUnits
}

#Create variables to hold total metrics
$totalExecutionCount = 0
$totalExecutionUnits = 0

#Iterate against collected metrics and add to total variables
ForEach ($count in $counts)
{
    $totalExecutionCount += $count
}

ForEach ($unit in $units)
{
    $totalExecutionUnits += $unit
}

#Divide Total Execution Units by 1024000 to get GB-s
$totalExecutionTime = $totalExecutionUnits/1024000

#Write final metric totals console
Write-Host "Total Executions: $totalExecutionCount"
Write-Host "Total Execution Time: $totalExecutionTime" GB-s