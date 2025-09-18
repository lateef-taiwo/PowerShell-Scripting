# ===== Azure Cost Jul–Sep via REST (no Az.CostManagement needed) =====

$subscriptionId = "<SUBSCRIPTION_ID>"   # e.g. "913d17ca-9c11-4e10-908c-a7d8abb50e26"
$year = 2025

# 1) Login & set context
Connect-AzAccount -ErrorAction Stop | Out-Null
Set-AzContext -Subscription $subscriptionId -ErrorAction Stop | Out-Null

# 2) Build REST call to Cost Management Query
$scope = "/subscriptions/$subscriptionId"
$api  = "2023-03-01"    # stable API version for Cost Management Query
$uri  = "https://management.azure.com$($scope)/providers/Microsoft.CostManagement/query?api-version=$api"

$from = Get-Date "$year-07-01T00:00:00Z"
$to   = Get-Date "$year-10-01T00:00:00Z"  # exclusive (returns Jul, Aug, Sep)

$body = @{
  type       = "ActualCost"
  timeframe  = "Custom"
  timePeriod = @{ from = $from; to = $to }
  dataset    = @{
    granularity = "Monthly"
    aggregation = @{
      totalCost = @{ name = "Cost"; function = "Sum" }
    }
  }
} | ConvertTo-Json -Depth 5

# 3) Call the API using Az.Accounts' REST helper
$resp = Invoke-AzRestMethod -Method POST -Uri $uri -Payload $body -ErrorAction Stop

# 4) Parse rows (columns can be UsageDate/TimePeriod, Currency/BillingCurrency)
$data = ($resp.Content | ConvertFrom-Json).properties

if (-not $data -or -not $data.rows) {
  Write-Warning "No cost data returned for Jul–Sep $year on subscription $subscriptionId."
  return
}

# Map column names to indexes
$colIdx = @{}
for ($i=0; $i -lt $data.columns.Count; $i++) { $colIdx[$data.columns[$i].name] = $i }

function Get-ColVal($row, $names) {
  foreach ($n in $names) { if ($colIdx.ContainsKey($n)) { return $row[$colIdx[$n]] } }
  return $null
}

# 5) Shape output
$rows = foreach ($r in $data.rows) {
  $monthRaw = Get-ColVal $r @('UsageDate','TimePeriod')  # usually yyyyMM
  $month = $null
  if ($monthRaw -is [int] -or ($monthRaw -is [string] -and $monthRaw -match '^\d{6}$')) {
    $month = [datetime]::ParseExact($monthRaw.ToString(),'yyyyMM',$null).ToString('yyyy-MM')
  } elseif ($monthRaw) {
    $tmp=$null; if ([datetime]::TryParse($monthRaw,[ref]$tmp)) { $month = $tmp.ToString('yyyy-MM') }
  }

  [pscustomobject]@{
    Month    = $month
    Cost     = [math]::Round([decimal](Get-ColVal $r @('totalCost')), 2)
    Currency = (Get-ColVal $r @('Currency','BillingCurrency','CurrencyCode'))
  }
}

# Keep only Jul, Aug, Sep of the chosen year and sort
$want = @("{0}-07" -f $year,"{0}-08" -f $year,"{0}-09" -f $year)
$rows = $rows | Where-Object { $_.Month -in $want } | Sort-Object Month

if (-not $rows) {
  Write-Warning "Query ran, but no rows matched Jul/Aug/Sep $year."
  return
}

# 6) Display, total, export
$rows | Format-Table Month, Cost, Currency -AutoSize

$total = ($rows | Measure-Object Cost -Sum).Sum
$curr  = ($rows | Select-Object -First 1).Currency
Write-Host ("`nTOTAL (Jul–Sep): {0} {1:N2}" -f $curr, $total) -ForegroundColor Cyan

$outCsv = "azure-cost-jul-sep-$year.csv"
$rows | Export-Csv -Path $outCsv -NoTypeInformation -Encoding UTF8
Write-Host "`nSaved CSV -> $outCsv" -ForegroundColor Yellow
