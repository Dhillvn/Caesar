[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$text = [IO.File]::ReadAllText($Path)
$lines = $text -split "`r`n|`n|`r"

$done = @{}
$tickets = @()

foreach ($line in $lines) {
    $trimmed = $line.Trim()
    $m = [regex]::Match($trimmed, '^[-*+]\s+\[([ xX])\]\s+#(\d+)\b')
    if (-not $m.Success) { continue }

    $num = [int]$m.Groups[2].Value
    $isDone = $m.Groups[1].Value -ne ' '

    $rest = $trimmed.Substring($m.Length)
    $blockers = @()
    $b = [regex]::Match($rest, '\(\s*blocked\s+by\s*:([^)]*)\)\s*$', 'IgnoreCase')
    if ($b.Success) {
        foreach ($n in [regex]::Matches($b.Groups[1].Value, '#(\d+)')) {
            $blockers += [int]$n.Groups[1].Value
        }
    }

    if ($done.ContainsKey($num)) {
        $done[$num] = $done[$num] -or $isDone
    } else {
        $done[$num] = $isDone
    }
    $tickets += [pscustomobject]@{ Number = $num; Done = $isDone; Blockers = $blockers }
}

$ready = @{}
foreach ($t in $tickets) {
    if ($done[$t.Number]) { continue }
    $ok = $true
    foreach ($b in $t.Blockers) {
        if (-not ($done.ContainsKey($b) -and $done[$b])) { $ok = $false; break }
    }
    if ($ok) { $ready[$t.Number] = $true }
}

foreach ($n in ($ready.Keys | Sort-Object)) { [string]$n }
