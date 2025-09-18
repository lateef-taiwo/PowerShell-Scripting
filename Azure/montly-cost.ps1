# ===== Azure Cost for July–September (single subscription) =====

$subscriptionId = "<SUBSCRIPTION_ID>"   # e.g. "913d17ca-9c11-4e10-908c-a7d8abb50e26"
$year = 2025

# 1) Sign in & set context
Connect-AzAccount -ErrorAction Stop
Set-AzContext -Subscription $subscriptionId -ErrorAction Stop

$scope = "/subscriptions/$subscriptionId"

# 2) Exact window: Jul 1 -> Oct 1 (exclusive) => returns Jul, Aug, Sep only
$from = [datetime]"$year-07-01"
$to   = [datetime]"$year-10-01"

# 3) Query Cost Management (monthly ActualCost)
$result = Get-AzCostManagementQuery `
  -Scope $scope `
  -Type ActualCost `
  -Timeframe Custom `
  -TimePeriodFrom $from `
  -TimePeriodTo $to `
  -DatasetGranularity Monthly `
  -DatasetAggregation @{ totalCost = @{ Name = 'Cost'; Function = 'Sum' } } `
  -ErrorAction Stop

if (-not $result -or -not $result.Rows) {
  Write-Warning "No cost data for Jul–Sep $year on subscription $subscriptionId."
  return
}

# 4) Shape rows (no pipeline on the foreach line)
$rows = foreach ($r in $result.Rows) {
  # Most tenants return: [0]=UsageDate (yyyyMM), [1]=totalCost, [2]=Currency
  $month = [datetime]::ParseExact($r[0].ToString(), 'yyyyMM', $null).ToString('yyyy-MM')
  [pscustomobject]@{
    Month    = $month
    Cost     = [math]::Round($r[1], 2)
    Currency = $r[2]
  }
}

# 5) Sort AFTER the foreach (to avoid the empty-pipe error)
$rows = $rows | Sort-Object Month

# 6) Display, total, export
$rows | Format-Table Month, Cost, Currency -AutoSize

$total = ($rows | Measure-Object -Property Cost -Sum).Sum
Write-Host ("`nTOTAL (Jul–Sep): {0} {1:N2}" -f $rows[0].Currency, $total) -ForegroundColor Cyan

$outCsv = "azure-cost-jul-sep-$year.csv"
$rows | Export-Csv -Path $outCsv -NoTypeInformation -Encoding UTF8
Write-Host "`nSaved CSV -> $outCsv" -ForegroundColor Yellow
