#requires -Version 5.1
[CmdletBinding()]
param()

# Dependency-free regression tests. Run with Windows PowerShell 5.1:
# powershell.exe -NoProfile -NonInteractive -File scripts/test-windows.ps1
# All preference data below is synthetic; no live registry or desktop access.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$script:PrismTestsPassed = 0
$repoRoot = Split-Path -Parent $PSScriptRoot
$installerPath = Join-Path $repoRoot 'adapters\windows\install.ps1'
$restorePath = Join-Path $repoRoot 'adapters\windows\restore.ps1'

function Assert-PrismTest {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-PrismTestEqual {
    param($Actual, $Expected, [string]$Message)
    $actualJson = ConvertTo-Json -InputObject $Actual -Depth 12 -Compress
    $expectedJson = ConvertTo-Json -InputObject $Expected -Depth 12 -Compress
    if ($actualJson -cne $expectedJson) { throw "${Message}: expected $expectedJson; got $actualJson" }
}

function Assert-PrismTestThrows {
    param([scriptblock]$Action, [string]$Message)
    $threw = $false
    try { & $Action | Out-Null } catch { $threw = $true }
    Assert-PrismTest $threw $Message
}

function Invoke-PrismTest {
    param([string]$Name, [scriptblock]$Action)
    try { & $Action } catch { throw "${Name}: $($_.Exception.Message)" }
    $script:PrismTestsPassed++
    Write-Output "PASS $Name"
}

Invoke-PrismTest 'PowerShell parsing and side-effect-free LibraryOnly entry point' {
    foreach ($path in @($PSCommandPath, $installerPath, $restorePath)) {
        $parseTokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$parseTokens, [ref]$parseErrors)
        Assert-PrismTest ($parseErrors.Count -eq 0) "Parse errors in ${path}: $($parseErrors -join ', ')"
        if ($path -eq $installerPath) {
            # Fail before loading if executable code has moved ahead of the
            # library-only return. Merely defining functions has no side effects.
            Assert-PrismTest ($null -eq $ast.BeginBlock -and $null -eq $ast.ProcessBlock -and $null -eq $ast.DynamicParamBlock) 'Installer has unexpected pre-library executable blocks.'
            $executable = @($ast.EndBlock.Statements | Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] })
            Assert-PrismTest ($executable.Count -gt 0) 'Installer is missing its LibraryOnly guard.'
            Assert-PrismTest ($executable[0].Extent.Text -match '^if\s*\(\s*\$LibraryOnly\s*\)\s*\{\s*return\s*\}$') 'Executable code precedes or changes the LibraryOnly guard; refusing to load.'
        }
    }
}

. $installerPath -LibraryOnly

# Replace every stateful helper immediately after the guarded library load.
# The persistence helper is exercised against this in-memory dictionary only.
$script:PrismTestRegistry = @{}
function Get-PrismRegistryEntry {
    param([string]$Path, [AllowEmptyString()] [string]$Name)
    $id = $Path + '|' + $Name
    if (-not $script:PrismTestRegistry.ContainsKey($id)) { throw "Missing synthetic registry entry: $id" }
    $script:PrismTestRegistry[$id]
}
function Get-PrismRegistrySnapshot { throw 'Live registry snapshots are forbidden in pure tests.' }
function Set-PrismRegistryEntry { throw 'Registry writes are forbidden in pure tests.' }
function Send-PrismSettingsChanged { throw 'Desktop notifications are forbidden in pure tests.' }
function Assert-PrismInteractiveSession { throw 'Interactive-session access is forbidden in pure tests.' }

function New-PrismTestPalette {
    $palette = [byte[]]::new(32)
    for ($index = 0; $index -lt 7; $index++) {
        $palette[$index * 4] = 0x12
        $palette[$index * 4 + 1] = 0x34
        $palette[$index * 4 + 2] = 0x56
        $palette[$index * 4 + 3] = 255
    }
    [Array]::Copy([byte[]]@(0x12, 0x34, 0x56, 0), 0, $palette, 28, 4)
    return ,$palette
}

