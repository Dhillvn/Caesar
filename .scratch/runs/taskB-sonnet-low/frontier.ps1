param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$lines = [System.IO.File]::ReadAllLines((Resolve-Path $Path))

$done = @{}
$blockedBy = @{}
$order = @()

$ticketRe = '^\s*-\s\[( |x|X)\]\s#(\d+)\b'
$blockedRe = 'blocked by:\s*(.+?)\)'

foreach ($line in $lines) {
    $m = [regex]::Match($line, $ticketRe)
    if (-not $m.Success) { continue }

    $isDone = $m.Groups[1].Value -eq 'x' -or $m.Groups[1].Value -eq 'X'
    $num = [int]$m.Groups[2].Value

    $done[$num] = $isDone
    $order += $num

    $blockers = @()
    $bm = [regex]::Match($line, $blockedRe)
    if ($bm.Success) {
        foreach ($bnum in [regex]::Matches($bm.Groups[1].Value, '#(\d+)')) {
            $blockers += [int]$bnum.Groups[1].Value
        }
    }
    $blockedBy[$num] = $blockers
}

$ready = @()
foreach ($num in ($order | Sort-Object -Unique)) {
    if ($done[$num]) { continue }
    $isReady = $true
    foreach ($b in $blockedBy[$num]) {
        if (-not $done.ContainsKey($b) -or -not $done[$b]) {
            $isReady = $false
            break
        }
    }
    if ($isReady) { $ready += $num }
}

$ready | Sort-Object | ForEach-Object { Write-Output $_ }
