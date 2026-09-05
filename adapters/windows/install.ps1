[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ThemeJson,
    [string]$BackupRoot,
    [Parameter(DontShow = $true)] [switch]$LibraryOnly
)

# Shared with restore.ps1. Loading -LibraryOnly defines functions only.
function Get-PrismWindowsSettings {
    param([ValidateSet(1, 2)] [int]$SchemaVersion = 2)
    @(
        [pscustomobject]@{ Path = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme' },
        [pscustomobject]@{ Path = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme' }
        # Explorer owns the source accent preferences on the supported Windows
        # 10 layout. Write them before the derived DWM values.
        if ($SchemaVersion -eq 2) {
            [pscustomobject]@{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name = 'AccentPalette' }
            [pscustomobject]@{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name = 'AccentColorMenu' }
            [pscustomobject]@{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name = 'StartColorMenu' }
        }
        [pscustomobject]@{ Path = 'Software\Microsoft\Windows\DWM'; Name = 'AccentColor' },
        [pscustomobject]@{ Path = 'Software\Microsoft\Windows\DWM'; Name = 'ColorizationColor' },
        [pscustomobject]@{ Path = 'Software\Microsoft\Windows\DWM'; Name = 'ColorPrevalence' }
    )
}

function ConvertTo-PrismAccent {
    param(
        [Parameter(Mandatory = $true)] [string]$Hex,
        [ValidateRange(0, 255)] [int]$ColorizationAlpha = 255
    )
    if ($Hex -notmatch '^#[0-9a-fA-F]{6}$') { throw 'colors.accent must be a six-digit #RRGGBB color.' }
    $rgb = $Hex.Substring(1)
    [pscustomobject]@{
        Argb = [Convert]::ToInt32(($ColorizationAlpha.ToString('X2') + $rgb), 16)
        Abgr = [Convert]::ToInt32(('FF' + $rgb.Substring(4, 2) + $rgb.Substring(2, 2) + $rgb.Substring(0, 2)), 16)
    }
}

function Assert-PrismExplorerAccentPalette {
    param([Parameter(Mandatory = $true)] [AllowEmptyCollection()] [byte[]]$Palette)
    if ($Palette.Length -ne 32) { throw 'Unsupported AccentPalette: expected exactly 32 bytes.' }
    for ($index = 0; $index -lt 7; $index++) {
        if ($Palette[$index * 4 + 3] -ne 255) {
            throw 'Unsupported AccentPalette: the first seven entries must be opaque RGBA colors.'
        }
    }
}

function New-PrismExplorerAccentPalette {
    param(
        [Parameter(Mandatory = $true)] [string]$Hex,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [byte[]]$ExistingPalette
    )
    $null = ConvertTo-PrismAccent -Hex $Hex
    Assert-PrismExplorerAccentPalette -Palette $ExistingPalette
    $rgb = @(
        [Convert]::ToInt32($Hex.Substring(1, 2), 16),
        [Convert]::ToInt32($Hex.Substring(3, 2), 16),
        [Convert]::ToInt32($Hex.Substring(5, 2), 16)
    )
    # A deterministic project ramp, not a claim to reproduce Windows' private
    # shade-generation algorithm. Entry 3 is exactly the requested accent.
    $mixAmounts = @(0.55, 0.35, 0.18, 0.0, -0.18, -0.35, -0.55)
    $palette = [byte[]]::new(32)
    for ($shade = 0; $shade -lt 7; $shade++) {
        $amount = [double]$mixAmounts[$shade]
        $target = if ($amount -gt 0) { 255 } else { 0 }
        for ($channel = 0; $channel -lt 3; $channel++) {
            $value = $rgb[$channel] + ($target - $rgb[$channel]) * [Math]::Abs($amount)
            $palette[$shade * 4 + $channel] = [byte][Math]::Round($value, [MidpointRounding]::AwayFromZero)
        }
        $palette[$shade * 4 + 3] = 255
    }
    # The final entry has an unknown purpose and is never reinterpreted.
    [Array]::Copy($ExistingPalette, 28, $palette, 28, 4)
    return ,$palette
}

function Assert-PrismWindowsEntryFormat {
    param([string]$Name, $Entry, [switch]$RequireExisting)
    if ($null -eq $Entry -or $Entry.Name -cne $Name -or $Entry.Exists -isnot [bool]) {
        throw "Malformed typed preference snapshot for $Name."
    }
    if (-not $Entry.Exists) {
        if ($RequireExisting) { throw "Required existing Windows preference is absent: $Name" }
        if ($null -ne $Entry.Kind -or $null -ne $Entry.Data) { throw "Absent preference has unexpected type/data: $Name" }
        return
    }
    $expectedKind = if ($Name -eq 'AccentPalette') { 'Binary' } else { 'DWord' }
    if ($Entry.Kind -cne $expectedKind) { throw "Unsupported registry format for ${Name}: expected $expectedKind." }
    if ($expectedKind -eq 'DWord') { $null = [int]::Parse([string]$Entry.Data, [Globalization.CultureInfo]::InvariantCulture) }
    else { Assert-PrismExplorerAccentPalette -Palette ([Convert]::FromBase64String([string]$Entry.Data)) }
}

function New-PrismWindowsChanges {
    param(
        [Parameter(Mandatory = $true)] [string]$Hex,
        [Parameter(Mandatory = $true)] [object[]]$BeforeEntries
    )
    # Pure planning: supplied typed snapshots are validated before any writes.
    $settings = @(Get-PrismWindowsSettings)
    $allowed = @($settings | ForEach-Object { $_.Path + '|' + $_.Name })
    $beforeById = @{}
    foreach ($entry in $BeforeEntries) {
        $id = [string]$entry.Path + '|' + [string]$entry.Name
        if ($allowed -notcontains $id -or $beforeById.ContainsKey($id) -or $entry.Before.Name -cne $entry.Name) {
            throw 'Unexpected, duplicate, or incomplete Windows preference snapshot.'
        }
        $beforeById[$id] = $entry.Before
        $required = $entry.Name -in @('AccentPalette', 'AccentColorMenu', 'StartColorMenu', 'ColorizationColor')
        Assert-PrismWindowsEntryFormat -Name $entry.Name -Entry $entry.Before -RequireExisting:$required
    }
    if ($beforeById.Count -ne $settings.Count) { throw 'The Windows preference snapshot is incomplete.' }
    $explorerPath = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
    $dwmPath = 'Software\Microsoft\Windows\DWM'
    $existingPalette = [Convert]::FromBase64String([string]$beforeById[$explorerPath + '|AccentPalette'].Data)
    $palette = New-PrismExplorerAccentPalette -Hex $Hex -ExistingPalette $existingPalette
    $colorization = [int]::Parse([string]$beforeById[$dwmPath + '|ColorizationColor'].Data, [Globalization.CultureInfo]::InvariantCulture)
    $alpha = [Convert]::ToInt32($colorization.ToString('X8').Substring(0, 2), 16)
    $accent = ConvertTo-PrismAccent -Hex $Hex -ColorizationAlpha $alpha
    $startHex = '#' + [BitConverter]::ToString($palette, 16, 3).Replace('-', '')
    $startAccent = ConvertTo-PrismAccent -Hex $startHex
    foreach ($setting in $settings) {
        $kind = 'DWord'
        $data = switch ($setting.Name) {
            'AppsUseLightTheme' { '0' }
            'SystemUsesLightTheme' { '0' }
            'AccentPalette' { $kind = 'Binary'; [Convert]::ToBase64String($palette) }
            'AccentColorMenu' { $accent.Abgr.ToString([Globalization.CultureInfo]::InvariantCulture) }
            'StartColorMenu' { $startAccent.Abgr.ToString([Globalization.CultureInfo]::InvariantCulture) }
            'AccentColor' { $accent.Abgr.ToString([Globalization.CultureInfo]::InvariantCulture) }
            'ColorizationColor' { $accent.Argb.ToString([Globalization.CultureInfo]::InvariantCulture) }
            'ColorPrevalence' { '1' }
            default { throw "Unknown owned Windows preference: $($setting.Name)" }
        }
        [pscustomobject]@{
            Path = $setting.Path
            Name = $setting.Name
            Before = $beforeById[$setting.Path + '|' + $setting.Name]
            Applied = [pscustomobject]@{ Name = $setting.Name; Exists = $true; Kind = $kind; Data = $data }
        }
    }
}

function Assert-PrismInteractiveSession {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $session = (Get-Process -Id $PID).SessionId
    if ($session -eq 0 -or $identity.IsSystem -or -not [Environment]::UserInteractive) {
        throw 'No settings changed: run as the signed-in user in their interactive session. Session 0/service tasks cannot notify the desktop. No automatic task or UI fallback is used.'
    }
}

function Get-PrismRegistryEntry {
    param([string]$Path, [AllowEmptyString()] [string]$Name)
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Path, $false)
    try {
        if (-not $key -or $key.GetValueNames() -notcontains $Name) {
            return [pscustomobject]@{ Name = $Name; Exists = $false; Kind = $null; Data = $null }
        }
        $kind = $key.GetValueKind($Name).ToString()
        $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $data = switch ($kind) {
            'Binary' { [Convert]::ToBase64String([byte[]]$value) }
            'None' { [Convert]::ToBase64String([byte[]]$value) }
            'DWord' { ([int]$value).ToString([Globalization.CultureInfo]::InvariantCulture) }
            'QWord' { ([long]$value).ToString([Globalization.CultureInfo]::InvariantCulture) }
            'MultiString' { ,([string[]]$value) }
            'String' { [string]$value }
            'ExpandString' { [string]$value }
            default { throw "Unsupported registry type: $kind" }
        }
        [pscustomobject]@{ Name = $Name; Exists = $true; Kind = $kind; Data = $data }
    } finally { if ($key) { $key.Dispose() } }
}

function Get-PrismRegistrySnapshot {
    param([string]$Path)
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Path, $false)
    try {
        $names = @()
        if ($key) { $names = @($key.GetValueNames() | Sort-Object) }
        [pscustomobject]@{
            Path = $Path
            KeyExists = [bool]$key
            Values = @(foreach ($name in $names) { Get-PrismRegistryEntry -Path $Path -Name $name })
        }
    } finally { if ($key) { $key.Dispose() } }
}

