[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)] [string]$BackupPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$restoreCmdlet = $PSCmdlet
. (Join-Path $PSScriptRoot 'install.ps1') -LibraryOnly
Assert-PrismInteractiveSession
$resolvedBackup = (Resolve-Path -LiteralPath $BackupPath -ErrorAction Stop).ProviderPath
$backup = Get-Content -LiteralPath $resolvedBackup -Raw -Encoding UTF8 | ConvertFrom-Json
if ($backup.SchemaVersion -notin @(1, 2) -or $backup.UserSid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) {
    throw 'Backup schema or user does not match. Legacy previous-theme.txt backups are not applied automatically.'
}
$orderedSettings = @(Get-PrismWindowsSettings -SchemaVersion ([int]$backup.SchemaVersion))
$allowed = @($orderedSettings | ForEach-Object { $_.Path + '|' + $_.Name })
$seen = @{}
$toRestore = @()
foreach ($change in @($backup.Changes)) {
    $id = [string]$change.Path + '|' + [string]$change.Name
    if ($allowed -notcontains $id -or $seen.ContainsKey($id) -or $change.Before.Name -cne $change.Name -or $change.Applied.Name -cne $change.Name) { throw 'Backup contains unexpected or duplicate settings.' }
    $seen[$id] = $true
    if ($backup.SchemaVersion -eq 2) {
        $requiredBefore = $change.Name -in @('AccentPalette', 'AccentColorMenu', 'StartColorMenu', 'ColorizationColor')
        Assert-PrismWindowsEntryFormat -Name $change.Name -Entry $change.Before -RequireExisting:$requiredBefore
        Assert-PrismWindowsEntryFormat -Name $change.Name -Entry $change.Applied -RequireExisting
    }
    # Do not roll back a later user edit to a value this run never changed.
    if (Test-PrismRegistryEntry $change.Before $change.Applied) { continue }
    $current = Get-PrismRegistryEntry -Path $change.Path -Name $change.Name
    if (Test-PrismRegistryEntry $current $change.Before) { continue }
    if (-not $Force -and -not (Test-PrismRegistryEntry $current $change.Applied)) {
        throw "HKCU\$($change.Path)\$($change.Name) changed since installation. Review it; use -Force only to explicitly discard that later edit. No values restored."
    }
    $toRestore += $change
}
if ($seen.Count -ne $allowed.Count) { throw 'Backup is incomplete; no values restored.' }
if (-not $restoreCmdlet.ShouldProcess("Only the $($allowed.Count) Windows preference values captured by this installation", 'Restore exact types, values, and absent values; notify existing windows and verify persistence')) { return }
# Do not trust backup ordering: Explorer source values precede derived DWM.
$orderedRestore = foreach ($setting in $orderedSettings) {
    $toRestore | Where-Object { $_.Path -eq $setting.Path -and $_.Name -eq $setting.Name }
}
foreach ($change in $orderedRestore) {
    Set-PrismRegistryEntry -Path $change.Path -Entry $change.Before
    if (-not (Test-PrismRegistryEntry (Get-PrismRegistryEntry $change.Path $change.Name) $change.Before)) {
        throw "Restore verification failed at $($change.Name). Backup retained: $resolvedBackup"
    }
}
$notified = Send-PrismSettingsChanged
$persistedChecks = @(Get-PrismPersistedChecks -Changes @($toRestore) -ExpectedField Before)
$mismatches = @($persistedChecks | Where-Object { -not $_.Matches })
if ($mismatches.Count) { Write-Warning 'Restored preferences differ after notification. Inspect PersistedMismatches; no retry is attempted and the backup is retained.' }
[pscustomobject]@{
    RestoredBackup = $resolvedBackup
    RestoredValues = $toRestore.Count
    DesktopNotified = $notified
    PersistedMatches = ($mismatches.Count -eq 0)
    PersistedMismatches = $mismatches
    WallpaperAndCursors = 'Untouched'
    RestartedApplications = $false
    Appearance = 'Immediate registry read-back only; verify visual adoption and later persistence.'
}
