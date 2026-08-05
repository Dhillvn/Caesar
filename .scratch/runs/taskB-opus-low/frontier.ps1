param([Parameter(Mandatory=$true)][string]$Path)

$lines = [IO.File]::ReadAllText($Path) -split "`r`n|`n|`r"

$done = @{}
$tickets = @()

foreach ($line in $lines) {
    $m = [regex]::Match($line, '^\s*[-*+]\s+\[([ xX])\]\s+#(\d+)\b')
    if (-not $m.Success) { continue }

    $num = [int]$m.Groups[2].Value
    $isDone = $m.Groups[1].Value -ne ' '
    $done[$num] = $isDone

    $blockers = @()
    $b = [regex]::Match($line, '\(\s*blocked\s+by\s*:([^)]*)\)', 'IgnoreCase')
    if ($b.Success) {
        foreach ($n in [regex]::Matches($b.Groups[1].Value, '#(\d+)')) {
            $blockers += [int]$n.Groups[1].Value
        }
    }

    $tickets += [pscustomobject]@{ Num = $num; Done = $isDone; Blockers = $blockers }
}

$ready = foreach ($t in $tickets) {
    if ($t.Done) { continue }
    $ok = $true
    foreach ($b in $t.Blockers) {
        if (-not $done.ContainsKey($b) -or -not $done[$b]) { $ok = $false; break }
    }
    if ($ok) { $t.Num }
}

foreach ($n in ($ready | Sort-Object -Unique)) { [Console]::Out.WriteLine($n) }
