$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$game = 'C:\Program Files (x86)\Steam\steamapps\common\GarrysMod'
$runtime = Join-Path $repo '.runtime'
$isolated = Join-Path $runtime 'garrysmod'
New-Item -ItemType Directory -Force -Path $isolated, "$isolated\cfg", "$isolated\lua\autorun\client", "$isolated\lua\civic", "$isolated\data" | Out-Null
# Only read-only game content is shared. Databases, saves, config and output
# remain under .runtime; the installed gamemodes/addons are never edited.
foreach ($name in @('bin','platform','sourceengine')) {
    $link = Join-Path $runtime $name
    if (!(Test-Path -LiteralPath $link)) { New-Item -ItemType Junction -Path $link -Target (Join-Path $game $name) | Out-Null }
}
foreach ($name in @('gamemodes','maps','materials','models','resource','particles','scenes','html')) {
    $target = Join-Path "$game\garrysmod" $name
    $link = Join-Path $isolated $name
    if ((Test-Path -LiteralPath $target) -and !(Test-Path -LiteralPath $link)) {
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    }
}
foreach ($entry in Get-ChildItem "$game\garrysmod\lua") {
    $link = Join-Path "$isolated\lua" $entry.Name
    if (!(Test-Path -LiteralPath $link)) {
        if ($entry.PSIsContainer) { New-Item -ItemType Junction -Path $link -Target $entry.FullName | Out-Null }
        else { Copy-Item -LiteralPath $entry.FullName -Destination $link }
    }
}
foreach ($entry in Get-ChildItem "$game\garrysmod" -Filter *.vpk) {
    $link = Join-Path $isolated $entry.Name
    if (!(Test-Path -LiteralPath $link)) { New-Item -ItemType HardLink -Path $link -Target $entry.FullName | Out-Null }
}
$g = $game.Replace('\','/')
@"
"GameInfo"
{
 game "Garry's Mod"
 title "Hutten UI smoke"
 type multiplayer_only
 FileSystem
 {
  SteamAppId 4000
  SearchPaths
  {
   game+mod "|gameinfo_path|."
   game+mod "$g/garrysmod/garrysmod.vpk"
   game "$g/sourceengine/hl2_textures.vpk"
   game "$g/sourceengine/hl2_sound_vo_english.vpk"
   game "$g/sourceengine/hl2_sound_misc.vpk"
   game "$g/sourceengine/hl2_misc.vpk"
   platform "$g/platform/platform_misc.vpk"
   mod+mod_write+default_write_path "|gameinfo_path|."
   game+game_write "|gameinfo_path|."
   game "$g/garrysmod"
   gamebin "$g/garrysmod/bin"
   game "$g/sourceengine"
   platform "$g/platform"
  }
 }
}
"@ | Set-Content "$isolated\gameinfo.txt" -Encoding ascii
Copy-Item "$repo\helix\gamemode\game\cl_civic_theme.lua" "$isolated\lua\civic\theme.lua" -Force
Copy-Item "$repo\helix\gamemode\game\ui\civic.dashboard.lua" "$isolated\lua\civic\dashboard.lua" -Force
Copy-Item "$repo\helix\gamemode\game\ui\civic.workspace.lua" "$isolated\lua\civic\workspace.lua" -Force
Copy-Item "$repo\helix\gamemode\core\libs\thirdparty\sh_utf8.lua" "$isolated\lua\civic\utf8.lua" -Force
New-Item -ItemType Directory -Force "$isolated\lua\core\libs\thirdparty\data" | Out-Null
Copy-Item "$repo\helix\gamemode\core\libs\thirdparty\data\sh_utf8_casemap.lua" "$isolated\lua\core\libs\thirdparty\data\sh_utf8_casemap.lua" -Force
Copy-Item "$PSScriptRoot\engine-smoke.lua" "$isolated\lua\autorun\client\civic_smoke.lua" -Force
Write-Output $isolated
