[CmdletBinding()]
param(
    [string]$ArchivePath
)

$ErrorActionPreference = 'Stop'

$releaseUrl = 'https://github.com/ful1e5/Bibata_Cursor_Rainbow/releases/download/v1.1.2/Bibata-Rainbow-Modern-Windows.zip'
$expectedSha256 = 'B94C6B42C634883443FACD5D8F7B0A1F248D3401880E509CD1AFC88F9C909046'
$schemeName = 'Pride Prism - Bibata Rainbow Modern'
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
$userProfile = [Environment]::GetFolderPath('UserProfile')
$prideRoot = Join-Path $localAppData 'PridePrism'
$cursorRoot = Join-Path $prideRoot 'Cursors\Bibata-Rainbow-Modern'
$backupPath = Join-Path $prideRoot 'cursor-backup.json'

if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
    $downloads = Join-Path $userProfile 'Downloads'
    $ArchivePath = Join-Path $downloads 'Bibata-Rainbow-Modern-Windows-v1.1.2.zip'
}

$ArchivePath = [IO.Path]::GetFullPath($ArchivePath)
if (-not (Test-Path -LiteralPath $ArchivePath)) {
    $archiveParent = Split-Path -Parent $ArchivePath
    New-Item -ItemType Directory -Path $archiveParent -Force | Out-Null
    Invoke-WebRequest -Uri $releaseUrl -OutFile $ArchivePath -UseBasicParsing
}

$actualSha256 = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
if (-not $actualSha256.Equals($expectedSha256, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Cursor archive hash mismatch. Expected $expectedSha256 but found $actualSha256."
}

function Export-FirstAniFrame {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Destination
    )

    $bytes = [IO.File]::ReadAllBytes($Source)
    $chunkOffset = -1
    for ($index = 0; $index -le $bytes.Length - 8; $index++) {
        if ($bytes[$index] -eq 0x69 -and $bytes[$index + 1] -eq 0x63 -and
            $bytes[$index + 2] -eq 0x6F -and $bytes[$index + 3] -eq 0x6E) {
            $chunkOffset = $index
            break
        }
    }

    if ($chunkOffset -lt 0) {
        throw "No embedded cursor frame was found in: $Source"
    }

    $frameLength = [BitConverter]::ToUInt32($bytes, $chunkOffset + 4)
    $frameOffset = $chunkOffset + 8
    if ($frameLength -lt 6 -or $frameOffset + $frameLength -gt $bytes.Length) {
        throw "The embedded cursor frame is invalid in: $Source"
    }

    $frame = New-Object byte[] $frameLength
    [Array]::Copy($bytes, $frameOffset, $frame, 0, $frameLength)
    if ($frame[0] -ne 0 -or $frame[1] -ne 0 -or $frame[2] -ne 2 -or $frame[3] -ne 0) {
        throw "The first animation frame is not a Windows cursor in: $Source"
    }

    [IO.File]::WriteAllBytes($Destination, $frame)
}

function Get-RegistrySnapshot {
    param(
        [Parameter(Mandatory)] [Microsoft.Win32.RegistryKey]$Key,
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Name
    )

    $exists = $Key.GetValueNames() -contains $Name
    if (-not $exists) {
        return [pscustomobject]@{ Name = $Name; Exists = $false; Kind = $null; Value = $null }
    }

    return [pscustomobject]@{
        Name = $Name
        Exists = $true
        Kind = $Key.GetValueKind($Name).ToString()
        Value = $Key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
}

New-Item -ItemType Directory -Path $prideRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath $backupPath)) {
    $currentKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Control Panel\Cursors', $false)
    $schemesKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Control Panel\Cursors\Schemes')
    try {
        $valueNames = @('', 'Arrow', 'Help', 'AppStarting', 'Wait', 'Crosshair', 'IBeam', 'NWPen',
            'No', 'SizeNS', 'SizeWE', 'SizeNWSE', 'SizeNESW', 'SizeAll', 'UpArrow', 'Hand',
            'Pin', 'Person', 'Scheme Source', 'CursorBaseSize')
        $values = foreach ($valueName in $valueNames) {
            Get-RegistrySnapshot -Key $currentKey -Name $valueName
        }
        $backup = [ordered]@{
            Version = 1
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
            SchemeName = $schemeName
            Values = @($values)
            SchemeRegistration = Get-RegistrySnapshot -Key $schemesKey -Name $schemeName
        }
        $backup | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $backupPath -Encoding UTF8
    } finally {
        $currentKey.Dispose()
        $schemesKey.Dispose()
    }
}

