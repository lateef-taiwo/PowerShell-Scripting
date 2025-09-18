# ===== Azure Cost Jul–Sep via REST (module-light, robust columns) =====
$subscriptionId = "<SUBSCRIPTION_ID>"   # e.g. "913d17ca-9c11-4e10-908c-a7d8abb50e26"
$year = 2025

# Sign in & set context
Connect-AzAccount -ErrorAction Stop | Out-Null
Set-AzContext -Subscription $subscriptionId -ErrorAction Stop | Out-Null

$scope = "/subscriptions/$subscriptionId"
$api  = "2023-03-01"
$uri  = "https://management.azure.com$($scope)/providers/Microsoft.CostManagement/query?api-version=$api"

# Jul 1 -> Oct 1 (exclusive) so we only get Jul, Aug, Sep
$from = Get-Date "$year-07-01T00:00:00Z"
$to   = Get-Date "$year-10-01T00:00:00Z"

# Monthly totals (ActualCost)
$body = @{
  type       = "ActualCost"
  timeframe  = "Custom"
  timePeriod = @{ from = $from; to = $to }
  dataset    = @{
    granularity = "Monthly"
    aggregation = @{
      totalCost = @{ name = "Cost"; function = "Sum" }   # alias 'totalCost' will appear as a column
    }
  }
} | ConvertTo-Json -Depth 6

# Call API with Az.Accounts' REST helper
$resp = Invoke-AzRestMethod -Method POST -Uri $uri -Payload $body -ErrorAction Stop
$data = ($resp.Content | ConvertFrom-Json).properties

if (-not $data -or -not $data.rows) {
  Write-Warning "No cost data returned for Jul–Sep $year on subscription $subscriptionId."
  return
}

# --- Robust column detection ---
$names = @($data.columns.name)

# find month/cost/currency indexes by fuzzy name match
$monthName = ($names | Where-Object { $_ -match 'UsageDate|TimePeriod|BillingMonth|Month' } | Select-Object -First 1)
$costName  = ($names | Where-Object { $_ -match '(?i)totalcost|^cost$|pretaxcost|costinbillingcurrency' } | Select-Object -First 1)
$currName  = ($names | Where-Object { $_ -match '(?i)currency' } | Select-Object -First 1)

$monthIdx = [Array]::IndexOf($names, $monthName)
$costIdx  = [Array]::IndexOf($names, $costName)
$currIdx  = [Array]::IndexOf($names, $currName)

if ($monthIdx -lt 0 -or $costIdx -lt 0) {
  Write-Warning "Could not locate expected columns. Columns returned: $($names -join ', ')"
  return
}

# --- Shape rows (no TryParse) ---
$rows = foreach ($r in $data.rows) {
  $monthRaw = $r[$monthIdx]

  # Normalize month to yyyy-MM
  $month = $null
  $s = $monthRaw.ToString()
  if ($s -match '^\d{6}$') {
    $month = [datetime]::ParseExact($s,'yyyyMM',$null).ToString('yyyy-MM')
  } else {
    try { $month = (Get-Date $s).ToString('yyyy-MM') } catch { $month = $s }
  }

  $cost = 0
  try { $cost = [decimal]$r[$costIdx] } catch { $cost = 0 }

  $currency = $null
  if ($currIdx -ge 0) { $currency = $r[$currIdx] }

  [pscustomobject]@{
    Month    = $month
    Cost     = [math]::Round($cost, 2)
    Currency = $currency
  }
}

# Sort & display (the API window already limits to Jul–Sep)
$rows = $rows | Sort-Object Month
$rows | Format-Table Month, Cost, Currency -AutoSize

# Total & CSV
$total = ($rows | Measure-Object Cost -Sum).Sum
$curr  = ($rows | Where-Object { $_.Currency } | Select-Object -First 1 -ExpandProperty Currency)
Write-Host ("`nTOTAL (Jul–Sep): {0} {1:N2}" -f ($curr ?? ''), $total) -ForegroundColor Cyan

$outCsv = "azure-cost-jul-sep-$year.csv"
$rows | Export-Csv -Path $outCsv -NoTypeInformation -Encoding UTF8
Write-Host "`nSaved CSV -> $outCsv" -ForegroundColor Yellow