function New-PrismTestBeforeEntries {
    param([int]$ColorizationAlpha = 196)
    $oldAccent = ConvertTo-PrismAccent -Hex '#123456' -ColorizationAlpha $ColorizationAlpha
    $oldStart = ConvertTo-PrismAccent -Hex '#0F2B46'
    $values = @{
        AppsUseLightTheme = '1'
        SystemUsesLightTheme = '1'
        AccentPalette = [Convert]::ToBase64String((New-PrismTestPalette))
        AccentColorMenu = $oldAccent.Abgr.ToString([Globalization.CultureInfo]::InvariantCulture)
        StartColorMenu = $oldStart.Abgr.ToString([Globalization.CultureInfo]::InvariantCulture)
        AccentColor = $oldAccent.Abgr.ToString([Globalization.CultureInfo]::InvariantCulture)
        ColorizationColor = $oldAccent.Argb.ToString([Globalization.CultureInfo]::InvariantCulture)
        ColorPrevalence = '0'
    }
    foreach ($setting in @(Get-PrismWindowsSettings)) {
        $kind = if ($setting.Name -eq 'AccentPalette') { 'Binary' } else { 'DWord' }
        [pscustomobject]@{
            Path = $setting.Path
            Name = $setting.Name
            Before = [pscustomobject]@{ Name = $setting.Name; Exists = $true; Kind = $kind; Data = $values[$setting.Name] }
        }
    }
}

Invoke-PrismTest 'ARGB/ABGR channel order and strict color input' {
    $accent = ConvertTo-PrismAccent -Hex '#123456'
    Assert-PrismTestEqual $accent.Argb.ToString('X8') 'FF123456' 'Default ARGB channel order'
    Assert-PrismTestEqual $accent.Abgr.ToString('X8') 'FF563412' 'Opaque ABGR channel order'
    foreach ($alpha in @(0, 128, 196, 255)) {
        $accent = ConvertTo-PrismAccent -Hex '#e866af' -ColorizationAlpha $alpha
        Assert-PrismTestEqual $accent.Argb.ToString('X8') ($alpha.ToString('X2') + 'E866AF') 'Explicit alpha must affect ARGB only'
        Assert-PrismTestEqual $accent.Abgr.ToString('X8') 'FFAF66E8' 'ABGR must remain opaque'
    }
    foreach ($hex in @('pink', '#FFF', '#12345678', '#12GG56', ' #123456', '#123456 ')) {
        Assert-PrismTestThrows { ConvertTo-PrismAccent -Hex $hex } "Accepted invalid accent: $hex"
    }
    foreach ($alpha in @(-1, 256)) {
        Assert-PrismTestThrows { ConvertTo-PrismAccent -Hex '#123456' -ColorizationAlpha $alpha } 'Accepted an out-of-range alpha'
    }
}

Invoke-PrismTest 'Seven weighted shades, exact index 3, opaque entries and unchanged tail' {
    $original = New-PrismTestPalette
    $originalHex = [BitConverter]::ToString($original)
    $palette = New-PrismExplorerAccentPalette -Hex '#E866AF' -ExistingPalette $original
    Assert-PrismTest ($palette -is [byte[]]) 'Palette must remain a byte array'
    Assert-PrismTestEqual $palette.Length 32 'Palette byte count'
    Assert-PrismTestEqual ([BitConverter]::ToString($palette)) 'F5-BA-DB-FF-F0-9C-CB-FF-EC-82-BD-FF-E8-66-AF-FF-BE-54-90-FF-97-42-72-FF-68-2E-4F-FF-12-34-56-00' '55/35/18 percent white, base, then 18/35/55 percent black ramp'
    Assert-PrismTestEqual ([BitConverter]::ToString($original)) $originalHex 'Input palette must not be mutated'
    foreach ($hex in @('#000000', '#FFFFFF', '#123456', '#E866AF')) {
        $palette = New-PrismExplorerAccentPalette -Hex $hex -ExistingPalette $original
        Assert-PrismTestEqual ([BitConverter]::ToString($palette, 12, 3).Replace('-', '')) $hex.Substring(1) 'Index 3 must contain the exact accent'
        Assert-PrismTestEqual ([BitConverter]::ToString($palette, 28, 4)) '12-34-56-00' 'All four unknown tail bytes must survive'
        for ($shade = 0; $shade -lt 7; $shade++) {
            Assert-PrismTestEqual ([int]$palette[$shade * 4 + 3]) 255 'First seven colors must be opaque'
            if ($shade -gt 0) {
                for ($channel = 0; $channel -lt 3; $channel++) {
                    Assert-PrismTest ($palette[$shade * 4 + $channel] -le $palette[($shade - 1) * 4 + $channel]) 'Ramp must run light to dark per channel'
                }
            }
        }
    }
    [Array]::Copy([byte[]]@(0, 128, 254, 1), 0, $original, 28, 4)
    $palette = New-PrismExplorerAccentPalette -Hex '#123456' -ExistingPalette $original
    Assert-PrismTestEqual ([BitConverter]::ToString($palette, 28, 4)) '00-80-FE-01' 'Unknown tail must not be interpreted as an opaque color'
    Assert-PrismTestEqual ([BitConverter]::ToString((New-PrismExplorerAccentPalette -Hex '#123456' -ExistingPalette $original))) ([BitConverter]::ToString($palette)) 'Palette generation must be deterministic'
}

