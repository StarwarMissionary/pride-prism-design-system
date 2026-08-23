[CmdletBinding()]
param(
    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    $BackupPath = Join-Path $localAppData 'PridePrism\cursor-backup.json'
}

$BackupPath = [IO.Path]::GetFullPath($BackupPath)
if (-not (Test-Path -LiteralPath $BackupPath)) {
    throw "Cursor backup was not found: $BackupPath"
}

$backup = Get-Content -LiteralPath $BackupPath -Raw | ConvertFrom-Json
$cursorKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Control Panel\Cursors', $true)
$schemesKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Control Panel\Cursors\Schemes')
try {
    foreach ($entry in $backup.Values) {
        $name = [string]$entry.Name
        if (-not $entry.Exists) {
            $cursorKey.DeleteValue($name, $false)
            continue
        }

        $kind = [Microsoft.Win32.RegistryValueKind]::$($entry.Kind)
        $value = $entry.Value
        if ($kind -eq [Microsoft.Win32.RegistryValueKind]::DWord) {
            $value = [int]$value
        }
        $cursorKey.SetValue($name, $value, $kind)
    }

    $schemeBackup = $backup.SchemeRegistration
    if ($schemeBackup.Exists) {
        $schemeKind = [Microsoft.Win32.RegistryValueKind]::$($schemeBackup.Kind)
        $schemesKey.SetValue([string]$schemeBackup.Name, $schemeBackup.Value, $schemeKind)
    } else {
        $schemesKey.DeleteValue([string]$backup.SchemeName, $false)
    }
} finally {
    $cursorKey.Dispose()
    $schemesKey.Dispose()
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
if (-not [PridePrism.CursorRefresh]::SystemParametersInfo(
        $spiSetCursors, 0, [IntPtr]::Zero, ($spifUpdateIniFile -bor $spifSendChange))) {
    $directError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $prideRoot = Join-Path $localAppData 'PridePrism'
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
            throw "Windows did not refresh the restored cursor scheme. Direct Win32 error: $directError; interactive refresh: $interactiveError."
        }
        Move-Item -LiteralPath $refreshResult -Destination $refreshLatest -Force
    } finally {
        if ($taskRegistered) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Restored the cursor scheme saved in: $BackupPath"