function Test-PrismRegistryEntry {
    param($Left, $Right)
    if ([bool]$Left.Exists -ne [bool]$Right.Exists) { return $false }
    if (-not $Left.Exists) { return $true }
    ($Left.Kind -eq $Right.Kind) -and
        (($Left.Data | ConvertTo-Json -Compress) -ceq ($Right.Data | ConvertTo-Json -Compress))
}

function Get-PrismPersistedChecks {
    param([object[]]$Changes, [ValidateSet('Applied', 'Before')] [string]$ExpectedField = 'Applied')
    foreach ($change in $Changes) {
        $expected = $change.$ExpectedField
        $actual = Get-PrismRegistryEntry -Path $change.Path -Name $change.Name
        [pscustomobject]@{
            Path = $change.Path
            Name = $change.Name
            Matches = [bool](Test-PrismRegistryEntry $actual $expected)
            Expected = $expected
            Actual = $actual
        }
    }
}

function Set-PrismRegistryEntry {
    param([string]$Path, $Entry)
    # Existing Windows preference keys only: do not create unknown registry paths.
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Path, $true)
    if (-not $key) { throw "Expected Windows preference key is missing: HKCU\$Path" }
    try {
        if (-not $Entry.Exists) { $key.DeleteValue([string]$Entry.Name, $false); return }
        $kind = [Microsoft.Win32.RegistryValueKind]::$($Entry.Kind)
        $value = switch ([string]$Entry.Kind) {
            'Binary' { ,([Convert]::FromBase64String([string]$Entry.Data)) }
            'None' { ,([Convert]::FromBase64String([string]$Entry.Data)) }
            'DWord' { [int]::Parse([string]$Entry.Data, [Globalization.CultureInfo]::InvariantCulture) }
            'QWord' { [long]::Parse([string]$Entry.Data, [Globalization.CultureInfo]::InvariantCulture) }
            'MultiString' { ,([string[]]$Entry.Data) }
            'String' { [string]$Entry.Data }
            'ExpandString' { [string]$Entry.Data }
            default { throw "Unsupported backup registry type: $($Entry.Kind)" }
        }
        $key.SetValue([string]$Entry.Name, $value, $kind)
    } finally { $key.Dispose() }
}