Invoke-PrismTest 'Unexpected palette and typed registry formats fail closed' {
    foreach ($length in @(0, 28, 31, 33, 36)) {
        Assert-PrismTestThrows { New-PrismExplorerAccentPalette -Hex '#123456' -ExistingPalette ([byte[]]::new($length)) } "Accepted palette length $length"
    }
    for ($index = 0; $index -lt 7; $index++) {
        $invalid = New-PrismTestPalette
        $invalid[$index * 4 + 3] = 254
        Assert-PrismTestThrows { New-PrismExplorerAccentPalette -Hex '#123456' -ExistingPalette $invalid } "Accepted non-opaque entry $index"
    }
    foreach ($entry in @(
        [pscustomobject]@{ Name = 'AccentColorMenu'; Exists = $true; Kind = 'String'; Data = '123' },
        [pscustomobject]@{ Name = 'AccentColorMenu'; Exists = $true; Kind = 'DWord'; Data = '4294967295' },
        [pscustomobject]@{ Name = 'AccentColorMenu'; Exists = 'true'; Kind = 'DWord'; Data = '1' },
        [pscustomobject]@{ Name = 'AccentColorMenu'; Exists = $false; Kind = 'DWord'; Data = '1' },
        [pscustomobject]@{ Name = 'AccentPalette'; Exists = $true; Kind = 'Binary'; Data = 'not base64!' },
        [pscustomobject]@{ Name = 'AccentPalette'; Exists = $true; Kind = 'DWord'; Data = '1' }
    )) {
        Assert-PrismTestThrows { Assert-PrismWindowsEntryFormat -Name $entry.Name -Entry $entry } 'Accepted malformed typed preference data'
    }
    $absent = [pscustomobject]@{ Name = 'AccentColorMenu'; Exists = $false; Kind = $null; Data = $null }
    Assert-PrismTestThrows { Assert-PrismWindowsEntryFormat -Name 'AccentColorMenu' -Entry $absent -RequireExisting } 'Accepted an absent required value'
    Assert-PrismTestThrows { Assert-PrismWindowsEntryFormat -Name 'AccentPalette' -Entry $absent } 'Accepted mismatched snapshot name'
}

Invoke-PrismTest 'Snapshot schema 1/2 allowlists retain five/eight ordered values' {
    $legacy = @(Get-PrismWindowsSettings -SchemaVersion 1)
    $current = @(Get-PrismWindowsSettings -SchemaVersion 2)
    Assert-PrismTestEqual $legacy.Count 5 'Schema 1 count'
    Assert-PrismTestEqual ($legacy.Name -join ',') 'AppsUseLightTheme,SystemUsesLightTheme,AccentColor,ColorizationColor,ColorPrevalence' 'Legacy allowlist must not gain Explorer values'
    Assert-PrismTestEqual $current.Count 8 'Schema 2 count'
    Assert-PrismTestEqual ($current.Name -join ',') 'AppsUseLightTheme,SystemUsesLightTheme,AccentPalette,AccentColorMenu,StartColorMenu,AccentColor,ColorizationColor,ColorPrevalence' 'Explorer sources must precede derived DWM values'
    Assert-PrismTestEqual @(Get-PrismWindowsSettings) $current 'Current schema must be the default'
    Assert-PrismTestEqual @($current | ForEach-Object { $_.Path + '|' + $_.Name } | Select-Object -Unique).Count 8 'No duplicate owned preferences'
    Assert-PrismTestThrows { Get-PrismWindowsSettings -SchemaVersion 3 } 'Accepted an unsupported schema'
}

