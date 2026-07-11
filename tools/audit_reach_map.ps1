# LilAxol reach-map audit v2 - flat script, sanity counters at each stage.
Add-Type -AssemblyName System.Drawing
$maps = "c:\Users\maram\Dev\GODOT PROJECTS\LilAxol\assets\maps"
$JUMP = 4

$terrBmp = [System.Drawing.Bitmap]::FromFile("$maps\marsh_draft_terrain.png")
$markBmp = [System.Drawing.Bitmap]::FromFile("$maps\marsh_draft_markers.png")
$MW = $terrBmp.Width; $MH = $terrBmp.Height
"SIZE terrain ${MW}x${MH}  markers $($markBmp.Width)x$($markBmp.Height)"

# ---- classify ----
$T = New-Object 'char[,]' $MH, $MW
$marks = New-Object System.Collections.ArrayList
$off = @{}
$tally = @{}
for ($y = 0; $y -lt $MH; $y++) { for ($x = 0; $x -lt $MW; $x++) {
	$p = $terrBmp.GetPixel($x, $y)
	$c = '.'
	if ($p.A -ge 128) {
		$c = '?'
		if ($p.R -eq 122 -and $p.G -eq 74)  { $c = 'E' }
		if ($p.R -eq 140 -and $p.G -eq 140) { $c = 'R' }
		if ($p.R -eq 46  -and $p.B -eq 242) { $c = 'W' }
		if ($p.R -eq 46  -and $p.G -eq 158) { $c = 'C' }
		if ($p.R -eq 210 -and $p.G -eq 180) { $c = 'D' }
		if ($p.R -eq 86  -and $p.G -eq 112) { $c = 'X' }
		if ($c -eq '?') { $k = "terrain #{0:X2}{1:X2}{2:X2}" -f $p.R, $p.G, $p.B; if (-not $off[$k]) { $off[$k] = 0 }; $off[$k]++ }
	}
	$T[$y, $x] = $c
	$ck = [string]$c
	if (-not $tally[$ck]) { $tally[$ck] = 0 }; $tally[$ck]++
	$m = $markBmp.GetPixel($x, $y)
	if ($m.A -ge 128) {
		$mc = '?'
		if ($m.R -eq 255 -and $m.G -eq 0   -and $m.B -eq 255) { $mc = 'S' }
		if ($m.R -eq 255 -and $m.G -eq 215) { $mc = 'F' }
		if ($m.R -eq 0   -and $m.G -eq 255) { $mc = 'P' }
		if ($m.R -eq 255 -and $m.G -eq 34)  { $mc = 'L' }
		if ($m.R -eq 255 -and $m.G -eq 136) { $mc = 'B' }
		if ($m.R -eq 255 -and $m.G -eq 255 -and $m.B -eq 0) { $mc = 'U' }
		if ($m.R -eq 183) { $mc = 'Y' }
		if ($m.R -eq 160) { $mc = 'V' }
		if ($mc -eq '?') { $k = "markers #{0:X2}{1:X2}{2:X2}" -f $m.R, $m.G, $m.B; if (-not $off[$k]) { $off[$k] = 0 }; $off[$k]++ }
		[void]$marks.Add(@($x, $y, [string]$mc))
	}
} }
$terrBmp.Dispose(); $markBmp.Dispose()
"CLASS TALLY: " + (($tally.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '  ')
"OFF-LEGEND: " + $(if ($off.Count) { ($off.GetEnumerator() | ForEach-Object { "$($_.Name) x$($_.Value)" }) -join '; ' } else { 'none' })

# ---- open grids (phase A as painted, phase B plugs broken) ----
$openA = New-Object 'bool[,]' $MH, $MW
$openB = New-Object 'bool[,]' $MH, $MW
for ($x = 0; $x -lt $MW; $x++) { for ($y = 0; $y -lt $MH; $y++) {
	$c = $T[$y, $x]
	foreach ($phase in 0, 1) {
		$solidSet = if ($phase -eq 0) { 'ERCDX' } else { 'EC' }
		$isOpen = $false
		if ($c -eq 'W') { $isOpen = $true }
		elseif ($solidSet.IndexOf([string]$c) -ge 0) { $isOpen = $false }
		else {
			# air (or a breakable in phase B): supported height above floor/water in this column
			$h = 1; $sup = $false; $yy = $y + 1
			while ($yy -lt $MH -and -not $sup) {
				$cc = $T[$yy, $x]
				if ($cc -eq 'W' -or $solidSet.IndexOf([string]$cc) -ge 0) { $sup = $true }
				else { $h++; $yy++ }
			}
			$isOpen = ($sup -and $h -le $JUMP)
			if (-not $isOpen) {
				$dy = -1
				while ($dy -le 1 -and -not $isOpen) {
					$dx = -1
					while ($dx -le 1 -and -not $isOpen) {
						$nx = $x + $dx; $ny = $y + $dy
						if ($nx -ge 0 -and $nx -lt $MW -and $ny -ge 0 -and $ny -lt $MH) {
							if ($T[$ny, $nx] -eq 'C') { $isOpen = $true }
						}
						$dx++
					}
					$dy++
				}
			}
		}
		if ($phase -eq 0) { $openA[$y, $x] = $isOpen } else { $openB[$y, $x] = $isOpen }
	}
} }
$ca = 0; $cb = 0
for ($y = 0; $y -lt $MH; $y++) { for ($x = 0; $x -lt $MW; $x++) { if ($openA[$y, $x]) { $ca++ }; if ($openB[$y, $x]) { $cb++ } } }
"SANITY open cells: phaseA=$ca phaseB=$cb (water alone = $($tally['W']))"

# ---- spawn ----
$sx = -1; $sy = -1; $spawnN = 0
foreach ($m in $marks) { if ($m[2] -eq 'S') { $sx = $m[0]; $sy = $m[1]; $spawnN++ } }
"SPAWN count=$spawnN at ($sx,$sy)"
if ($sx -lt 0) { "FATAL: no spawn"; exit }

# ---- floods (explicit int queues, flat) ----
$reachA = New-Object 'bool[,]' $MH, $MW
$reachB = New-Object 'bool[,]' $MH, $MW
foreach ($phase in 0, 1) {
	# NOTE: never assign a 2D array via an if-EXPRESSION - the pipeline flattens [,] arrays
	if ($phase -eq 0) { $open = $openA; $seen = $reachA } else { $open = $openB; $seen = $reachB }
	if (-not $open[$sy, $sx]) { "WARNING: spawn cell not traversable in phase $phase"; continue }
	$qx = New-Object 'System.Collections.Generic.Queue[int]'
	$qy = New-Object 'System.Collections.Generic.Queue[int]'
	$qx.Enqueue($sx); $qy.Enqueue($sy); $seen[$sy, $sx] = $true
	while ($qx.Count -gt 0) {
		$x = $qx.Dequeue(); $y = $qy.Dequeue()
		$nx = $x + 1; if ($nx -lt $MW  -and -not $seen[$y, $nx] -and $open[$y, $nx]) { $seen[$y, $nx] = $true; $qx.Enqueue($nx); $qy.Enqueue($y) }
		$nx = $x - 1; if ($nx -ge 0   -and -not $seen[$y, $nx] -and $open[$y, $nx]) { $seen[$y, $nx] = $true; $qx.Enqueue($nx); $qy.Enqueue($y) }
		$ny = $y + 1; if ($ny -lt $MH  -and -not $seen[$ny, $x] -and $open[$ny, $x]) { $seen[$ny, $x] = $true; $qx.Enqueue($x); $qy.Enqueue($ny) }
		$ny = $y - 1; if ($ny -ge 0   -and -not $seen[$ny, $x] -and $open[$ny, $x]) { $seen[$ny, $x] = $true; $qx.Enqueue($x); $qy.Enqueue($ny) }
	}
}
$ra = 0; $rb = 0
for ($y = 0; $y -lt $MH; $y++) { for ($x = 0; $x -lt $MW; $x++) { if ($reachA[$y, $x]) { $ra++ }; if ($reachB[$y, $x]) { $rb++ } } }
"SANITY reach cells: phaseA=$ra phaseB=$rb"

# ---- marker report ----
$nameT = @{ 'E'='earth'; 'R'='rubble'; 'W'='water'; 'C'='climb'; 'D'='silt-gate'; 'X'='boulder-gate'; '.'='air'; '?'='off-legend' }
$nameM = @{ 'S'='spawn'; 'F'='friend'; 'P'='portal'; 'L'='leak'; 'B'='barrel'; 'U'='curio'; 'Y'='lilypad'; 'V'='vent'; '?'='UNKNOWN' }
""
"== MARKERS =="
foreach ($m in $marks) {
	$x = $m[0]; $y = $m[1]; $k = $m[2]
	$foot = [string]$T[$y, $x]
	$stat = @()
	if ('ERCDX'.IndexOf($foot) -ge 0) { $stat += "BURIED in $($nameT[$foot])" }
	if (-not $reachB[$y, $x]) { $stat += "unreachable even post-break" }
	elseif (-not $reachA[$y, $x]) { $stat += "post-break only (sealed)" }
	if ($k -eq 'Y') {
		$below = if ($y + 1 -lt $MH) { [string]$T[($y + 1), $x] } else { '.' }
		if ($below -ne 'W') { $stat += "not directly above water (below=$($nameT[$below]))" }
	}
	$s = if ($stat.Count) { $stat -join '; ' } else { 'ok' }
	"{0,-8} ({1,3},{2,2})  {3}" -f $nameM[$k], $x, $y, $s
}

# ---- water bodies ----
""
"== WATER BODIES =="
$comp = New-Object 'int[,]' $MH, $MW
$nc = 0
for ($y0 = 0; $y0 -lt $MH; $y0++) { for ($x0 = 0; $x0 -lt $MW; $x0++) {
	if ($T[$y0, $x0] -ne 'W' -or $comp[$y0, $x0] -ne 0) { continue }
	$nc++
	$qx = New-Object 'System.Collections.Generic.Queue[int]'
	$qy = New-Object 'System.Collections.Generic.Queue[int]'
	$qx.Enqueue($x0); $qy.Enqueue($y0); $comp[$y0, $x0] = $nc
	$size = 0; $ra2 = $false; $rb2 = $false
	$minx = $x0; $maxx = $x0; $miny = $y0; $maxy = $y0
	while ($qx.Count -gt 0) {
		$x = $qx.Dequeue(); $y = $qy.Dequeue(); $size++
		if ($reachA[$y, $x]) { $ra2 = $true }
		if ($reachB[$y, $x]) { $rb2 = $true }
		if ($x -lt $minx) { $minx = $x }; if ($x -gt $maxx) { $maxx = $x }
		if ($y -lt $miny) { $miny = $y }; if ($y -gt $maxy) { $maxy = $y }
		$nx = $x + 1; if ($nx -lt $MW -and $T[$y, $nx] -eq 'W' -and $comp[$y, $nx] -eq 0) { $comp[$y, $nx] = $nc; $qx.Enqueue($nx); $qy.Enqueue($y) }
		$nx = $x - 1; if ($nx -ge 0 -and $T[$y, $nx] -eq 'W' -and $comp[$y, $nx] -eq 0) { $comp[$y, $nx] = $nc; $qx.Enqueue($nx); $qy.Enqueue($y) }
		$ny = $y + 1; if ($ny -lt $MH -and $T[$ny, $x] -eq 'W' -and $comp[$ny, $x] -eq 0) { $comp[$ny, $x] = $nc; $qx.Enqueue($x); $qy.Enqueue($ny) }
		$ny = $y - 1; if ($ny -ge 0 -and $T[$ny, $x] -eq 'W' -and $comp[$ny, $x] -eq 0) { $comp[$ny, $x] = $nc; $qx.Enqueue($x); $qy.Enqueue($ny) }
	}
	$v = if ($ra2) { "reachable" } elseif ($rb2) { "SEALED - opens post-break" } else { "NEVER REACHABLE" }
	"body {0}: {1} cells  span ({2},{3})-({4},{5})  {6}" -f $nc, $size, $minx, $miny, $maxx, $maxy, $v
} }

# ---- edges ----
""
"== EDGES =="
$issues = 0
for ($y = 0; $y -lt $MH; $y++) { foreach ($x in 0, ($MW - 1)) {
	if ($T[$y, $x] -ne 'W') { continue }
	$hasP = $false
	foreach ($m in $marks) { if ($m[2] -eq 'P' -and [math]::Abs($m[0] - $x) -le 4 -and [math]::Abs($m[1] - $y) -le 4) { $hasP = $true } }
	if (-not $hasP) { "water at edge ($x,$y) with NO portal within 4 cells"; $issues++ }
} }
for ($x = 0; $x -lt $MW; $x++) { if ($T[($MH - 1), $x] -eq 'W') { "water leaks out the BOTTOM edge at ($x,$($MH-1))"; $issues++ } }
if ($issues -eq 0) { "all edge water has portals; bottom sealed" }

# ---- climb strips ----
""
"== CLIMB STRIPS =="
$cseen = New-Object 'bool[,]' $MH, $MW
for ($y0 = 0; $y0 -lt $MH; $y0++) { for ($x0 = 0; $x0 -lt $MW; $x0++) {
	if ($T[$y0, $x0] -ne 'C' -or $cseen[$y0, $x0]) { continue }
	$qx = New-Object 'System.Collections.Generic.Queue[int]'
	$qy = New-Object 'System.Collections.Generic.Queue[int]'
	$qx.Enqueue($x0); $qy.Enqueue($y0); $cseen[$y0, $x0] = $true
	$top = $y0; $bot = $y0; $grasp = $false; $n = 0
	while ($qx.Count -gt 0) {
		$x = $qx.Dequeue(); $y = $qy.Dequeue(); $n++
		if ($y -lt $top) { $top = $y }; if ($y -gt $bot) { $bot = $y }
		$nx = $x + 1; if ($nx -lt $MW) { if ($T[$y, $nx] -eq 'C' -and -not $cseen[$y, $nx]) { $cseen[$y, $nx] = $true; $qx.Enqueue($nx); $qy.Enqueue($y) } elseif ($reachA[$y, $nx]) { $grasp = $true } }
		$nx = $x - 1; if ($nx -ge 0) { if ($T[$y, $nx] -eq 'C' -and -not $cseen[$y, $nx]) { $cseen[$y, $nx] = $true; $qx.Enqueue($nx); $qy.Enqueue($y) } elseif ($reachA[$y, $nx]) { $grasp = $true } }
		$ny = $y + 1; if ($ny -lt $MH) { if ($T[$ny, $x] -eq 'C' -and -not $cseen[$ny, $x]) { $cseen[$ny, $x] = $true; $qx.Enqueue($x); $qy.Enqueue($ny) } elseif ($reachA[$ny, $x]) { $grasp = $true } }
		$ny = $y - 1; if ($ny -ge 0) { if ($T[$ny, $x] -eq 'C' -and -not $cseen[$ny, $x]) { $cseen[$ny, $x] = $true; $qx.Enqueue($x); $qy.Enqueue($ny) } elseif ($reachA[$ny, $x]) { $grasp = $true } }
	}
	$v = if ($grasp) { "graspable" } else { "STRANDED - nothing reachable beside it" }
	"strip x=$x0 rows $top-$bot  $n cells  $v"
} }

# ---- overlay ----
$sky = [System.Drawing.Color]::FromArgb(255, 187, 215, 234)
$cmap = @{ 'E' = @(122,74,35); 'R' = @(140,140,140); 'W' = @(46,111,242); 'C' = @(46,158,63); 'D' = @(210,180,140); 'X' = @(86,112,126); '?' = @(255,0,0) }
$mmap = @{ 'S' = @(255,0,255); 'F' = @(255,215,0); 'P' = @(0,255,255); 'L' = @(255,34,34); 'B' = @(255,136,0); 'U' = @(255,255,0); 'Y' = @(183,240,74); 'V' = @(160,32,240); '?' = @(0,0,0) }
$bmp = New-Object System.Drawing.Bitmap($MW, $MH)
for ($y = 0; $y -lt $MH; $y++) { for ($x = 0; $x -lt $MW; $x++) {
	$c = [string]$T[$y, $x]
	if ($c -eq '.') { $bmp.SetPixel($x, $y, $sky); continue }
	$v = $cmap[$c]
	if ($c -eq 'W') {
		if (-not $reachB[$y, $x])     { $v = @(220, 40, 40) }
		elseif (-not $reachA[$y, $x]) { $v = @(235, 180, 60) }
	}
	$bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $v[0], $v[1], $v[2]))
} }
foreach ($m in $marks) { $v = $mmap[$m[2]]; $bmp.SetPixel($m[0], $m[1], [System.Drawing.Color]::FromArgb(255, $v[0], $v[1], $v[2])) }
$big = New-Object System.Drawing.Bitmap(($MW * 6), ($MH * 6))
$g = [System.Drawing.Graphics]::FromImage($big)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.DrawImage($bmp, 0, 0, ($MW * 6), ($MH * 6))
$big.Save("$maps\marsh_draft_audit.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $big.Dispose()
""
"overlay: $maps\marsh_draft_audit.png  (red water = never reachable, amber = post-break only)"