function Send-PrismSettingsChanged {
    try {
    if (-not ('PridePrism.NativeThemeNotification' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace PridePrism {
    public static class NativeThemeNotification {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr window, uint message, UIntPtr wParam, string lParam,
            uint flags, uint timeout, out UIntPtr result);
    }
}
'@
    }
    $success = $true
    foreach ($area in @('ImmersiveColorSet', 'DWM')) {
        $result = [UIntPtr]::Zero
        $sent = [PridePrism.NativeThemeNotification]::SendMessageTimeout(
            [IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, $area, 0x0002, 100, [ref]$result)
        if ($sent -eq [IntPtr]::Zero) { $success = $false }
    }
    if (-not $success) { Write-Warning 'Desktop notification failed or timed out. Check the post-notification persistence results and verify appearance; no applications were restarted.' }
    return $success
    } catch {
        Write-Warning "Desktop notification could not run: $($_.Exception.Message). Check the persistence results; no applications were restarted."
        return $false
    }
}

if ($LibraryOnly) { return }
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ThemeJson)) { throw 'Supply -ThemeJson with a generated theme.json file.' }
$themePath = (Resolve-Path -LiteralPath $ThemeJson -ErrorAction Stop).ProviderPath
$theme = Get-Content -LiteralPath $themePath -Raw -Encoding UTF8 | ConvertFrom-Json
$null = ConvertTo-PrismAccent -Hex ([string]$theme.colors.accent)
Assert-PrismInteractiveSession

