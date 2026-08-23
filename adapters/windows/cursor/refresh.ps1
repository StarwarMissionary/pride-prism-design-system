[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ResultPath,
    [Parameter(Mandatory)] [string]$Nonce
)

$ErrorActionPreference = 'Stop'
$ResultPath = [IO.Path]::GetFullPath($ResultPath)
$resultParent = Split-Path -Parent $ResultPath
New-Item -ItemType Directory -Path $resultParent -Force | Out-Null

if (-not ('PridePrism.CursorLiveRefresh' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace PridePrism {
    public static class CursorLiveRefresh {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(uint action, uint parameter, IntPtr value, uint flags);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr LoadCursorFromFile(string fileName);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr LoadCursor(IntPtr instance, IntPtr cursorName);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr CopyIcon(IntPtr icon);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetSystemCursor(IntPtr cursor, uint cursorId);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool DestroyCursor(IntPtr cursor);
    }
}
'@
}

$spiSetCursors = 0x0057
$spifUpdateIniFile = 0x0001
$spifSendChange = 0x0002
$success = [PridePrism.CursorLiveRefresh]::SystemParametersInfo(
    $spiSetCursors, 0, [IntPtr]::Zero, ($spifUpdateIniFile -bor $spifSendChange))
$directError = if ($success) { 0 } else { [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
$method = 'SystemParametersInfo'
$roleResults = @()

if (-not $success) {
    $method = 'SetSystemCursor'
    $cursorIds = [ordered]@{
        Arrow = 32512
        IBeam = 32513
        Wait = 32514
        Crosshair = 32515
        UpArrow = 32516
        NWPen = 32631
        SizeNWSE = 32642
        SizeNESW = 32643
        SizeWE = 32644
        SizeNS = 32645
        SizeAll = 32646
        No = 32648
        Hand = 32649
        AppStarting = 32650
        Help = 32651
        Pin = 32671
        Person = 32672
    }

    $cursorKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Control Panel\Cursors', $false)
    try {
        foreach ($entry in $cursorIds.GetEnumerator()) {
            $role = [string]$entry.Key
            $cursorId = [uint32]$entry.Value
            $rawPath = [string]$cursorKey.GetValue(
                $role, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $cursorPath = [Environment]::ExpandEnvironmentVariables($rawPath)
            $cursor = [IntPtr]::Zero
            $loadError = 0

            if ([string]::IsNullOrWhiteSpace($cursorPath)) {
                $sharedCursor = [PridePrism.CursorLiveRefresh]::LoadCursor([IntPtr]::Zero, [IntPtr]$cursorId)
                if ($sharedCursor -ne [IntPtr]::Zero) {
                    $cursor = [PridePrism.CursorLiveRefresh]::CopyIcon($sharedCursor)
                }
            } else {
                $cursor = [PridePrism.CursorLiveRefresh]::LoadCursorFromFile($cursorPath)
            }

            if ($cursor -eq [IntPtr]::Zero) {
                $loadError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
                $roleResults += [pscustomobject]@{
                    Role = $role
                    Success = $false
                    Stage = 'Load'
                    ErrorCode = $loadError
                }
                continue
            }

            $roleSucceeded = [PridePrism.CursorLiveRefresh]::SetSystemCursor($cursor, $cursorId)
            $roleError = if ($roleSucceeded) { 0 } else { [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
            if (-not $roleSucceeded) {
                [void][PridePrism.CursorLiveRefresh]::DestroyCursor($cursor)
            }
            $roleResults += [pscustomobject]@{
                Role = $role
                Success = $roleSucceeded
                Stage = 'Set'
                ErrorCode = $roleError
            }
        }
    } finally {
        if ($cursorKey) { $cursorKey.Dispose() }
    }

    $success = $roleResults.Count -eq $cursorIds.Count -and
        @($roleResults | Where-Object { -not $_.Success }).Count -eq 0
}

$errorCode = if ($success) {
    0
} else {
    $roleError = $roleResults | Where-Object { -not $_.Success } | Select-Object -First 1 -ExpandProperty ErrorCode
    if ($null -ne $roleError) { $roleError } else { $directError }
}

[ordered]@{
    Nonce = $Nonce
    Success = $success
    ErrorCode = $errorCode
    DirectErrorCode = $directError
    Method = $method
    Roles = @($roleResults)
    SessionId = (Get-Process -Id $PID).SessionId
    CompletedUtc = [DateTime]::UtcNow.ToString('o')
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ResultPath -Encoding UTF8

if (-not $success) {
    exit 1
}
