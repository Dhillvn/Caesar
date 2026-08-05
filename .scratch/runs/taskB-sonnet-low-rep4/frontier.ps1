param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$lines = [IO.File]::ReadAllText($Path) -split "`r?`n"

$done = @{}
$tickets = @{}

foreach ($line in $lines) {
    if ($line -match '- \[( |x)\]\s*#(\d+)') {
        $num = [int]$Matches[2]
        $isDone = $Matches[1] -eq 'x'
        $tickets[$num] = $line
        $done[$num] = $isDone
    }
}

$ready = @()
foreach ($num in $tickets.Keys) {
    if ($done[$num]) { continue }
    $line = $tickets[$num]
    $blockers = @()
    if ($line -match 'blocked by:\s*([^\)]+)') {
        $blockers = [regex]::Matches($Matches[1], '#(\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
    }
    $blockedByUndone = $false
    foreach ($b in $blockers) {
        if (-not $done.ContainsKey($b) -or -not $done[$b]) {
            $blockedByUndone = $true
            break
        }
    }
    if (-not $blockedByUndone) { $ready += $num }
}

$ready | Sort-Object | ForEach-Object { Write-Output $_ }