$settings = @(Get-PrismWindowsSettings)
$beforeEntries = foreach ($setting in $settings) {
    $existingKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($setting.Path, $false)
    if (-not $existingKey) { throw "Unsupported Windows configuration: HKCU\$($setting.Path) is missing." }
    $existingKey.Dispose()
    [pscustomobject]@{
        Path = $setting.Path
        Name = $setting.Name
        Before = Get-PrismRegistryEntry -Path $setting.Path -Name $setting.Name
    }
}
$changes = @(New-PrismWindowsChanges -Hex ([string]$theme.colors.accent) -BeforeEntries @($beforeEntries))
if (-not $PSCmdlet.ShouldProcess('Current-user dark mode and Windows 10 accent preferences', 'Back up, apply eight preference values, notify existing windows, and verify persisted values')) { return }

if ([string]::IsNullOrWhiteSpace($BackupRoot)) { $BackupRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PridePrism\Windows\Backups' }
$runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N')
$backupDirectory = Join-Path ([IO.Path]::GetFullPath($BackupRoot)) $runId
[void][IO.Directory]::CreateDirectory($backupDirectory)
$backupPath = Join-Path $backupDirectory 'snapshot.json'
$snapshotPaths = @(
    'Software\Microsoft\Windows\CurrentVersion\Themes',
    'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
    'Software\Microsoft\Windows\CurrentVersion\Explorer\Accent',
    'Software\Microsoft\Windows\DWM',
    'Control Panel\Desktop',
    'Control Panel\Cursors',
    'Control Panel\Cursors\Schemes'
)
$currentThemeEntry = Get-PrismRegistryEntry -Path $snapshotPaths[0] -Name 'CurrentTheme'
$themeFile = [pscustomobject]@{ OriginalPath = $null; Exists = $false; BackupFile = $null; Sha256 = $null }
if ($currentThemeEntry.Exists -and $currentThemeEntry.Kind -in @('String', 'ExpandString')) {
    $currentThemePath = [Environment]::ExpandEnvironmentVariables([string]$currentThemeEntry.Data)
    $themeFile.OriginalPath = $currentThemePath
    if ($currentThemePath.StartsWith('\\')) { throw 'Refusing to read a network theme path. No preference values were changed.' }
    if (Test-Path -LiteralPath $currentThemePath -PathType Leaf) {
        $themeCopy = Join-Path $backupDirectory 'current-theme.original'
        Copy-Item -LiteralPath $currentThemePath -Destination $themeCopy -ErrorAction Stop
        $themeFile.Exists = $true
        $themeFile.BackupFile = 'current-theme.original'
        $themeFile.Sha256 = (Get-FileHash -LiteralPath $themeCopy -Algorithm SHA256).Hash
    }
}
$snapshot = [ordered]@{
    SchemaVersion = 2
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    UserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    SessionId = (Get-Process -Id $PID).SessionId
    ThemeJsonSha256 = (Get-FileHash -LiteralPath $themePath -Algorithm SHA256).Hash
    ThemeFile = $themeFile
    Registry = @($snapshotPaths | ForEach-Object { Get-PrismRegistrySnapshot -Path $_ })
    Changes = @($changes)
}
$snapshot | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $backupPath -Encoding UTF8 -ErrorAction Stop
$null = Get-Content -LiteralPath $backupPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Refuse concurrent preference edits before the first write.
foreach ($change in $changes) {
    if (-not (Test-PrismRegistryEntry (Get-PrismRegistryEntry $change.Path $change.Name) $change.Before)) {
        throw "A preference changed during backup; no settings applied. Snapshot: $backupPath"
    }
}
$written = [Collections.Generic.List[object]]::new()
try {
    foreach ($change in $changes) {
        if (Test-PrismRegistryEntry $change.Before $change.Applied) { continue }
        Set-PrismRegistryEntry -Path $change.Path -Entry $change.Applied
        $written.Add($change)
        if (-not (Test-PrismRegistryEntry (Get-PrismRegistryEntry $change.Path $change.Name) $change.Applied)) { throw "Read-back mismatch: $($change.Name)" }
    }
} catch {
    $applyError = $_
    # Restore source Explorer values before derived DWM values here as well.
    foreach ($change in $written) {
        Set-PrismRegistryEntry -Path $change.Path -Entry $change.Before
    }
    [void](Send-PrismSettingsChanged)
    $rollbackMismatches = @(Get-PrismPersistedChecks -Changes @($written) -ExpectedField Before | Where-Object { -not $_.Matches })
    if ($rollbackMismatches.Count) {
        throw "Apply failed; rollback values differ after notification: $($rollbackMismatches.Name -join ', '). Original error: $applyError. Snapshot: $backupPath"
    }
    throw "Apply failed; written values matched their rollback snapshot immediately after notification: $applyError. Snapshot: $backupPath"
}
$notified = Send-PrismSettingsChanged
$persistedChecks = @(Get-PrismPersistedChecks -Changes $changes)
$mismatches = @($persistedChecks | Where-Object { -not $_.Matches })
if ($mismatches.Count) { Write-Warning 'Windows preference values differ after notification. Inspect PersistedMismatches; live colors are not confirmed and no retry is attempted.' }
[pscustomobject]@{
    BackupPath = $backupPath
    Accent = $theme.colors.accent
    ChangedValues = $written.Count
    DesktopNotified = $notified
    PersistedMatches = ($mismatches.Count -eq 0)
    PersistedMismatches = $mismatches
    WallpaperAndCursors = 'Preserved'
    Appearance = 'Immediate registry read-back only. Verify visual adoption and later persistence in the interactive session; app support varies.'
}
