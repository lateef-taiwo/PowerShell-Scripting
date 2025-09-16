# Requires Az.Accounts, Az.Network, Az.Resources
Connect-AzAccount

# Optional: only include subscriptions you actually manage
$subs = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }

# Where to save results
$root = "$HOME\azure-topology"
New-Item -ItemType Directory -Force -Path $root | Out-Null

foreach ($sub in $subs) {
    Write-Host "== Subscription: $($sub.Name) ==" -ForegroundColor Cyan
    Set-AzContext -Subscription $sub.Id | Out-Null

    # Find VNets and the regions they’re in (so we know where to enable Network Watcher)
    $vnets = Get-AzVirtualNetwork -ErrorAction SilentlyContinue
    if (-not $vnets) {
        Write-Host "  (no VNets)" -ForegroundColor DarkGray
        continue
    }

    $regions = $vnets.Location | Sort-Object -Unique
    foreach ($region in $regions) {
        # Ensure Network Watcher exists/enabled in this region
        try {
            $nw = Get-AzNetworkWatcher -Location $region -ErrorAction Stop
        } catch {
            # Create NW using the conventional RG name (or pick your own RG)
            $rgName = "NetworkWatcherRG"
            if (-not (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue)) {
                New-AzResourceGroup -Name $rgName -Location $region | Out-Null
            }
            $nw = New-AzNetworkWatcher -Name "NetworkWatcher_$region" -ResourceGroupName $rgName -Location $region
        }
    }

    # Now iterate all RGs and pull Network Watcher Topology
    $rgs = Get-AzResourceGroup
    foreach ($rg in $rgs) {
        # Pick a region to query: use the RG’s location if it matches a NW, else fallback to first VNet region
        $regionToUse = $rg.Location
        try { $nw = Get-AzNetworkWatcher -Location $regionToUse -ErrorAction Stop }
        catch { $regionToUse = $regions | Select-Object -First 1; $nw = Get-AzNetworkWatcher -Location $regionToUse -ErrorAction SilentlyContinue }

        if (-not $nw) {
            Write-Host "  Skipping RG '$($rg.ResourceGroupName)' (no Network Watcher available in $regionToUse)" -ForegroundColor DarkYellow
            continue
        }

        Write-Host "  -> Topology for RG: $($rg.ResourceGroupName) via $($nw.Location)"

        # Azure-native topology (nodes + relationships)
        $topo = Get-AzNetworkWatcherTopology `
            -NetworkWatcher $nw `
            -TargetResourceGroupName $rg.ResourceGroupName `
            -TargetSubscriptionId $sub.Id

        # Persist JSON (native)
        $outDir = Join-Path $root "$($sub.Name)\$($rg.ResourceGroupName)"
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
        $jsonPath = Join-Path $outDir "topology.json"
        $topo | ConvertTo-Json -Depth 100 | Out-File -FilePath $jsonPath -Encoding UTF8

        # --- OPTIONAL: also emit a GraphViz DOT so you can render an SVG diagram locally ---
        # Nodes: resourceId (label = short name + type)
        # Edges: relationships (source -> target)
        $dotPath = Join-Path $outDir "topology.dot"

        $nodes = @{}
        foreach ($n in $topo.Resources) {
            # Build a readable label: last segment of ID + type
            $name = ($n.Id -split '/')[ -1 ]
            $label = "$($name)\n$($n.Type)"
            $nodes[$n.Id] = $label
        }

        $dot = @()
        $dot += 'digraph azure_topology {'
        $dot += '  rankdir=LR;'
        $dot += '  node [shape=box, style="rounded,filled", fillcolor=white, fontsize=10];'
        $dot += '  edge [arrowsize=0.6];'

        # Group nodes by VNet if you want clusters (lightweight)
        # Build edges
        foreach ($rel in $topo.Relationships) {
            $src = $rel.SourceId
            $dst = $rel.DestinationId
            if ($nodes.ContainsKey($src) -and $nodes.ContainsKey($dst)) {
                $dot += "  `"$src`" -> `"$dst`";"
            }
        }

        # Emit node declarations with labels
        foreach ($kvp in $nodes.GetEnumerator()) {
            $id = $kvp.Key
            $label = $kvp.Value.Replace('"','\"')
            $dot += "  `"$id`" [label=""$label""];"
        }

        $dot += '}'
        $dot -join "`n" | Out-File -FilePath $dotPath -Encoding UTF8

        # If GraphViz 'dot' is installed and on PATH, auto-render an SVG
        $dotExe = (Get-Command dot -ErrorAction SilentlyContinue)
        if ($dotExe) {
            $svgPath = Join-Path $outDir "topology.svg"
            & $dotExe.Source -Tsvg $dotPath -o $svgPath
            Write-Host "     Saved: $svgPath" -ForegroundColor Green
        } else {
            Write-Host "     (Install GraphViz to render $dotPath to SVG/PNG)" -ForegroundColor DarkGray
        }
    }
}
Write-Host "`nAll done. Output in: $root" -ForegroundColor Cyan