Invoke-PrismTest 'Pure change plan preserves alpha, emits exact menu colors and validates snapshots' {
    $before = @(New-PrismTestBeforeEntries)
    $beforeJson = ConvertTo-Json -InputObject $before -Depth 12 -Compress
    $changes = @(New-PrismWindowsChanges -Hex '#E866AF' -BeforeEntries $before)
    Assert-PrismTestEqual $changes.Count 8 'Planned preference count'
    Assert-PrismTestEqual ($changes.Name -join ',') (@(Get-PrismWindowsSettings).Name -join ',') 'Plan must retain controlled write order'
    $byName = @{}
    foreach ($change in $changes) {
        $byName[$change.Name] = $change
        Assert-PrismWindowsEntryFormat -Name $change.Name -Entry $change.Applied -RequireExisting
    }
    foreach ($name in @('AccentColor', 'AccentColorMenu')) {
        Assert-PrismTestEqual ([int]::Parse($byName[$name].Applied.Data).ToString('X8')) 'FFAF66E8' 'Base menu/DWM ABGR'
    }
    Assert-PrismTestEqual ([int]::Parse($byName.StartColorMenu.Applied.Data).ToString('X8')) 'FF9054BE' 'Start menu must use darker shade index 4'
    Assert-PrismTestEqual ([int]::Parse($byName.ColorizationColor.Applied.Data).ToString('X8')) 'C4E866AF' 'Existing ColorizationColor alpha must be preserved'
    Assert-PrismTestEqual $byName.AccentPalette.Applied.Kind 'Binary' 'Palette registry type'
    Assert-PrismTestEqual ([BitConverter]::ToString([Convert]::FromBase64String($byName.AccentPalette.Applied.Data), 28, 4)) '12-34-56-00' 'Typed palette tail'
    foreach ($name in @('AppsUseLightTheme', 'SystemUsesLightTheme')) { Assert-PrismTestEqual $byName[$name].Applied.Data '0' 'Dark mode preference' }
    Assert-PrismTestEqual $byName.ColorPrevalence.Applied.Data '1' 'Title-bar accent preference'
    Assert-PrismTestEqual (ConvertTo-Json -InputObject $before -Depth 12 -Compress) $beforeJson 'Planning must not mutate the snapshot'
    foreach ($alpha in @(0, 128, 255)) {
        $alphaChanges = @(New-PrismWindowsChanges -Hex '#E866AF' -BeforeEntries @(New-PrismTestBeforeEntries -ColorizationAlpha $alpha))
        $colorization = $alphaChanges | Where-Object { $_.Name -eq 'ColorizationColor' }
        Assert-PrismTestEqual ([int]::Parse($colorization.Applied.Data).ToString('X8')) ($alpha.ToString('X2') + 'E866AF') 'Planner must retain any existing alpha byte'
    }
    foreach ($name in @('AccentPalette', 'AccentColorMenu', 'StartColorMenu', 'ColorizationColor')) {
        $invalid = @(New-PrismTestBeforeEntries)
        $missing = $invalid | Where-Object { $_.Name -eq $name }
        $missing.Before = [pscustomobject]@{ Name = $name; Exists = $false; Kind = $null; Data = $null }
        Assert-PrismTestThrows { New-PrismWindowsChanges -Hex '#E866AF' -BeforeEntries $invalid } "Accepted missing required preference $name"
    }
    Assert-PrismTestThrows { New-PrismWindowsChanges -Hex '#E866AF' -BeforeEntries $before[0..6] } 'Accepted incomplete snapshot'
    Assert-PrismTestThrows { New-PrismWindowsChanges -Hex '#E866AF' -BeforeEntries ($before + $before[0]) } 'Accepted duplicate snapshot entry'
    $invalid = @(New-PrismTestBeforeEntries)
    $invalid[0].Path = 'Unexpected\Registry\Path'
    Assert-PrismTestThrows { New-PrismWindowsChanges -Hex '#E866AF' -BeforeEntries $invalid } 'Accepted a path outside the allowlist'
}

