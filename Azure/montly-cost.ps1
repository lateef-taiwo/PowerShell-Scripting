$subscriptionId = "<SUBSCRIPTION_ID>"
$year = 2025

Connect-AzAccount -ErrorAction Stop
Set-AzContext -Subscription $subscriptionId -ErrorAction Stop

$scope = "/subscriptions/$subscriptionId"
$from = [datetime]"$year-07-01"
$to   = [datetime]"$year-10-01"

$result = Get-AzCostManagementQuery -Scope $scope -Type ActualCost -Timeframe Custom `
  -TimePeriodFrom $from -TimePeriodTo $to -DatasetGranularity Monthly `
  -DatasetAggregation @{ totalCost = @{ Name = 'Cost'; Function = 'Sum' } }

$rows = foreach ($r in $result.Rows) {
  $m = [datetime]::ParseExact($r[0].ToString(),'yyyyMM',$null).ToString('yyyy-MM')
  [pscustomobject]@{ Month=$m; Cost=[math]::Round($r[1],2); Currency=$r[2] }
} | Sort-Object Month

$rows | Format-Table -AutoSize
$total = ($rows | Measure-Object Cost -Sum).Sum
Write-Host "`nTOTAL (Jul–Sep): $total $($rows[0].Currency)" -ForegroundColor Cyan
$rows | Export-Csv "azure-cost-jul-sep-$year.csv" -NoTypeInformation