$stageRoot = Join-Path ([IO.Path]::GetTempPath()) ("PridePrism-Cursor-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stageRoot | Out-Null
try {
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $stageRoot
    $sourceRoot = Join-Path $stageRoot 'Bibata-Rainbow-Modern-Windows'
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'Default.ani'))) {
        throw 'The verified archive does not contain the expected Bibata Rainbow cursor files.'
    }

    New-Item -ItemType Directory -Path $cursorRoot -Force | Out-Null
    $staticSources = [ordered]@{
        Arrow = 'Default.ani'
        Help = 'Help.ani'
        Crosshair = 'Cross.ani'
        IBeam = 'IBeam.ani'
        NWPen = 'Handwriting.ani'
        No = 'Unavailiable.ani'
        SizeNS = 'Vertical.ani'
        SizeWE = 'Horizontal.ani'
        SizeNWSE = 'Diagonal_1.ani'
        SizeNESW = 'Diagonal_2.ani'
        SizeAll = 'Move.ani'
        UpArrow = 'Alternate.ani'
        Hand = 'Link.ani'
        Pin = 'Default.ani'
        Person = 'Link.ani'
    }

    $installedPaths = @{}
    foreach ($entry in $staticSources.GetEnumerator()) {
        $destination = Join-Path $cursorRoot ($entry.Key + '.cur')
        Export-FirstAniFrame -Source (Join-Path $sourceRoot $entry.Value) -Destination $destination
        $installedPaths[$entry.Key] = $destination
    }

    foreach ($animated in @(
        [pscustomobject]@{ Role = 'AppStarting'; File = 'Work.ani' },
        [pscustomobject]@{ Role = 'Wait'; File = 'Busy.ani' }
    )) {
        $destination = Join-Path $cursorRoot ($animated.Role + '.ani')
        Copy-Item -LiteralPath (Join-Path $sourceRoot $animated.File) -Destination $destination -Force
        $installedPaths[$animated.Role] = $destination
    }

    $roleOrder = @('Arrow', 'Help', 'AppStarting', 'Wait', 'Crosshair', 'IBeam', 'NWPen', 'No',
        'SizeNS', 'SizeWE', 'SizeNWSE', 'SizeNESW', 'SizeAll', 'UpArrow', 'Hand', 'Pin', 'Person')

    $cursorKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Control Panel\Cursors', $true)
    $schemesKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Control Panel\Cursors\Schemes')
    try {
        foreach ($role in $roleOrder) {
            $cursorKey.SetValue($role, $installedPaths[$role], [Microsoft.Win32.RegistryValueKind]::String)
        }
        $cursorKey.SetValue('', $schemeName, [Microsoft.Win32.RegistryValueKind]::String)
        $cursorKey.SetValue('Scheme Source', 1, [Microsoft.Win32.RegistryValueKind]::DWord)
        $schemeValue = ($roleOrder | ForEach-Object { $installedPaths[$_] }) -join ','
        $schemesKey.SetValue($schemeName, $schemeValue, [Microsoft.Win32.RegistryValueKind]::String)
    } finally {
        $cursorKey.Dispose()
        $schemesKey.Dispose()
    }
} finally {
    if (Test-Path -LiteralPath $stageRoot) {
        $resolvedStage = [IO.Path]::GetFullPath($stageRoot)
        $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $validPrefix = $resolvedStage.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)
        $validName = (Split-Path -Leaf $resolvedStage).StartsWith('PridePrism-Cursor-', [StringComparison]::Ordinal)
        if ($validPrefix -and $validName) {
            Remove-Item -LiteralPath $resolvedStage -Recurse -Force
        }
    }
}

if (-not ('PridePrism.CursorRefresh' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace PridePrism {
    public static class CursorRefresh {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(uint action, uint parameter, IntPtr value, uint flags);
    }
}
'@
}

$spiSetCursors = 0x0057
$spifUpdateIniFile = 0x0001
$spifSendChange = 0x0002
$refreshSucceeded = [PridePrism.CursorRefresh]::SystemParametersInfo(
    $spiSetCursors, 0, [IntPtr]::Zero, ($spifUpdateIniFile -bor $spifSendChange))

if (-not $refreshSucceeded) {
    $directError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $nonce = [Guid]::NewGuid().ToString('N')
    $refreshScript = Join-Path $PSScriptRoot 'refresh.ps1'
    $refreshResult = Join-Path $prideRoot "cursor-refresh-$nonce.json"
    $refreshLatest = Join-Path $prideRoot 'cursor-refresh-result.json'
    $taskName = "PridePrism-CursorRefresh-$nonce"
    $taskRegistered = $false
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -ResultPath "{1}" -Nonce "{2}"' -f $refreshScript, $refreshResult, $nonce
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5)
        $principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
        $taskRegistered = $true
        Start-ScheduledTask -TaskName $taskName

        $deadline = (Get-Date).AddSeconds(20)
        $result = $null
        do {
            Start-Sleep -Milliseconds 250
            if (Test-Path -LiteralPath $refreshResult) {
                try {
                    $candidate = Get-Content -LiteralPath $refreshResult -Raw | ConvertFrom-Json
                    if ($candidate.Nonce -eq $nonce) { $result = $candidate }
                } catch {
                    $result = $null
                }
            }
        } while (-not $result -and (Get-Date) -lt $deadline)

        if (-not $result -or -not $result.Success) {
            $interactiveError = if ($result) { $result.ErrorCode } else { 'no result' }
            throw "Windows did not refresh the cursor scheme. Direct Win32 error: $directError; interactive refresh: $interactiveError."
        }
        Move-Item -LiteralPath $refreshResult -Destination $refreshLatest -Force
    } finally {
        if ($taskRegistered) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Applied cursor scheme: $schemeName"
Write-Host "Original scheme backup: $backupPath"
Write-Host "Installed cursor files: $cursorRoot"
