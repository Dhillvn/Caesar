param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$lines = [IO.File]::ReadAllText($Path) -split "`r?`n"

$done = @{}
$blockedBy = @{}

foreach ($line in $lines) {
    if ($line -match '^\s*-\s\[( |x|X)\]\s*#(\d+)') {
        $num = [int]$Matches[2]
        $isDone = $Matches[1] -ne ' '
        $done[$num] = $isDone
        $blockedBy[$num] = @()

        if ($line -match '\(blocked by:\s*([^)]*)\)') {
            $blockedBy[$num] = [regex]::Matches($Matches[1], '#(\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
        }
    }
}

$ready = foreach ($num in $done.Keys) {
    if ($done[$num]) { continue }
    $blockers = $blockedBy[$num]
    $allDone = $true
    foreach ($b in $blockers) {
        if (-not $done.ContainsKey($b) -or -not $done[$b]) { $allDone = $false; break }
    }
    if ($allDone) { $num }
}

$ready | Sort-Object | ForEach-Object { $_ }