Invoke-PrismTest 'Typed snapshot comparisons distinguish data, type and existence' {
    $entry = [pscustomobject]@{ Name = 'AccentPalette'; Exists = $true; Kind = 'Binary'; Data = 'AQIDBA==' }
    $same = [pscustomobject]@{ Name = 'AccentPalette'; Exists = $true; Kind = 'Binary'; Data = 'AQIDBA==' }
    Assert-PrismTest (Test-PrismRegistryEntry $entry $same) 'Identical binary snapshots must match'
    $same.Data = 'AQIDBQ=='
    Assert-PrismTest (-not (Test-PrismRegistryEntry $entry $same)) 'Different binary bytes must not match'
    $same.Data = $entry.Data
    $same.Kind = 'String'
    Assert-PrismTest (-not (Test-PrismRegistryEntry $entry $same)) 'Different registry types must not match'
    $absent = [pscustomobject]@{ Name = 'AccentPalette'; Exists = $false; Kind = $null; Data = $null }
    Assert-PrismTest (-not (Test-PrismRegistryEntry $entry $absent)) 'Absent and present values must not match'
    Assert-PrismTest (Test-PrismRegistryEntry $absent $absent) 'Two absent snapshots must match'
}

Invoke-PrismTest 'In-memory persistence checks detect both reverted DWM values and verify rollback' {
    $changes = @(New-PrismWindowsChanges -Hex '#E866AF' -BeforeEntries @(New-PrismTestBeforeEntries))
    $script:PrismTestRegistry = @{}
    foreach ($change in $changes) { $script:PrismTestRegistry[$change.Path + '|' + $change.Name] = $change.Applied }
    $checks = @(Get-PrismPersistedChecks -Changes $changes)
    Assert-PrismTestEqual $checks.Count 8 'All owned preferences must be re-read'
    Assert-PrismTestEqual @($checks | Where-Object { -not $_.Matches }).Count 0 'Unchanged applied snapshots must match'
    foreach ($change in $changes) {
        if ($change.Name -in @('AccentColor', 'ColorizationColor')) {
            $script:PrismTestRegistry[$change.Path + '|' + $change.Name] = $change.Before
        }
    }
    $checks = @(Get-PrismPersistedChecks -Changes $changes)
    $mismatches = @($checks | Where-Object { -not $_.Matches })
    Assert-PrismTestEqual $mismatches.Count 2 'Both simulated DWM reversions must be detected'
    Assert-PrismTestEqual ($mismatches.Name -join ',') 'AccentColor,ColorizationColor' 'Only reverted DWM values should mismatch'
    foreach ($mismatch in $mismatches) {
        $change = $changes | Where-Object { $_.Name -eq $mismatch.Name }
        Assert-PrismTestEqual $mismatch.Expected $change.Applied 'Mismatch must expose typed expected data'
        Assert-PrismTestEqual $mismatch.Actual $change.Before 'Mismatch must expose typed actual data'
    }
    $written = [Collections.Generic.List[object]]::new()
    foreach ($change in $changes) {
        $written.Add($change)
        $script:PrismTestRegistry[$change.Path + '|' + $change.Name] = $change.Before
    }
    $rollbackChecks = @(Get-PrismPersistedChecks -Changes @($written) -ExpectedField Before)
    Assert-PrismTestEqual $rollbackChecks.Count 8 'Rollback must re-read all written values'
    Assert-PrismTestEqual @($rollbackChecks | Where-Object { -not $_.Matches }).Count 0 'Restored typed snapshots must match Before'
}

Write-Output "$script:PrismTestsPassed pure Windows regression groups passed on PowerShell $($PSVersionTable.PSVersion). No live registry access, notifications, deployment, or file writes."
