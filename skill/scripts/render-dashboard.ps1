<#
.SYNOPSIS
  Pure renderer: dashboard-data.ps1's JSON in, the Caesar command centre page out
  (issue #183). Every fact on the page comes from the JSON - this script does not
  call gh, frontier.ps1 or anything else that talks to GitHub.

.DESCRIPTION
  Reproduces docs/prototypes/command-centre.html against real data. The prototype
  is JS-driven over a fixture; this is server-rendered PowerShell with no client
  script at all, because the page must show the moment it was generated and a
  static file cannot age its own timestamp (docs/research/command-centre-refresh.md
  section 5) - so every value, including "swept Ns ago", is baked in at render time.

  On a caught sweep failure the caller (the regenerator loop, #183 step 8) re-invokes
  this script with the last-known-good JSON plus -ErrorMessage/-ErrorTime/
  -FailureCount, so the page still rewrites with a banner rather than going stale.

.EXAMPLE
  .\dashboard-data.ps1 | .\render-dashboard.ps1 -OutFile out\index.html
.EXAMPLE
  .\render-dashboard.ps1 -Path data.json -OutFile out\index.html -ErrorMessage "gh: rate limited" -ErrorTime (Get-Date) -FailureCount 3
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline = $true)]
    [string]$Json,
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$OutFile,
    [string]$ErrorMessage,
    [string]$ErrorTime,
    [int]$FailureCount = 0
)

