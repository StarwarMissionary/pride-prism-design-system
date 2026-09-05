[CmdletBinding()]
param([Parameter(Mandatory = $true)] [string]$ThemeJson)

# Read-only: no EditorPrefs, registry, projects, resource files, or app launches.
$ErrorActionPreference = 'Stop'
$theme = Get-Content -LiteralPath $ThemeJson -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($name in @('accent', 'focus')) {
    if ([string]$theme.colors.$name -notmatch '^#[0-9a-fA-F]{6}$') { throw "colors.$name must be #RRGGBB." }
}
@(
    [pscustomobject]@{ Preference = 'General > Editor Theme'; Value = 'Dark'; Application = 'Manual native Preferences control' },
    [pscustomobject]@{ Preference = 'Colors > Scene > Selected Outline'; Value = $theme.colors.accent; Application = 'Optional; preserve existing alpha' },
    [pscustomobject]@{ Preference = 'Colors > Scene > Selected Children Outline'; Value = $theme.colors.focus; Application = 'Optional; preserve existing alpha' },
    [pscustomobject]@{ Preference = 'Colors > General > Playmode Tint'; Value = 'Preserve existing'; Application = 'Keep this separate state indicator; not a global recoloring control' }
)
