param([Parameter(Mandatory)][string]$Path)

$done = @{}
$tickets = @()

foreach ($line in [IO.File]::ReadAllLines($Path)) {
    $m = [regex]::Match($line, '^\s*-\s+\[( |x|X)\]\s+#(\d+)\b')
    if (-not $m.Success) { continue }
    $num = [int]$m.Groups[2].Value
    $isDone = $m.Groups[1].Value -ne ' '
    $done[$num] = $isDone
    $b = [regex]::Match($line, '\(blocked by:([^)]*)\)')
    $blockers = @()
    if ($b.Success) {
        foreach ($n in [regex]::Matches($b.Groups[1].Value, '#(\d+)')) {
            $blockers += [int]$n.Groups[1].Value
        }
    }
    $tickets += ,@($num, $isDone, $blockers)
}

$ready = foreach ($t in $tickets) {
    if ($t[1]) { continue }
    $ok = $true
    foreach ($b in $t[2]) { if (-not $done[$b]) { $ok = $false } }
    if ($ok) { $t[0] }
}

foreach ($n in ($ready | Sort-Object -Unique)) { [Console]::Out.WriteLine($n) }