begin {
    $sb = [System.Text.StringBuilder]::new()
}
process {
    if ($Json) { [void]$sb.Append($Json) }
}
end {
    $ErrorActionPreference = 'Stop'

    $jsonText = if ($Path) { [IO.File]::ReadAllText($Path) } else { $sb.ToString() }
    if (-not $jsonText.Trim()) { throw "render-dashboard.ps1: no JSON given (pipe, -Json or -Path)" }
    $data = $jsonText | ConvertFrom-Json

    function Esc($s) {
        if ($null -eq $s) { return '' }
        [System.Net.WebUtility]::HtmlEncode([string]$s)
    }

    function Format-Ago([double]$sec) {
        if ($sec -lt 0) { $sec = 0 }
        $sec = [int]$sec
        if ($sec -lt 60) { return "${sec}s" }
        if ($sec -lt 3600) { return "$([int]($sec / 60))m" }
        return "$([int]($sec / 3600))h"
    }

    function Format-When($iso) {
        if (-not $iso) { return '&mdash;' }
        try { return ([datetime]$iso).ToString('yyyy-MM-dd HH:mm') } catch { return (Esc $iso) }
    }

    # One state -> one class, glyph and word alike (DESIGN.md "State colours").
    # ponytail: named $StateColours, not $STATE - PowerShell variable names are
    # case-insensitive, and a loop var $state below would silently alias $STATE.
    $StateColours = @{
        'Needs you' = @{ cls = 'c-copper';   gl = [char]0x25C6 }
        'Ongoing'   = @{ cls = 'c-teal';     gl = [char]0x25CF }
        'Queued'    = @{ cls = 'c-bone';     gl = [char]0x25CB }
        'Blocked'   = @{ cls = 'c-graphite'; gl = [char]0x2298 }
    }
    function St($ticket) { if ($StateColours.ContainsKey($ticket.State)) { $StateColours[$ticket.State] } else { $StateColours['Queued'] } }

    function Row-Html($map, $t) {
        $s = St $t
        $blk = ''
        if ($t.BlockedBy -and @($t.BlockedBy).Count -gt 0) {
            $links = @($t.BlockedBy | ForEach-Object {
                "<a href=`"https://github.com/$($map.Repo)/issues/$_`">#$_</a>"
            }) -join ', '
            $blk = "blocked by $links"
        }
        $who = if ($t.Who -eq 'You') { 'you' } else { 'caesar' }
        return '<div class="row">' +
            "<a class=`"hit`" href=`"$($t.Url)`" aria-label=`"$(Esc $t.Title)`"></a>" +
            "<span class=`"gl $($s.cls)`">$($s.gl)</span>" +
            "<span class=`"rn $($s.cls)`">$($t.Number)</span>" +
            "<span class=`"rt`"><a href=`"$($t.Url)`">$(Esc $t.Title)</a></span>" +
            "<span class=`"col`">$(Esc $t.Type)</span>" +
            "<span class=`"col`">$who</span>" +
            "<span class=`"col blk`">$blk</span>" +
            "<span class=`"st $($s.cls)`">$(Esc $t.State)</span></div>"
    }

    function Body-Html($map) {
        $tickets = @($map.OpenTickets)
        if ($map.Error) {
            return '<div class="done" style="color:var(--copper-signal)">' +
                "<span class=`"lab mono`" style=`"color:var(--copper-signal)`">sweep error</span>" +
                "$(Esc $map.Error)</div>"
        }
        if ($tickets.Count -eq 0) {
            $last = if ($map.LastDecided) {
                "Last decided: <a href=`"$($map.LastDecided.Url)`">#$($map.LastDecided.Number)</a> $(Esc $map.LastDecided.Title). "
            } else { '' }
            return '<div class="done"><span class="lab mono">nothing open &mdash; the way is clear</span>' +
                "$last$($map.DoneCount) decisions in total. Retire its " +
                '<span class="mono">caesar:driving</span> label, or reopen the map with a new ticket.</div>'
        }
        $out = ''
        foreach ($state in @('Needs you', 'Ongoing', 'Queued')) {
            $rows = @($tickets | Where-Object { $_.State -eq $state })
            if ($rows.Count -eq 0) { continue }
            $out += "<div class=`"ghead mono`"><span class=`"lab`">$state</span><span class=`"ct`">$($rows.Count)</span></div>" +
                '<div class="rows grp">' + (($rows | ForEach-Object { Row-Html $map $_ }) -join '') + '</div>'
        }
        $blocked = @($tickets | Where-Object { $_.State -eq 'Blocked' })
        if ($blocked.Count -gt 0) {
            $out += "<details class=`"blocked`"><summary>$($blocked.Count) blocked &mdash; show</summary>" +
                '<div class="rows grp">' + (($blocked | ForEach-Object { Row-Html $map $_ }) -join '') + '</div></details>'
        }
        return $out
    }

    $maps = @($data.Maps)

    function Card-Html($map) {
        $tickets = @($map.OpenTickets)
        $blockedCt = @($tickets | Where-Object { $_.State -eq 'Blocked' }).Count
        $ongoingCt = @($tickets | Where-Object { $_.State -eq 'Ongoing' }).Count
        $title = if ($map.Title) { Esc $map.Title } else { '(sweep failed)' }
        $live = if ($ongoingCt -gt 0) {
            '<span class="c-teal" style="display:flex;align-items:center;gap:6px">' +
            '<span class="pulse" style="background:var(--teal-metric)"></span>live</span>'
        } else { '' }
        return '<div class="card">' +
            '<div class="cbar mono">' +
            '<span class="dot" style="background:#ff5f57"></span>' +
            '<span class="dot" style="background:#febc2e"></span>' +
            '<span class="dot" style="background:#28c840"></span>' +
            "<span class=`"num`"><span class=`"hash`">#</span>$($map.Number)</span>" +
            "<span class=`"t`">$title</span>" +
            "<span class=`"right`"><span class=`"repo`">$(Esc $map.Repo)</span>$live</span>" +
            '</div>' +
            '<div class="cbody">' +
            '<div class="chead">' +
            "<span class=`"num`"><span class=`"hash`">#</span>$($map.Number)</span>" +
            "<span class=`"t`">$title</span>" +
            "<span class=`"right`"><span class=`"repo mono`">$(Esc $map.Repo)</span></span>" +
            '</div>' +
            "<div class=`"meta`">$($tickets.Count) open &middot; $blockedCt blocked &middot; $($map.DoneCount) decided</div>" +
            (Body-Html $map) +
            "<a class=`"more`" href=`"$($map.Url)`"><span>Open the map &rarr;</span></a>" +
            '</div></div>'
    }

    # ---- global metrics (facts only, all from the JSON) ----
    $open = ($maps | Measure-Object -Property OpenCount -Sum).Sum
    if (-not $open) { $open = 0 }
    $decided = ($maps | Measure-Object -Property DoneCount -Sum).Sum
    if (-not $decided) { $decided = 0 }
    $allTickets = @($maps | ForEach-Object { $_.OpenTickets })
    $needsRaj = @($allTickets | Where-Object { $_.Who -eq 'You' }).Count
    $caesarHolds = @($allTickets | Where-Object { $_.Who -eq 'Caesar' }).Count
    $mapCount = $maps.Count
    $slotsUsed = $data.AgentSlots.InUse
    $slotsCap = $data.AgentSlots.Cap

    $genDto = [DateTimeOffset]::Parse($data.GeneratedAt)
    $ago = (Get-Date).ToUniversalTime() - $genDto.UtcDateTime
    $agoStr = Format-Ago $ago.TotalSeconds
    $stale = $ago.TotalSeconds -gt 180
    $genStr = $genDto.ToString('yyyy-MM-dd HH:mm')

    $staleAttr = if ($stale) { ' stale' } else { '' }

    # ---- the gate: open PRs grouped under the map they belong to ----
    $prs = @($data.OpenPrs)
    $gateItems = ''
    if ($prs.Count -eq 0) {
        $gateItems = '<div class="done"><span class="lab mono">nothing at the gate</span>no open PRs.</div>'
    } else {
        $mapTitleOf = @{}
        foreach ($m in $maps) { $mapTitleOf[[int]$m.Number] = $m.Title }
        $seenMaps = New-Object System.Collections.Generic.List[int]
        foreach ($p in $prs) { if ($p.Map -and -not $seenMaps.Contains([int]$p.Map)) { [void]$seenMaps.Add([int]$p.Map) } }
        foreach ($mapNum in $seenMaps) {
            $mapTitle = if ($mapTitleOf.ContainsKey($mapNum)) { Esc $mapTitleOf[$mapNum] } else { '' }
            $gateItems += "<div class=`"gmap`"><span class=`"gnum`">#$mapNum</span><span class=`"gt`">$mapTitle</span></div><ul>"
            foreach ($p in ($prs | Where-Object { $_.Map -eq $mapNum })) {
                $sub = if ($p.ClosesTicket) { "closes #$($p.ClosesTicket) &middot; " } else { '' }
                $sub += $(if ($p.Draft) { 'draft' } else { 'ready' })
                $sub += " &middot; $(Format-Ago $p.AgeSeconds) old"
                $gateItems += "<li><span class=`"n`">#$($p.Number)</span><span>" +
                    "<a href=`"$($p.Url)`">$(Esc $p.Title)</a>" +
                    "<span class=`"sub`">$sub</span></span></li>"
            }
            $gateItems += '</ul>'
        }
        $unmapped = @($prs | Where-Object { -not $_.Map })
        if ($unmapped.Count -gt 0) {
            $gateItems += '<div class="gmap"><span class="gnum">&mdash;</span><span class="gt">no map found for this PR&#39;s ticket</span></div><ul>'
            foreach ($p in $unmapped) {
                $sub = $(if ($p.Draft) { 'draft' } else { 'ready' }) + " &middot; $(Format-Ago $p.AgeSeconds) old"
                $gateItems += "<li><span class=`"n`">#$($p.Number)</span><span>" +
                    "<a href=`"$($p.Url)`">$(Esc $p.Title)</a>" +
                    "<span class=`"sub`">$sub</span></span></li>"
            }
            $gateItems += '</ul>'
        }
    }
    $gateCap = if ($prs.Count -eq 0) { '0 branches at the gate.' } else { "$($prs.Count) branch$(if ($prs.Count -ne 1) { 'es' }) at the gate." }

    # ---- ledger: the most recent runs (the page's job is "what the last runs cost", not a full history) ----
    $runs = @($data.CenturionRuns | Sort-Object { [datetime]$_.Timestamp } -Descending | Select-Object -First 10)
    $runRows = ($runs | ForEach-Object {
        $cls = if ($_.Classification -match '^ERRORED' -or $_.Classification -eq 'RUNNING') { 'c-copper' } else { 'c-teal' }
        $cost = if ($null -ne $_.Cost) { '$' + [math]::Round($_.Cost, 2).ToString('0.00') } else { '&mdash;' }
        $turns = if ($null -ne $_.Turns) { $_.Turns } else { '&mdash;' }
        $ref = if ($_.Ticket) { "#$($_.Ticket)" } else { Esc $_.Name }
        "<tr><td class=`"m`">$ref</td><td class=`"m`">$(Esc $_.Repo)</td>" +
        "<td><span class=`"st $cls`">$(Esc $_.Classification)</span></td>" +
        "<td>$cost</td><td class=`"m`">$turns</td><td class=`"m`">$(Format-When $_.Timestamp)</td></tr>"
    }) -join ''

    # ---- footer: repos actually driven, not a hardcoded list ----
    $repos = @($maps | Where-Object { $_.Repo } | ForEach-Object { $_.Repo } | Select-Object -Unique)
    $repoLinks = ($repos | ForEach-Object { "<a href=`"https://github.com/$_/issues`">$(Esc $_)</a>" }) -join ''

    # ---- failure banner, prepended without touching the last-good tables underneath ----
    $banner = ''
    if ($ErrorMessage) {
        $when = if ($ErrorTime) { $ErrorTime } else { '' }
        $banner = '<div class="wrap"><div class="failbanner mono">' +
            "sweep failed $when &middot; $FailureCount consecutive failure$(if ($FailureCount -ne 1) { 's' }) &middot; " +
            "$(Esc $ErrorMessage)</div></div>"
    }

    $bar = (@(
        @{ l = 'open'; v = $open; hot = $false }
        @{ l = 'need you'; v = $needsRaj; hot = $true }
        @{ l = 'caesar holds'; v = $caesarHolds; hot = $false }
        @{ l = 'decided'; v = $decided; hot = $false }
        @{ l = 'slots'; v = "$slotsUsed/$slotsCap"; hot = $false }
        @{ l = 'maps'; v = $mapCount; hot = $false }
    ) | ForEach-Object {
        $hot = if ($_.hot) { ' hot' } else { '' }
        "<span class=`"m$hot`"><span class=`"v`">$($_.v)</span><span class=`"l mono`">$($_.l)</span></span>"
    }) -join ''

    $cards = ($maps | ForEach-Object { Card-Html $_ }) -join ''

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="30">
<title>Caesar — command centre</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Geist:wght@400;500&family=Geist+Mono:wght@400&display=swap" rel="stylesheet">
<style>
:root{
  --obsidian-canvas:#101010; --carbon-lift:#1d1a18; --ash-stroke:#3d3a39;
  --graphite-mid:#4d4947; --warm-granite:#8a8380; --pale-stone:#b8b3b0;
  --bone:#eeeeee; --chalk:#fafafa;
  --copper-signal:#C87941;
  --teal-metric:#0D9488;
  --btn-dark:#1f1d1c; --frame:#0d0d0d;
  --font-geist:'Geist',Inter,system-ui,ui-sans-serif,sans-serif;
  --font-geist-mono:'Geist Mono',ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
  --page-max-width:1200px; --section-gap:56px; --card-padding:24px; --element-gap:24px;
  --radius-nav:3px; --radius-buttons:3px; --radius-cards:10px; --radius-largepanels:20px;
  --row-grid: 18px 52px 1fr 104px 72px 150px 104px;
}
*{box-sizing:border-box}
body{margin:0;background:var(--obsidian-canvas);color:var(--bone);
  font:400 16px/1.5 var(--font-geist);-webkit-font-smoothing:antialiased}
a{text-decoration:none;color:inherit;
  transition:color .15s cubic-bezier(.4,0,.2,1),border-color .15s cubic-bezier(.4,0,.2,1)}
.wrap{max-width:var(--page-max-width);margin:0 auto;padding:0 24px}
.mono{font:400 12px/1 var(--font-geist-mono);letter-spacing:-.24px;text-transform:uppercase}
nav{height:64px;display:flex;align-items:center;gap:24px;
  max-width:var(--page-max-width);margin:0 auto;padding:0 24px}
nav .mark{font:400 12px/1 var(--font-geist-mono);letter-spacing:.14em;
  text-transform:uppercase;color:var(--bone)}
nav .links{display:flex;gap:28px;margin-left:16px}
nav .links a{font:400 14px/1 var(--font-geist);text-transform:uppercase;
  letter-spacing:-.02em;color:var(--bone)}
nav .links a:hover{color:var(--warm-granite)}
nav .right{margin-left:auto;display:flex;align-items:center;gap:12px}
.frame{background:var(--frame);border-radius:var(--radius-cards);overflow:hidden}
.frame .bar{display:flex;align-items:center;gap:8px;padding:12px 16px;background:var(--carbon-lift)}
.dot{width:8px;height:8px;border-radius:50%}
#bar{display:grid;grid-template-columns:repeat(6,1fr);gap:0;padding:0;margin-top:32px;
  border-top:1px solid var(--carbon-lift);border-bottom:1px solid var(--carbon-lift)}
#bar .m{display:block;padding:16px 20px;border-top:1px solid var(--carbon-lift);
  border-bottom:1px solid var(--carbon-lift);border-left:1px solid var(--carbon-lift)}
#bar .m:first-child{border-left:0}
#bar .m .v{font:400 36px/1.1 var(--font-geist);letter-spacing:-1.12px;color:var(--bone);display:block;margin-bottom:10px}
#bar .m .l{color:var(--warm-granite);display:block}
#bar .m.hot .v{color:var(--copper-signal)}
.stale{color:var(--copper-signal) !important}
.stale .pulse{background:var(--copper-signal)}
.pulse{width:6px;height:6px;border-radius:50%;background:var(--copper-signal);flex:none}
.sec-head{display:flex;align-items:baseline;gap:16px;margin-bottom:32px}
.sec-head h2{font:400 44px/1.12 var(--font-geist);letter-spacing:-1.1px;margin:0}
.grid{display:grid;grid-template-columns:1fr;gap:var(--element-gap)}
.card{background:var(--frame);border:0;border-radius:var(--radius-cards);padding:0;overflow:hidden}
.cbar{display:flex;align-items:center;gap:8px;padding:12px 16px;background:var(--carbon-lift)}
.cbar .num{font:400 20px/1 var(--font-geist-mono);letter-spacing:-.4px;color:var(--bone);
  margin-left:12px;flex:none}
.cbar .num .hash{color:var(--graphite-mid)}
.cbar .t{color:var(--pale-stone);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.cbar .right{margin-left:auto;display:flex;align-items:center;gap:16px;flex:none}
.cbar .repo{color:var(--warm-granite)}
.cbody{padding:4px 20px 20px}
.chead{display:none}
.meta{color:var(--warm-granite);font:400 14px/1.43 var(--font-geist);margin-top:16px}
.rows{margin-top:4px}
.row{display:grid;grid-template-columns:var(--row-grid);gap:12px;align-items:baseline;
  padding:7px 12px;margin:0 -12px;border-top:1px solid var(--carbon-lift);position:relative}
.rows.grp .row:first-child{border-top:0}
.row .hit{position:absolute;inset:0}
.row:hover{background:var(--carbon-lift)}
.row:hover .rt{color:var(--chalk)}
.gl{font:400 12px/1.6 var(--font-geist-mono);color:var(--graphite-mid);text-align:center}
.rn{font:400 12px/1.6 var(--font-geist-mono);letter-spacing:-.24px;color:var(--graphite-mid)}
.rt{font:400 14px/1.43 var(--font-geist);color:var(--bone);min-width:0;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap;position:relative;z-index:1}
.col{font:400 12px/1.6 var(--font-geist-mono);letter-spacing:-.24px;text-transform:uppercase;
  color:var(--warm-granite);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.col.blk{color:var(--graphite-mid)}
.col.blk a{position:relative;z-index:1;color:inherit}
.col.blk a:hover{color:var(--bone)}
.st{font:400 12px/1.6 var(--font-geist-mono);letter-spacing:-.24px;text-transform:uppercase;
  color:var(--warm-granite);white-space:nowrap}
.c-copper{color:var(--copper-signal)}
.c-teal{color:var(--teal-metric)}
.c-bone{color:var(--bone)}
.c-graphite{color:var(--graphite-mid)}
.ghead{display:grid;grid-template-columns:var(--row-grid);gap:12px;
  color:var(--pale-stone);padding:12px 0 4px;border-top:1px solid var(--carbon-lift)}
.ghead .lab{grid-column:2 / 4}
.ghead .ct{grid-column:7;color:var(--graphite-mid)}
details.blocked{border-top:1px solid var(--carbon-lift);padding-top:14px;margin-top:4px}
details.blocked summary{cursor:pointer;list-style:none;color:var(--graphite-mid);
  font:400 12px/1.6 var(--font-geist-mono);letter-spacing:-.24px;text-transform:uppercase}
details.blocked summary::-webkit-details-marker{display:none}
details.blocked summary:hover{color:var(--warm-granite)}
.more{margin-top:20px;display:inline-block;color:var(--bone);font:400 14px/1 var(--font-geist)}
.more span{border-bottom:1px solid var(--ash-stroke);padding-bottom:6px}
.more:hover span{color:var(--chalk);border-color:var(--chalk)}
.done{padding:20px 0 4px;color:var(--warm-granite);font:400 14px/1.43 var(--font-geist)}
.done .lab{color:var(--teal-metric);display:block;margin-bottom:8px}
.ledger{width:100%;border-collapse:collapse;margin-top:32px}
.ledger th{text-align:left;padding:0 16px 12px 0;color:var(--pale-stone);
  font:400 12px/1 var(--font-geist-mono);letter-spacing:-.24px;text-transform:uppercase;
  border-bottom:1px solid var(--carbon-lift)}
.ledger td{padding:16px 16px 16px 0;border-bottom:1px solid var(--carbon-lift);
  font:400 14px/1.43 var(--font-geist);color:var(--bone);vertical-align:top}
.ledger td.m{font-family:var(--font-geist-mono);letter-spacing:-.24px;
  color:var(--warm-granite);font-size:12px;text-transform:uppercase}
.cta{background:var(--bone);border-radius:var(--radius-cards);padding:var(--card-padding);
  color:var(--obsidian-canvas);max-width:640px;position:relative;overflow:hidden}
.cta .cap{color:var(--obsidian-canvas);display:flex;align-items:center;gap:8px}
.cta h2{font:400 36px/1.1 var(--font-geist);letter-spacing:-1.12px;
  color:var(--obsidian-canvas);margin:16px 0 0}
.cta ul{list-style:none;margin:24px 0 0;padding:0}
.cta li{display:flex;gap:12px;padding:10px 0;border-top:1px solid rgba(16,16,16,.14);
  font:400 14px/1.43 var(--font-geist)}
.cta li .n{font-family:var(--font-geist-mono);font-size:12px;letter-spacing:-.24px;
  color:var(--graphite-mid);width:56px;flex:none;line-height:1.6}
.cta li .sub{display:block;color:var(--graphite-mid);margin-top:4px;
  font:400 12px/1.4 var(--font-geist-mono);letter-spacing:-.24px;text-transform:uppercase}
.cta .done{color:var(--graphite-mid)}
.cta .done .lab{color:var(--teal-metric)}
.gmap{display:flex;align-items:baseline;gap:12px;margin-top:24px;
  padding-bottom:8px;border-bottom:1px solid rgba(16,16,16,.14)}
.gmap:first-child{margin-top:0}
.gmap .gnum{font:400 20px/1 var(--font-geist-mono);letter-spacing:-.4px;color:var(--obsidian-canvas)}
.gmap .gt{font:400 12px/1 var(--font-geist-mono);letter-spacing:-.24px;text-transform:uppercase;
  color:var(--graphite-mid);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.gmap + ul li:first-child{border-top:0}
.failbanner{background:var(--carbon-lift);border-left:3px solid var(--copper-signal);
  color:var(--copper-signal);padding:16px 24px;margin-top:16px;font:400 14px/1.5 var(--font-geist)}
.failbanner .mono{color:var(--copper-signal)}
section{padding-top:var(--section-gap)}
footer{padding:var(--section-gap) 0 96px;border-top:1px solid var(--carbon-lift);margin-top:var(--section-gap)}
footer .cols{display:grid;grid-template-columns:2fr 1fr 1fr 1fr;gap:36px}
footer .h{color:var(--bone);margin-bottom:20px}
footer a{display:block;font:400 14px/2 var(--font-geist);color:var(--warm-granite)}
footer a:hover{color:var(--bone)}
footer .brand{font:400 44px/1.12 var(--font-geist);letter-spacing:-1.1px;color:var(--bone);margin:0 0 16px}
footer p{font:400 14px/1.6 var(--font-geist);color:var(--warm-granite);margin:0;max-width:420px}
footer .foot-note{margin-top:56px;color:var(--graphite-mid)}
</style>
</head>
<body>
$banner
<nav>
  <span class="mark">Caesar</span>
  <span class="links"><a href="#maps">Maps</a><a href="#queue">Queue</a><a href="#ledger">Ledger</a></span>
  <span class="right">
    <span class="mono$staleAttr">$(if ($stale) { "stale &mdash; swept $agoStr ago" } else { "swept $agoStr ago" })</span>
  </span>
</nav>

<div class="wrap">
  <div id="bar">$bar</div>
</div>

<div class="wrap">
  <section id="maps">
    <div class="sec-head">
      <span class="mono" style="color:#b8b3b0">Frontiers</span>
      <h2>$mapCount maps under way</h2>
    </div>
    <div class="grid">$cards</div>
  </section>

  <section id="queue">
    <div class="sec-head">
      <span class="mono" style="color:#b8b3b0">The gate</span>
      <h2>Nothing crosses into main without your word</h2>
    </div>
    <div class="cta">
      <div class="cap mono"><span class="pulse"></span>$($prs.Count) awaiting your word</div>
      <h2>$gateCap</h2>
      $gateItems
    </div>
  </section>

  <section id="ledger">
    <div class="sec-head">
      <span class="mono" style="color:#b8b3b0">Ledger</span>
      <h2>What the last runs cost</h2>
    </div>
    <table class="ledger">
      <thead><tr><th>Run</th><th>Repo</th><th>Result</th><th>Cost</th><th>Turns</th><th>When</th></tr></thead>
      <tbody>$runRows</tbody>
    </table>
  </section>

  <footer>
    <div class="cols">
      <div>
        <div class="brand">Caesar</div>
        <p>Every Wayfinder map under way, on one surface. Read-only &mdash; every row links out to GitHub, and Caesar does the acting.</p>
      </div>
      <div>
        <div class="h mono">Maps</div>
        <a href="#maps">Frontiers</a><a href="#queue">The gate</a><a href="#ledger">Ledger</a>
      </div>
      <div>
        <div class="h mono">Repos</div>
        $repoLinks
      </div>
      <div>
        <div class="h mono">Runs</div>
        <a href="#ledger">Recent runs</a><a href="#queue">Open PRs</a>
        <span>$slotsUsed / $slotsCap agent slots</span>
      </div>
    </div>
    <div class="foot-note mono">Generated $genStr &middot; Factory, with Numen's two accents &middot; read-only, links out to GitHub</div>
  </footer>
</div>
</body>
</html>
"@

    [IO.File]::WriteAllText($OutFile, $html)
}
