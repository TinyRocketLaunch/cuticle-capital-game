param(
    [string]$EconomyPath = "godot/data/economy.json"
)

if (-not (Test-Path $EconomyPath)) {
    Write-Error "Economy file not found: $EconomyPath"
    exit 1
}

$json = Get-Content $EconomyPath | ConvertFrom-Json
$errors = @()

if (-not $json.services -and -not $json.service) { $errors += 'Missing services/service config.' }
if (-not $json.starting_state) { $errors += 'Missing starting_state config.' }
if (-not $json.save) { $errors += 'Missing save config.' }
if (-not $json.queue) { $errors += 'Missing queue config.' }
if (-not $json.staff) { $errors += 'Missing staff config.' }

if ($json.upgrades.Count -lt 3) {
    $errors += 'Expected at least 3 upgrades for prototype pacing.'
}

if ($json.services) {
    if ($json.services.Count -lt 2) {
        $errors += 'Expected at least 2 services (manicure + pedicure) in current scope.'
    }

    foreach ($s in $json.services) {
        if (-not $s.id) { $errors += 'A service is missing id.' }
        if (-not $s.name) { $errors += "Service '$($s.id)' is missing name." }
        if ([double]$s.duration_sec -le 0) { $errors += "Service '$($s.id)' duration_sec must be > 0." }
        if ([double]$s.payout -le 0) { $errors += "Service '$($s.id)' payout must be > 0." }
    }
}

foreach ($u in $json.upgrades) {
    if (-not $u.id) { $errors += 'An upgrade is missing id.' }
    if (-not $u.title) { $errors += "Upgrade '$($u.id)' is missing title." }
    if ([double]$u.base_cost -le 0) { $errors += "Upgrade '$($u.id)' base_cost must be > 0." }
    if ([double]$u.cost_multiplier -le 1) { $errors += "Upgrade '$($u.id)' cost_multiplier should be > 1." }
    if (-not $u.effects) { $errors += "Upgrade '$($u.id)' missing effects object." }
}

if ($json.locations.Count -lt 2) {
    $errors += 'Expected at least 2 locations (bedroom + suite) in MVP.'
}

if ($json.missions -and $json.missions.Count -lt 1) {
    $errors += 'Expected at least 1 mission/objective.'
}

for ($i = 1; $i -lt $json.locations.Count; $i++) {
    $curr = [double]$json.locations[$i].unlock_cost
    $prev = [double]$json.locations[$i - 1].unlock_cost
    if ($curr -lt $prev) {
        $errors += "Location unlock_cost decreases at index $i."
    }
}

if ($errors.Count -gt 0) {
    Write-Host 'QA FAILED' -ForegroundColor Red
    $errors | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host 'QA PASSED: economy sanity checks' -ForegroundColor Green
