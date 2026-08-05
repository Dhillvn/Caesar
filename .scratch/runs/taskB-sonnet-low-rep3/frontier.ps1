param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$lines = [IO.File]::ReadAllText($Path) -split "`r?`n"

$tickets = @{}      # number -> done bool
$blockers = @{}     # number -> list of blocker numbers

foreach ($line in $lines) {
    if ($line -match '^\s*-\s*\[([ xX])\]\s*#(\d+)') {
        $num = [int]$Matches[2]
        $done = $Matches[1] -ne ' '
        $tickets[$num] = $done

        $blockers[$num] = @()
        if ($line -match '\(blocked by:\s*([^)]*)\)') {
            $blockers[$num] = [regex]::Matches($Matches[1], '#(\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
        }
    }
}

$ready = foreach ($num in $tickets.Keys) {
    if ($tickets[$num]) { continue }
    $blocked = $false
    foreach ($b in $blockers[$num]) {
        if (-not $tickets.ContainsKey($b) -or -not $tickets[$b]) { $blocked = $true; break }
    }
    if (-not $blocked) { $num }
}

$ready | Sort-Object | ForEach-Object { $_.ToString() }
