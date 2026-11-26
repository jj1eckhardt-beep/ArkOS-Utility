# ==============================================================================
# PROJECT: dArkOS-Utility
# PURPOSE: High-speed ArkOS ROM migration utility.
# AUTHOR:  [jj1eckhardt]
# ==============================================================================


# ==============================================================================
# SECTION 0: INITIALIZATION & IDENTITY
# ==============================================================================
# 1. Manual Identity (Change these for new releases)
$global:ScriptTitle = "dArkOS UTILITY"  # What people see in the UI
$global:Cvers = "v1.3.0"               # The version number
$global:BuildDate = "2026.11.26"       # The build timestamp
$global:RepoName = "ArkOS-Utility"     # For GitHub link consistency
$global:RepoOwner = "jj1eckhardt-beep"

# 2. Automated File Identity
# This gets the name of the .ps1 file itself for logging purposes -.ps1
$global:ScriptFname1 = (Get-Item $PSCommandPath).Basename 

# 3. Initialize Process Globals
$global:MasterPath = ""
$global:ArchivePath = ""
$global:AbortArchive = $false


# ==============================================================================
#  ASCII Art
# ==============================================================================

$HeaderArt = @"
     ___________________________________
    /...................................\
    |:                                 :|   Thank you to the ArkOS Wiki Page.
    |:                                 :|   Thank you to the Handheld community.
    |:          $ScriptFname1          :|   Thank you especially to the Developers.
    |:             $Cvers              :|
    |:           $BuildDate            :|
    |:                                 :|   I Thank God for this day
    |:                                 :|   for the sun in the sky
    |:                                 :|   for my mom and my dad
    |:                                 :|   and my piece of apple pie
    |:                                 :|
    |:           jj1eckhardt           :|       ~Veggie Tales~
    |:.................................:|
    |              __ . __              |
    |      __      . ___ .              |
    |     |  |     __ . __    ( X )     |
    |  ___|  |___                       |
    | |          |        ( Y )   ( A ) |
    | |___    ___|                      |
    |     |  |       fun      ( B )     |
    |     |__|      ( F )               |
    |            ( S ) ( S )            |
    |     ___   select  start   ___     |
    |    /   \                 /   \    |
    |   {     }               {     }   |
    |    \___/                 \___/    |
    \___________________________________/
"@

# Force Windows line endings
$HeaderArt = $HeaderArt -replace '(?<!\r)\n', "`r`n" # force CRLF no matter how the file is saved

# To display it in the console during launch:
Write-Host $HeaderArt -ForegroundColor Cyan


# ==============================================================================
# SECTION 1: SYSTEM INITIALIZATION & GLOBAL CORE
# ==============================================================================

# --- 1.1: REQUIRED ASSEMBLIES & UI ENGINE ---
# These MUST be at the top. They load the "dictionary" PowerShell uses for Windows.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# This line ensures the buttons look like modern Windows buttons, not 1995 style.
[System.Windows.Forms.Application]::EnableVisualStyles()

# (Optional) Forces PowerShell to use modern security for the GitHub link
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- 1.2: GLOBAL CONFIGURATIONS ---
# These variables control the behavior of Sync and Scan throughout the script
# ============================================================
# EXTENSION CATEGORIES
# ============================================================

# Actual playable game files (what should be counted as "ROMs")
$global:GameExtensions = @(
    # Archives that usually contain games
    ".zip", ".7z", ".rar",

    # Disc / CD images
    ".iso", ".chd", ".bin", ".cue", ".img", ".cso", ".gdi", ".cdi",
    ".mds", ".mdf", ".nrg", ".ccd", ".toc", ".m3u", ".m3u8",

    # Nintendo
    ".nes", ".unf", ".unif", ".nez", ".fds",
    ".sfc", ".smc", ".fig", ".swc", ".snes",
    ".n64", ".z64", ".v64", ".u64", ".ndd",
    ".gcm", ".gcz", ".rvz", ".tgc", ".wia",
    ".wbfs", ".wdf", ".wad",
    ".wud", ".wux", ".wua", ".rpx",
    ".xci", ".nsp", ".nsz", ".nca",
    ".gb", ".gbc", ".sgb", ".gba", ".agb", ".srl",
    ".nds", ".dsi", ".ids",
    ".3ds", ".cia", ".cci", ".cxi", ".3dsx",
    ".min", ".vb", ".vboy",

    # Sega
    ".sg", ".sc", ".sms", ".gg",
    ".md", ".gen", ".smd", ".32x",

    # Sony
    ".pbp", ".vpk", ".pkg",

    # Other systems
    ".pce", ".sgx",
    ".ngp", ".ngc", ".ngpc",
    ".ws", ".wsc",
    ".lnx", ".lyx",
    ".a26", ".a52", ".a78",
    ".j64", ".jag",
    ".col", ".cv", ".int", ".vec",
    ".p8",                # Pico-8 source
    ".mgw", ".vmu", ".dosz",
    ".rom"
)

# Box art / images (and Pico-8 special case)
$global:BoxArtExtensions = @(
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"
)

# Gamelist / metadata files
$global:GamelistExtensions = @(
    ".xml",               # gamelist.xml, etc.
    ".json",
    ".txt", ".csv"
)

# Support files (saves, configs, patches, videos, manuals, etc.)
$global:SupportExtensions = @(
    # Saves
    ".srm", ".sav", ".dsv", ".eep", ".mpk", ".mcr", ".ps2",

    # Patches
    ".ips", ".bps", ".ups",

    # Configs / data
    ".ini", ".dat", ".cfg", ".sig",

    # Videos / audio (trailers, music, etc.)
    ".mp4", ".avi", ".mov", ".mpg", ".mpeg", ".wmv", ".mkv", ".webm",
    ".mp3", ".ogg", ".wav", ".flac", ".aac",

    # Other support
    ".pdf", ".rtf", ".sh", ".bat", ".cmd", ".jar",
    ".pup", ".lo", ".ldb", ".s12"
)

# Master list (for any code that still needs "everything")
$global:RomExtensions = $global:GameExtensions + 
                        $global:BoxArtExtensions + 
                        $global:GamelistExtensions + 
                        $global:SupportExtensions

$global:SourcePath = ""
$global:DestPath = ""
$global:AbortSync = $false
$global:TransferActive = $false
$global:CurrentBytes = 0
$global:CurrentFile = "Initializing..."
$script:ReportWidth = 104
# ============================================================
# Report Generation Toggles
# ============================================================
$script:GenerateAuditTxt = $true    # Human-readable .txt report
$script:GenerateAuditCsv = $false    # Clean .csv for Excel
$script:GenerateSdTxt = $false
$script:GenerateSdCsv = $true

# --- 1.3: MASTER SYSTEM DATABASE (Rows 1-140) ---
# The source of truth for folder names and aliases across all OS variants
$global:SystemDatabase = @(

    [PSCustomObject]@{ID = 1     ; Name = "3DO"                     ; Folder = "3do"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "1" },      
    [PSCustomObject]@{ID = 2     ; Name = "Entex Adventure Vision"  ; Folder = "advision"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "2" },      
    [PSCustomObject]@{ID = 3     ; Name = "American Laser Games"    ; Folder = "alg"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "3" },      
    [PSCustomObject]@{ID = 4     ; Name = "Amiga"                   ; Folder = "amiga"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "4" },      
    [PSCustomObject]@{ID = 5     ; Name = "Amiga CD32"              ; Folder = "amigacd32"        ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "5" },      
    [PSCustomObject]@{ID = 6     ; Name = "Amstrad CPC"             ; Folder = "amstradcpc"       ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "6" },      
    [PSCustomObject]@{ID = 7     ; Name = "Apple II"                ; Folder = "apple2"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "7" },      
    [PSCustomObject]@{ID = 8     ; Name = "Arcade"                  ; Folder = "arcade"           ; Alias = "mame"        ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "8" },      
    [PSCustomObject]@{ID = 9     ; Name = "Arduboy"                 ; Folder = "arduboy"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "9" },      
    [PSCustomObject]@{ID = 10    ; Name = "Astrocade"               ; Folder = "astrocde"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "10" },     
    [PSCustomObject]@{ID = 11    ; Name = "Atari 2600"              ; Folder = "atari2600"        ; Alias = "atari"       ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "11" },     
    [PSCustomObject]@{ID = 12    ; Name = "Atari 5200"              ; Folder = "atari5200"        ; Alias = "a5200"       ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "12" },     
    [PSCustomObject]@{ID = 13    ; Name = "Atari 7800"              ; Folder = "atari7800"        ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "13" },     
    [PSCustomObject]@{ID = 14    ; Name = "Atari 800"               ; Folder = "atari800"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "14" },     
    [PSCustomObject]@{ID = 15    ; Name = "Atari Jaguar"            ; Folder = "atarijaguar"      ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "15" },     
    [PSCustomObject]@{ID = 16    ; Name = "Atari Lynx"              ; Folder = "atarilynx"        ; Alias = "lynx"        ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "16" },     
    [PSCustomObject]@{ID = 17    ; Name = "Atari ST"                ; Folder = "atarist"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "17" },     
    [PSCustomObject]@{ID = 18    ; Name = "Atari XEGS"              ; Folder = "atarixegs"        ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "18" },     
    [PSCustomObject]@{ID = 19    ; Name = "Sammy Atomiswave"        ; Folder = "atomiswave"       ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "19" },     
    [PSCustomObject]@{ID = 20    ; Name = "Backup Storage"          ; Folder = "backup"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "20" },     
    [PSCustomObject]@{ID = 21    ; Name = "BBC Micro"               ; Folder = "bbcmicro"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "21" },     
    [PSCustomObject]@{ID = 22    ; Name = "Background Music"        ; Folder = "bgmusic"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "22" },     
    [PSCustomObject]@{ID = 23    ; Name = "System BIOS"             ; Folder = "bios"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "23" },     
    [PSCustomObject]@{ID = 24    ; Name = "Commodore 128"           ; Folder = "c128"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "24" },     
    [PSCustomObject]@{ID = 25    ; Name = "Commodore 16"            ; Folder = "c16"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "25" },     
    [PSCustomObject]@{ID = 26    ; Name = "Commodore 64"            ; Folder = "c64"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "26" },     
    [PSCustomObject]@{ID = 27    ; Name = "Cave Story"              ; Folder = "cavestory"        ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "27" },     
    [PSCustomObject]@{ID = 27.1  ; Name = "Philips CD-i"            ; Folder = "cdimono1"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $false   ; dArkOS = $true    ; RE_ID = "27.1" },   
    [PSCustomObject]@{ID = 28    ; Name = "Fairchild Channel F"     ; Folder = "channelf"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "28" },     
    [PSCustomObject]@{ID = 29    ; Name = "Tandy CoCo 3"            ; Folder = "coco3"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "29" },     
    [PSCustomObject]@{ID = 30    ; Name = "ColecoVision"            ; Folder = "coleco"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "30" },     
    [PSCustomObject]@{ID = 31    ; Name = "CPS 1"                   ; Folder = "cps1"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "31" },     
    [PSCustomObject]@{ID = 32    ; Name = "CPS 2"                   ; Folder = "cps2"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "32" },     
    [PSCustomObject]@{ID = 33    ; Name = "CPS 3"                   ; Folder = "cps3"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "33" },     
    [PSCustomObject]@{ID = 34    ; Name = "Daphne"                  ; Folder = "daphne"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "34" },     
    [PSCustomObject]@{ID = 35    ; Name = "Doom"                    ; Folder = "doom"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "35" },     
    [PSCustomObject]@{ID = 36    ; Name = "PC (MS-DOS)"             ; Folder = "dos"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "36" },     
    [PSCustomObject]@{ID = 37    ; Name = "Dragon 32/64"            ; Folder = "dragon32"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "37" },     
    [PSCustomObject]@{ID = 38    ; Name = "Dreamcast"               ; Folder = "dreamcast"        ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "38" },     
    [PSCustomObject]@{ID = 39    ; Name = "EasyRPG"                 ; Folder = "easyrpg"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "39" },     
    [PSCustomObject]@{ID = 40    ; Name = "Enterprise 64/128"       ; Folder = "enterprise"       ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "40" },     
    [PSCustomObject]@{ID = 41    ; Name = "Famicom"                 ; Folder = "famicom"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "41" },     
    [PSCustomObject]@{ID = 41.2  ; Name = "Final Burn Neo"          ; Folder = "fbneo"            ; Alias = "---"         ; G350_Src = "fbneo"            ; ArkOS = $false   ; dArkOS = $false   ; RE_ID = "41.2" },   
    [PSCustomObject]@{ID = 42    ; Name = "Famicom Disk System"     ; Folder = "fds"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "42" },     
    [PSCustomObject]@{ID = 43    ; Name = "Game and Watch"          ; Folder = "gameandwatch"     ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "43" },     
    [PSCustomObject]@{ID = 44    ; Name = "Game Gear (Sega)"        ; Folder = "gamegear"         ; Alias = "gg"          ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "44" },     
    [PSCustomObject]@{ID = 44.1  ; Name = "Game Tank"               ; Folder = "gametank"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $false   ; dArkOS = $true    ; RE_ID = "44.1" },   
    [PSCustomObject]@{ID = 45    ; Name = "Nintendo Game Boy"       ; Folder = "gb"               ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "45" },     
    [PSCustomObject]@{ID = 46    ; Name = "Game Boy Advance"        ; Folder = "gba"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "46" },     
    [PSCustomObject]@{ID = 47    ; Name = "Game Boy Color"          ; Folder = "gbc"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "47" },     
    [PSCustomObject]@{ID = 47.1  ; Name = "Game Cube (RK3566)"      ; Folder = "gc"               ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "47.1" },     
    [PSCustomObject]@{ID = 48    ; Name = "Genesis/Megadrive"       ; Folder = "genesis"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "48" },     
    [PSCustomObject]@{ID = 49    ; Name = "Amstrad GX4000"          ; Folder = "gx4000"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "49" },     
    [PSCustomObject]@{ID = 50    ; Name = "Intellivision"           ; Folder = "intellivision"    ; Alias = "intv"        ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "50" },     
    [PSCustomObject]@{ID = 51    ; Name = "Java (FreeJ2ME)"         ; Folder = "j2me"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "51" },       
    [PSCustomObject]@{ID = 52    ; Name = "Launch Images"           ; Folder = "launchimages"     ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "52" },     
    [PSCustomObject]@{ID = 53    ; Name = "Love2d"                  ; Folder = "love2d"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "53" },     
    [PSCustomObject]@{ID = 54    ; Name = "LowRes NX"               ; Folder = "lowresnx"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "54" },     
    [PSCustomObject]@{ID = 55    ; Name = "Mame/Mame 2010"          ; Folder = "mame"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "55" },     
    [PSCustomObject]@{ID = 56    ; Name = "Mame 2003"               ; Folder = "mame2003"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "56" },     
    [PSCustomObject]@{ID = 57    ; Name = "Master System"           ; Folder = "mastersystem"     ; Alias = "sms"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "57" },     
    [PSCustomObject]@{ID = 58    ; Name = "Sega Mega Drive"         ; Folder = "megadrive"        ; Alias = "genesis"     ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "58" },     
    [PSCustomObject]@{ID = 58.2  ; Name = "Mega Drive Japan"        ; Folder = "megadrive-japan"  ; Alias = "---"         ; G350_Src = "megadrive-japan"  ; ArkOS = $false   ; dArkOS = $false   ; RE_ID = "58.2" },   
    [PSCustomObject]@{ID = 59    ; Name = "Mega Duck"               ; Folder = "megaduck"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "59" },     
    [PSCustomObject]@{ID = 60    ; Name = "Movie Player"            ; Folder = "movies"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "60" },     
    [PSCustomObject]@{ID = 61    ; Name = "Megadrive MSU"           ; Folder = "msumd"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "61" },     
    [PSCustomObject]@{ID = 62    ; Name = "MSX"                     ; Folder = "msx"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "62" },     
    [PSCustomObject]@{ID = 63    ; Name = "MSX2"                    ; Folder = "msx2"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "63" },     
    [PSCustomObject]@{ID = 63.1  ; Name = "Music Path"              ; Folder = "music"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $false   ; dArkOS = $true    ; RE_ID = "63.1" },   
    [PSCustomObject]@{ID = 64    ; Name = "Microvision"             ; Folder = "mv"               ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "64" },     
    [PSCustomObject]@{ID = 65    ; Name = "Nintendo 64"             ; Folder = "n64"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "65" },     
    [PSCustomObject]@{ID = 66    ; Name = "Nintendo 64DD"           ; Folder = "n64dd"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "66" },     
    [PSCustomObject]@{ID = 67    ; Name = "Naomi"                   ; Folder = "naomi"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "67" },     
    [PSCustomObject]@{ID = 68    ; Name = "Nintendo DS"             ; Folder = "nds"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "68" },     
    [PSCustomObject]@{ID = 69    ; Name = "Neo Geo"                 ; Folder = "neogeo"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "69" },     
    [PSCustomObject]@{ID = 70    ; Name = "Neo Geo CD"              ; Folder = "neogeocd"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "70" },     
    [PSCustomObject]@{ID = 71    ; Name = "Nintendo NES"            ; Folder = "nes"              ; Alias = "fc"          ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "71" },     
    [PSCustomObject]@{ID = 72    ; Name = "Neo Geo Pocket"          ; Folder = "ngp"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "72" },     
    [PSCustomObject]@{ID = 73    ; Name = "Neo Geo Pocket Color"    ; Folder = "ngpc"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "73" },     
    [PSCustomObject]@{ID = 74    ; Name = "Magnavox Odyssey 2"      ; Folder = "odyssey2"         ; Alias = "o2"          ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "74" },     
    [PSCustomObject]@{ID = 75    ; Name = "Visual Novel Engine"     ; Folder = "onscripter"       ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "75" },     
    [PSCustomObject]@{ID = 76    ; Name = "OpenBOR"                 ; Folder = "openbor"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "76" },     
    [PSCustomObject]@{ID = 77    ; Name = "Palm OS"                 ; Folder = "palm"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "77" },     
    [PSCustomObject]@{ID = 78    ; Name = "PC98"                    ; Folder = "pc98"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "78" },     
    [PSCustomObject]@{ID = 79    ; Name = "PC Engine"               ; Folder = "pcengine"         ; Alias = "pce"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "79" },     
    [PSCustomObject]@{ID = 80    ; Name = "PC Engine CD"            ; Folder = "pcenginecd"       ; Alias = "pcecd"       ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "80" },     
    [PSCustomObject]@{ID = 81    ; Name = "PC-FX"                   ; Folder = "pcfx"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "81" },     
    [PSCustomObject]@{ID = 82    ; Name = "Sega Pico"               ; Folder = "pico"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "82" },     
    [PSCustomObject]@{ID = 83    ; Name = "PICO-8"                  ; Folder = "pico-8"           ; Alias = "pico8"       ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "83" },     
    [PSCustomObject]@{ID = 84    ; Name = "Aquaplus P/ECE"          ; Folder = "piece"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "84" },     
    [PSCustomObject]@{ID = 85    ; Name = "Pokemon Mini"            ; Folder = "pokemonmini"      ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "85" },     
    [PSCustomObject]@{ID = 86    ; Name = "Ports"                   ; Folder = "ports"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "86" },     
    [PSCustomObject]@{ID = 87    ; Name = "PS Portable (PSP)"       ; Folder = "psp"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "87" },     
    [PSCustomObject]@{ID = 87.2  ; Name = "PSP Configs/Saves"       ; Folder = "psp/ppsspp"       ; Alias = "---"         ; G350_Src = "ppsspp"           ; ArkOS = $false   ; dArkOS = $false   ; RE_ID = "87.2" },   
    [PSCustomObject]@{ID = 88    ; Name = "PSP Minis"               ; Folder = "pspminis"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "88" },     
    [PSCustomObject]@{ID = 89    ; Name = "Playstation 1"           ; Folder = "psx"              ; Alias = "ps1"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "89" },     
    [PSCustomObject]@{ID = 90    ; Name = "PuzzleScript"            ; Folder = "puzzlescript"     ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "90" },     
    [PSCustomObject]@{ID = 91    ; Name = "Satellaview"             ; Folder = "satellaview"      ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "91" },     
    [PSCustomObject]@{ID = 92    ; Name = "Sega Saturn"             ; Folder = "saturn"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "92" },     
    [PSCustomObject]@{ID = 93    ; Name = "ScummVM"                 ; Folder = "scummvm"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "93" },     
    [PSCustomObject]@{ID = 94    ; Name = "Super Cassette Vision"   ; Folder = "scv"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "94" },     
    [PSCustomObject]@{ID = 95    ; Name = "Sega 32X"                ; Folder = "sega32x"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "95" },     
    [PSCustomObject]@{ID = 96    ; Name = "Sega CD"                 ; Folder = "segacd"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "96" },     
    [PSCustomObject]@{ID = 97    ; Name = "(SNES)/(SFC)"            ; Folder = "sfc"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "97" },     
    [PSCustomObject]@{ID = 98    ; Name = "SG 1000"                 ; Folder = "sg-1000"          ; Alias = "sg1000"      ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "98" },     
    [PSCustomObject]@{ID = 99    ; Name = "Super Game Boy"          ; Folder = "sgb"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "99" },     
    [PSCustomObject]@{ID = 100   ; Name = "Super Nintendo"          ; Folder = "snes"             ; Alias = "sfc"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "100" },    
    [PSCustomObject]@{ID = 101   ; Name = "Super Nintendo Hacks"    ; Folder = "snes-hacks"       ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "101" },    
    [PSCustomObject]@{ID = 102   ; Name = "Super Nintendo MSU1"     ; Folder = "snesmsu1"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "102" },    
    [PSCustomObject]@{ID = 103   ; Name = "Solarus"                 ; Folder = "solarus"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "103" },    
    [PSCustomObject]@{ID = 104   ; Name = "SuFami Turbo"            ; Folder = "sufami"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "104" },    
    [PSCustomObject]@{ID = 105   ; Name = "Super Grafx"             ; Folder = "supergrafx"       ; Alias = "sgfx"        ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "105" },    
    [PSCustomObject]@{ID = 106   ; Name = "Watara Supervision"      ; Folder = "supervision"      ; Alias = "sv"          ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "106" },    
    [PSCustomObject]@{ID = 107   ; Name = "System Themes"           ; Folder = "themes"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "107" },    
    [PSCustomObject]@{ID = 108   ; Name = "Thomson MO/TO"           ; Folder = "thomson"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "108" },    
    [PSCustomObject]@{ID = 109   ; Name = "TI-99/4A"                ; Folder = "ti99"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "109" },    
    [PSCustomObject]@{ID = 110   ; Name = "TIC-80"                  ; Folder = "tic80"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "110" },    
    [PSCustomObject]@{ID = 110.1 ; Name = "Tiger LCD"               ; Folder = "tigerlcd"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $false   ; dArkOS = $true    ; RE_ID = "110.1" },  
    [PSCustomObject]@{ID = 111   ; Name = "ArkOS Tools"             ; Folder = "tools"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "111" },    
    [PSCustomObject]@{ID = 112   ; Name = "TurboGrafx-16"           ; Folder = "turbografx"       ; Alias = "pcengine"    ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "112" },    
    [PSCustomObject]@{ID = 113   ; Name = "TurboGrafx-CD"           ; Folder = "turbografxcd"     ; Alias = "pcenginecd"  ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "113" },    
    [PSCustomObject]@{ID = 114   ; Name = "Videoton TV-Computer"    ; Folder = "tvc"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "114" },    
    [PSCustomObject]@{ID = 115   ; Name = "Uzebox"                  ; Folder = "uzebox"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "115" },
    [PSCustomObject]@{ID = 115.2 ; Name = "Verticle Arcade"         ; Folder = "varcade"          ; Alias = "---"         ; G350_Src = "varcade"          ; ArkOS = $false   ; dArkOS = $false   ; RE_ID = "115.2" },    
    [PSCustomObject]@{ID = 116   ; Name = "Vectrex"                 ; Folder = "vectrex"          ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "116" },    
    [PSCustomObject]@{ID = 117   ; Name = "Commodore Vic-20"        ; Folder = "vic20"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "117" },    
    [PSCustomObject]@{ID = 117.1 ; Name = "Videopac"                ; Folder = "videopac"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $false   ; dArkOS = $true    ; RE_ID = "117.1" },  
    [PSCustomObject]@{ID = 118   ; Name = "System Videos"           ; Folder = "videos"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "118" },    
    [PSCustomObject]@{ID = 119   ; Name = "Vircon32"                ; Folder = "vircon32"         ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "119" },    
    [PSCustomObject]@{ID = 120   ; Name = "Virtual Boy"             ; Folder = "virtualboy"       ; Alias = "vb"          ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "120" },    
    [PSCustomObject]@{ID = 121   ; Name = "Apple Macintosh"         ; Folder = "vmac"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "121" },    
    [PSCustomObject]@{ID = 122   ; Name = "Dreamcast VMU"           ; Folder = "vmu"              ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "122" },    
    [PSCustomObject]@{ID = 123   ; Name = "WASM-4"                  ; Folder = "wasm4"            ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "123" },    
    [PSCustomObject]@{ID = 124   ; Name = "Wolfenstein 3D"          ; Folder = "wolf"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "124" },    
    [PSCustomObject]@{ID = 124.2 ; Name = "Half-Life (Xash3D)"      ; Folder = "ports/xash3d"     ; Alias = "---"         ; G350_Src = "xash3d_fwgs"      ; ArkOS = $false   ; dArkOS = $false   ; RE_ID = "124.2" },  
    [PSCustomObject]@{ID = 125   ; Name = "WonderSwan"              ; Folder = "wonderswan"       ; Alias = "ws"          ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "125" },    
    [PSCustomObject]@{ID = 126   ; Name = "WonderSwan Color"        ; Folder = "wonderswancolor"  ; Alias = "wsc"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "126" },    
    [PSCustomObject]@{ID = 127   ; Name = "Sharp X1"                ; Folder = "x1"               ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "127" },    
    [PSCustomObject]@{ID = 128   ; Name = "Sharp X68000"            ; Folder = "x68000"           ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "128" },    
    [PSCustomObject]@{ID = 129   ; Name = "ZX-81"                   ; Folder = "zx81"             ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "129" },    
    [PSCustomObject]@{ID = 130   ; Name = "ZX Spectrum"             ; Folder = "zxspectrum"       ; Alias = "---"         ; G350_Src = "---"              ; ArkOS = $true    ; dArkOS = $true    ; RE_ID = "130" }

)

# --- 1.4: DATABASE OS-SPECIFIC FLAG and SPECIAL ADDITIONS LOGIC ---
# --- [PSCustomObject]@{ID=xx.1 = Indicates: dArkOS_RE_ID specific folders
# --- [PSCustomObject]@{ID=xx.2 = Indicates: G350_Src specific folders


# ==============================================================================
# ==============================================================================
# SECTION 2: UI FRAME & THEME
# ==============================================================================


# --- 2.1: MAIN WINDOW DEFINITION ---
# The primary container for the entire utility
$global:Form = New-Object System.Windows.Forms.Form
$global:Form.Size = New-Object System.Drawing.Size(820, 850)
$global:Form.StartPosition = "CenterScreen"
$global:Form.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#f0f0f0")
$global:Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$global:Form.MaximizeBox = $false
$global:Form.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Hide

# --- 2.1.1: HEADER & TITLE ---
$global:Form.Text = "$global:ScriptTitle | $global:Cvers | Build: $global:BuildDate"

# --- 2.2: GLOBAL UI SCALING & THEME SETTINGS ---
# Set the icon (if you have one) or generic window properties here
# $global:Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")

# --- 2.3: SYSTEM COLORS & BRUSHES ---
# Defining shared colors here makes it easier to change the look later
$global:ColorDarkPanel = [System.Drawing.ColorTranslator]::FromHtml("#1e1e1e") #Formerly #2d2d2d, Try #212121, or #1a1a1a
$global:ColorButtonGray = [System.Drawing.ColorTranslator]::FromHtml("#dcdcdc")
$global:ColorSyncBlue = [System.Drawing.ColorTranslator]::FromHtml("#add8e6")
$global:ColorAbortRed = [System.Drawing.ColorTranslator]::FromHtml("#FF0000")
$global:ColorGboxLine = [System.Drawing.ColorTranslator]::FromHtml("#2d2d2d")

# ==============================================================================
# SECTION 3: UI CONTROLS (Labels, Buttons, & Logs)
# ==============================================================================

# --- 3.0: HEADER HELP OBJECT ---
$global:lblHelpHint = New-Object System.Windows.Forms.LinkLabel
$global:lblHelpHint.Text = "[?] How to use this tool" 
$global:lblHelpHint.Location = New-Object System.Drawing.Point(15, 0) 
$global:lblHelpHint.Size = New-Object System.Drawing.Size(160, 20)
$global:lblHelpHint.LinkColor = [System.Drawing.Color]::DimGray
$global:lblHelpHint.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$Form.Controls.Add($global:lblHelpHint)
$global:lblHelpHint.add_LinkClicked({ Show-HelpManual })


# --- 3.1: PATH SELECTION ROW (TOP) ---
$global:btnMaster = New-Object Windows.Forms.Button
$global:btnMaster.Text = "1. Select MASTER (PC)"
$global:btnMaster.Location = New-Object System.Drawing.Point(30, 20)
$global:btnMaster.Size = New-Object System.Drawing.Size(295, 45)
$global:btnMaster.BackColor = $global:ColorButtonGray

$global:btnReset = New-Object Windows.Forms.Button
$global:btnReset.Text = "Reset ALL Paths"
$global:btnReset.Location = New-Object System.Drawing.Point(330, 20)
$global:btnReset.Size = New-Object System.Drawing.Size(140, 45)
$global:btnReset.BackColor = $global:ColorButtonGray
$global:btnReset.Font = New-Object Drawing.Font("Segoe UI", 9, [Drawing.FontStyle]::Bold)

$global:btnSD = New-Object Windows.Forms.Button
$global:btnSD.Text = "2. Select TARGET (SD/PC)"
$global:btnSD.Location = New-Object System.Drawing.Point(475, 20)
$global:btnSD.Size = New-Object System.Drawing.Size(295, 45)
$global:btnSD.BackColor = $global:ColorButtonGray

# --- 3.2: STATUS DISPLAY (PATHs BOX) ---
$global:lblStatus = New-Object Windows.Forms.Label
$global:lblStatus.Text = "Ready"
$global:lblStatus.Location = New-Object System.Drawing.Point(30, 75)
$global:lblStatus.Size = New-Object System.Drawing.Size(740, 45)
$global:lblStatus.TextAlign = "MiddleLeft"
$global:lblStatus.Font = New-Object Drawing.Font("Consolas", 9)
$global:lblStatus.BackColor = $global:ColorDarkPanel
$global:lblStatus.ForeColor = [System.Drawing.Color]::White

$global:btnSync = New-Object Windows.Forms.Button
$global:btnSync.Text = "UNIVERSAL SYNC"
$global:btnSync.Location = New-Object System.Drawing.Point(30, 130)
$global:btnSync.Size = New-Object System.Drawing.Size(295, 55)
$global:btnSync.BackColor = $global:ColorSyncBlue
$global:btnSync.Enabled = $false

$global:btnAbort = New-Object Windows.Forms.Button
$global:btnAbort.Text = "ABORT"
$global:btnAbort.Location = New-Object System.Drawing.Point(330, 130)
$global:btnAbort.Size = New-Object System.Drawing.Size(65, 55)
$global:btnAbort.BackColor = $global:ColorAbortRed
$global:btnAbort.ForeColor = [System.Drawing.Color]::White
$global:btnAbort.Font = New-Object Drawing.Font("Segoe UI", 10, [Drawing.FontStyle]::Bold)
$global:btnAbort.Enabled = $false

$global:btnCleanup = New-Object Windows.Forms.Button
$global:btnCleanup.Text = "CLEANUP"
$global:btnCleanup.Location = New-Object System.Drawing.Point(402, 130)
$global:btnCleanup.Size = New-Object System.Drawing.Size(180, 55)
$global:btnCleanup.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#ffb6c1")
$global:btnCleanup.Enabled = $false

# Cleanup Mode GroupBox
$global:gbCleanMode = New-Object Windows.Forms.GroupBox
$global:gbCleanMode.Text = "Cleanup Mode Select"
$global:gbCleanMode.Location = New-Object System.Drawing.Point(592, 127)
$global:gbCleanMode.Size = New-Object System.Drawing.Size(173, 57)
$global:gbCleanMode.ForeColor = [System.Drawing.Color]::Black
$global:gbCleanMode.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)

$global:rbMirrSource = New-Object Windows.Forms.RadioButton
$global:rbMirrSource.Text = "Mirror Source"
$global:rbMirrSource.Location = New-Object System.Drawing.Point(10, 14)
$global:rbMirrSource.ForeColor = [System.Drawing.Color]::Black
$global:rbMirrSource.AutoSize = $true 
$global:rbMirrSource.Checked = $true

$global:rbDeleteEmpty = New-Object Windows.Forms.RadioButton
$global:rbDeleteEmpty.Text = "Delete Empty Folders"
$global:rbDeleteEmpty.Location = New-Object System.Drawing.Point(10, 33)
$global:rbDeleteEmpty.ForeColor = [System.Drawing.Color]::Black
$global:rbDeleteEmpty.AutoSize = $true

$global:gbCleanMode.Controls.AddRange(@($global:rbMirrsource, $global:rbDeleteEmpty))

# --- 3.6: POWER CLONE BUTTON (unShrunk & unCentered) ---
$global:btnPowerClone = New-Object Windows.Forms.Button
$global:btnPowerClone.Text = "POWER CLONE"
$global:btnPowerClone.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#ffd700")
$global:btnPowerClone.ForeColor = [System.Drawing.Color]::White
$global:btnPowerClone.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$global:btnPowerClone.Size = New-Object System.Drawing.Size(365, 55) 
$global:btnPowerClone.Location = New-Object System.Drawing.Point(30, 190) # Adjusted for the new center

# --- 3.5: CLONE MODE GROUPBOX (Expanded & Aligned) ---
$global:gbCloneMode = New-Object Windows.Forms.GroupBox
$global:gbCloneMode.Text = "Clone Mode Select"
$global:gbCloneMode.Location = New-Object System.Drawing.Point(405, 187)
$global:gbCloneMode.Size = New-Object System.Drawing.Size(359, 57)
$global:gbCloneMode.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)

# Left Side Column
$global:rbFoldersOnly = New-Object Windows.Forms.RadioButton
$global:rbFoldersOnly.Text = "Folders Only"
$global:rbFoldersOnly.Location = New-Object System.Drawing.Point(10, 12)
$global:rbFoldersOnly.Checked = $true

$global:rbEverything = New-Object Windows.Forms.RadioButton
$global:rbEverything.Text = "EVERYTHING"
$global:rbEverything.Location = New-Object System.Drawing.Point(10, 31)

# Right Side Column (Inline with Folders)
$global:rbSystemOnly = New-Object Windows.Forms.RadioButton
$global:rbSystemOnly.Text = "System Only (BIOS/Ports/Tools)"
$global:rbSystemOnly.Location = New-Object System.Drawing.Point(150, 14) # Moved to the right
$global:rbSystemOnly.AutoSize = $true

# NEW: ROMs Only Radio Button (Placed directly under System Only)
$global:rbRomsOnly = New-Object Windows.Forms.RadioButton
$global:rbRomsOnly.Text = "ROMs Only (No System Folders)"
$global:rbRomsOnly.Location = New-Object System.Drawing.Point(150, 33) 
$global:rbRomsOnly.AutoSize = $true

$global:gbCloneMode.Controls.AddRange(@(
        $global:rbFoldersOnly, 
        $global:rbEverything, 
        $global:rbSystemOnly, 
        $global:rbRomsOnly
    ))

# --- 3.4: OS GENERATION & TOOLS ---
$global:btnGenArk = New-Object Windows.Forms.Button
$global:btnGenArk.Text = "GEN: ArkOS"
$global:btnGenArk.Location = New-Object System.Drawing.Point(30, 252)
$global:btnGenArk.Size = New-Object System.Drawing.Size(180, 55)
$global:btnGenArk.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#99FF00")
$global:btnGenArk.Enabled = $false

$global:btnGenDark = New-Object Windows.Forms.Button
$global:btnGenDark.Text = "GEN: dArkOS"
$global:btnGenDark.Location = New-Object System.Drawing.Point(215, 252)
$global:btnGenDark.Size = New-Object System.Drawing.Size(180, 55)
$global:btnGenDark.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#66FF00")
$global:btnGenDark.Enabled = $false

$global:btnGenDarkRE = New-Object Windows.Forms.Button
$global:btnGenDarkRE.Text = "GEN: dArkOS-RE"
$global:btnGenDarkRE.Location = New-Object System.Drawing.Point(401, 252)
$global:btnGenDarkRE.Size = New-Object System.Drawing.Size(180, 55)
$global:btnGenDarkRE.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#33FF00")
$global:btnGenDarkRE.Enabled = $false

$global:btnGenG350 = New-Object Windows.Forms.Button
$global:btnGenG350.Text = "G350 Source"
$global:btnGenG350.Location = New-Object System.Drawing.Point(587, 252)
$global:btnGenG350.Size = New-Object System.Drawing.Size(180, 55)
$global:btnGenG350.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#ffeb3b")
$global:btnGenG350.Font = New-Object Drawing.Font("Segoe UI", 9, [Drawing.FontStyle]::Bold)
$global:btnGenG350.Enabled = $false

# The Audit Button
$global:btnAudit = New-Object System.Windows.Forms.Button
$global:btnAudit.Text = "RUN FULL 130-SYSTEM AUDIT"
$global:btnAudit.Location = New-Object System.Drawing.Point(30, 315)
$global:btnAudit.Size = New-Object System.Drawing.Size(180, 55)
$global:btnAudit.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#e0e0e0")
$global:btnAudit.Enabled = $false # Keep disabled until paths are set

# File Report Enable GroupBox for Audit
$global:gbToggleAudit = New-Object Windows.Forms.GroupBox
$global:gbToggleAudit.Text = "File Creation Toggle"
$global:gbToggleAudit.Location = New-Object System.Drawing.Point(215, 312)
$global:gbToggleAudit.Size = New-Object System.Drawing.Size(175, 57)
$global:gbToggleAudit.ForeColor = [System.Drawing.Color]::Black
$global:gbToggleAudit.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)

# .txt checkbox for Audit
$global:chkToggleAtxt = New-Object Windows.Forms.CheckBox
$global:chkToggleAtxt.Text = "Create .txt"
$global:chkToggleAtxt.Location = New-Object System.Drawing.Point(10, 16)
$global:chkToggleAtxt.ForeColor = [System.Drawing.Color]::Black
$global:chkToggleAtxt.AutoSize = $true
$global:chkToggleAtxt.Checked = $script:GenerateAuditTxt   # start with current setting

# .csv checkbox for Audit
$global:chkToggleAcsv = New-Object Windows.Forms.CheckBox
$global:chkToggleAcsv.Text = "Create .csv"
$global:chkToggleAcsv.Location = New-Object System.Drawing.Point(10, 34)
$global:chkToggleAcsv.ForeColor = [System.Drawing.Color]::Black
$global:chkToggleAcsv.AutoSize = $true
$global:chkToggleAcsv.Checked = $script:GenerateAuditCsv   # start with current setting

$global:gbToggleAudit.Controls.AddRange(@($global:chkToggleAtxt, $global:chkToggleAcsv))

# The SD Card Speed Test Button
$global:btnSDSpeed = New-Object System.Windows.Forms.Button
$global:btnSDSpeed.Text = "RUN WinSAT SD Speed Test"
$global:btnSDSpeed.Location = New-Object System.Drawing.Point(401, 315)
$global:btnSDSpeed.Size = New-Object System.Drawing.Size(180, 55)
$global:btnSDSpeed.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#e0e0e0")
$global:btnSDSpeed.Enabled = $true   # Keep disabled until paths are set

# File Report Enable GroupBox for Speed Test
$global:gbToggleSDSpeed = New-Object Windows.Forms.GroupBox
$global:gbToggleSDSpeed.Text = "File Creation Toggle"
$global:gbToggleSDSpeed.Location = New-Object System.Drawing.Point(587, 312)
$global:gbToggleSDSpeed.Size = New-Object System.Drawing.Size(175, 57)
$global:gbToggleSDSpeed.ForeColor = [System.Drawing.Color]::Black
$global:gbToggleSDSpeed.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)

# .txt checkbox for Speed Test
$global:chkToggleStxt = New-Object Windows.Forms.CheckBox
$global:chkToggleStxt.Text = "Create .txt"
$global:chkToggleStxt.Location = New-Object System.Drawing.Point(10, 16)
$global:chkToggleStxt.ForeColor = [System.Drawing.Color]::Black
$global:chkToggleStxt.AutoSize = $true
$global:chkToggleStxt.Checked = $script:GenerateSdTxt

# .csv checkbox for Speed Test
$global:chkToggleScsv = New-Object Windows.Forms.CheckBox
$global:chkToggleScsv.Text = "Append .csv"
$global:chkToggleScsv.Location = New-Object System.Drawing.Point(10, 34)
$global:chkToggleScsv.ForeColor = [System.Drawing.Color]::Black
$global:chkToggleScsv.AutoSize = $true
$global:chkToggleScsv.Checked = $script:GenerateSdCsv

$global:gbToggleSDSpeed.Controls.AddRange(@($global:chkToggleStxt, $global:chkToggleScsv))

# --- 3.6: MONITORING (PROGRESS & LOG) ---

# --- Create a lighter timer (1 second is plenty) ---
$global:UITimer = New-Object System.Windows.Forms.Timer
$global:UITimer.Interval = 1000   # was 500 – less frequent is much better

$global:UITimer.add_Tick({
    if ($global:TransferActive) {
        Update-UIProgress `
            -BytesDone  $global:CurrentBytes `
            -TotalBytes $global:TotalJobBytes `
            -Stopwatch  $global:TransferWatch `
            -FileName   $global:CurrentFile
    }
})
$global:UITimer.Start()

$global:lblAction = New-Object Windows.Forms.Label
$global:lblAction.Text = "Ready"
$global:lblAction.Location = New-Object System.Drawing.Point(30, 380)
$global:lblAction.Size = New-Object System.Drawing.Size(740, 25)
$global:lblAction.Font = New-Object Drawing.Font("Consolas", 10)
$global:lblAction.Visible = $true  # <--- HIDE UNTIL NEEDED

$global:ProgressBar = New-Object Windows.Forms.ProgressBar
$global:ProgressBar.Location = New-Object System.Drawing.Point(30, 400)
$global:ProgressBar.Size = New-Object System.Drawing.Size(735, 25)
$global:ProgressBar.Visible = $true  # <--- HIDE BY DEFAULT

$global:Log = New-Object Windows.Forms.TextBox
$global:Log.Multiline = $true
$global:Log.ReadOnly = $true
$global:Log.Location = New-Object System.Drawing.Point(30, 435)
$global:Log.Size = New-Object System.Drawing.Size(760, 350)
$global:Log.ScrollBars = "vertical"
$global:Log.WordWrap = $false          # ← critical
$global:Log.Font = New-Object Drawing.Font("Consolas", 9)
$global:Log.BackColor = $global:ColorDarkPanel
$global:Log.ForeColor = [System.Drawing.Color]::White


# --- 3.7: FOOTER & GITHUB LINK ---

$global:lblGitHub = New-Object System.Windows.Forms.LinkLabel
# Use single quotes around the whole string so the double quotes stay as text
$global:lblGitHub.Text = "$global:ScriptFname1 $global:Cvers | GitHub.com | Click for Updates"
$global:lblGitHub.Location = New-Object System.Drawing.Point(30, 790)
$global:lblGitHub.Size = New-Object System.Drawing.Size(400, 20)
$global:lblGitHub.LinkColor = [System.Drawing.Color]::Gray
$global:lblGitHub.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)

# Make the entire string clickable
$global:lblGitHub.LinkArea = New-Object System.Windows.Forms.LinkArea(0, $global:lblGitHub.Text.Length)

# Section: Footer Support (Standardized for all projects)
# 1. The Static Text (Gray)
$global:lblSupportText = New-Object System.Windows.Forms.Label
$global:lblSupportText.Text = "Support"
$global:lblSupportText.Location = New-Object Drawing.Point(722, 790) # Matches GitHub Y-axis
$global:lblSupportText.AutoSize = $true
$global:lblSupportText.ForeColor = [System.Drawing.Color]::Gray
$global:lblSupportText.Font = New-Object Drawing.Font("Segoe UI Symbol", 9, [System.Drawing.FontStyle]::Italic)
# 2. The Heart (Red)
$global:lblSupport = New-Object System.Windows.Forms.LinkLabel
$global:lblSupport.Text = "$([char]0x2764)" # Heart Unicode (U+2764)
$global:lblSupport.Location = New-Object System.Drawing.Point(772, 790)
$global:lblSupport.AutoSize = $true
$global:lblSupport.LinkColor = [System.Drawing.Color]::Red
$global:lblSupport.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 10, [System.Drawing.FontStyle]::Bold)
$global:lblSupport.LinkBehavior = [System.Windows.Forms.LinkBehavior]::NeverUnderline
$global:lblSupport.Add_LinkClicked({ Start-Process "https://ko-fi.com/kofisupporter19535" })
# 1. Create the ToolTip object
$global:toolTipSupport = New-Object System.Windows.Forms.ToolTip
$global:toolTipSupport.InitialDelay = 500  # Delay in milliseconds before showing
$global:toolTipSupport.AutoPopDelay = 5000 # How long it stays visible
$global:toolTipSupport.ToolTipTitle = "Support the Project"

# 2. Attach it to your Heart label
$global:toolTipSupport.SetToolTip($global:lblSupport, "Click here to support via Ko-fi!")


# 3. Ensure it's at the VERY FRONT of the layering
$global:lblSupport.BringToFront() 


$Form.Controls.Add($global:lblHelpHint)

# ==============================================================================
# SECTION 4: THE ENGINE (Functions)
# ==============================================================================
# Function 4.0: Set UI State
function Set-UIState {
    param([bool]$IsWorking)
    
    # Force a refresh to clear the "pissed off" UI buffer
    [System.Windows.Forms.Application]::DoEvents()

    # 1. Flip Action Buttons
    $global:btnSync.Enabled = -not $IsWorking
    $global:btnPowerClone.Enabled = -not $IsWorking
    $global:btnCleanup.Enabled = -not $IsWorking
    $global:btnReset.Enabled = -not $IsWorking

    # 2. Configure Abort
    if ($IsWorking) {
        $global:btnAbort.Enabled = $true
        $global:btnAbort.BackColor = [System.Drawing.Color]::DarkRed
        $global:btnAbort.Text = "ABORT"
    }
    else {
        $global:btnAbort.Enabled = $false
        # Standardize: Revert to the original DarkRed/White theme so it looks 'Armed'
        $global:btnAbort.BackColor = [System.Drawing.Color]::DarkRed 
        $global:btnAbort.Text = "ABORT" # Keep it as ABORT so it stays symmetrical
    }

    # 3. CRITICAL: Force the form to redraw NOW
    $global:Form.Refresh() 
    [System.Windows.Forms.Application]::DoEvents()
}

# Function 4.1: Check if Master and Target paths are set
function Test-PathsReady {
    param(
        [string]$ActionName,
        [bool]$DestinationOnly = $false
    )
    
    # 1. Target is always mandatory
    if ([string]::IsNullOrWhiteSpace($global:DestPath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a TARGET folder before running: $ActionName", "Paths Not Set",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return $false
    }

    # 2. Master is only mandatory if NOT Destination-Only
    if (-not $DestinationOnly -and [string]::IsNullOrWhiteSpace($global:SourcePath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a MASTER folder before running: $ActionName", "Paths Not Set",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return $false
    }

    return $true
}

# Function 4.2: Universal Progress Bar & Dashboard Updater
function Update-UIProgress {
    param(
        [long]$BytesDone,
        [long]$TotalBytes,
        $Stopwatch,
        [string]$FileName
    )

    # --- Percentage (always update the bar, it’s relatively cheap) ---
    $percent = if ($TotalBytes -gt 0) {
        [math]::Min(100, [int](($BytesDone / $TotalBytes) * 100))
    } else { 0 }

    if ($global:ProgressBar.Value -ne $percent) {
        $global:ProgressBar.Value = $percent
    }

    # --- Only do the expensive text/speed work every ~1 second ---
    $now = $Stopwatch.Elapsed.TotalMilliseconds
    if ($null -eq $global:LastUpdate) { $global:LastUpdate = 0 }

    if (($now - $global:LastUpdate) -lt 900) { return }   # skip most of the work
    $global:LastUpdate = $now

    # --- Elapsed time ---
    $elapsed = $Stopwatch.Elapsed
    $elapsedStr = $elapsed.ToString("hh\:mm\:ss")

    # --- Simple speed calculation (no rolling queue needed for good enough results) ---
    $seconds = $elapsed.TotalSeconds
    $avgBps  = if ($seconds -gt 0.5) { $BytesDone / $seconds } else { 0 }
    $speed   = [math]::Round($avgBps / 1MB, 1)

    # --- ETA ---
    $remainStr = "--:--"
    if ($avgBps -gt 50KB -and $TotalBytes -gt $BytesDone) {
        $secondsLeft = ($TotalBytes - $BytesDone) / $avgBps
        $ts = [TimeSpan]::FromSeconds($secondsLeft)
        $remainStr = if ($ts.TotalHours -ge 1) {
            $ts.ToString("hh\:mm\:ss")
        } else {
            $ts.ToString("mm\:ss")
        }
    }

    # --- Filename truncation ---
    $displayName = if ($FileName.Length -gt 22) {
        $FileName.Substring(0, 19) + "..."
    } else { $FileName }

    # --- Update label (no .Refresh() needed) ---
    $global:lblAction.Text = "Progress: {0,3}% | {1,4} MB/s | Time: {2} | Left: {3} | {4}" -f `
        $percent, $speed, $elapsedStr, $remainStr, $displayName

    # --- DoEvents only when we actually update the text (much rarer) ---
    [System.Windows.Forms.Application]::DoEvents()
}

# Function 4.3: Historical Logging Helper
function Update-Log {
    param([string]$Message, [bool]$Highlight = $false)
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $global:Log.AppendText("[$timestamp] > $Message`r`n")
    
    if ($Highlight) {
        $global:lblAction.Text = $Message
        $global:lblAction.Visible = $true
    }
    # Auto-scroll to bottom
    $global:Log.SelectionStart = $global:Log.Text.Length
    $global:Log.ScrollToCaret()
}

# Function 4.4: Master/Target Folder Selection
function Set-Path {
    param([string]$Type)
    
    $fb = New-Object Windows.Forms.FolderBrowserDialog
    $fb.ShowNewFolderButton = $true
    
    if ($fb.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
        if ($Type -eq "Master") {
            $global:SourcePath = $fb.SelectedPath
            Update-Log "MASTER SET: $global:SourcePath"
            
            # WAKE UP BOTH-PATHS BUTTONS (If Target was already selected first)
            if ($global:DestPath -ne "") {
                $global:btnSync.Enabled = $true
                $global:btnPowerClone.Enabled = $true
                $global:btnGenG350.Enabled = $true # Enforced here!
            }
        } 
        else {
            $global:DestPath = $fb.SelectedPath
            Update-Log "TARGET SET: $global:DestPath"
            
            # WAKE UP TARGET-ONLY BUTTONS
            $global:btnAudit.Enabled = $true
            $global:btnGenArk.Enabled = $true
            $global:btnGenDark.Enabled = $true
            $global:btnGenDarkRE.Enabled = $true
            $global:btnCleanup.Enabled = $true
            $global:btnAudit.BackColor = [System.Drawing.Color]::LightGreen
            
            # WAKE UP BOTH-PATHS BUTTONS (If Master was already selected first)
            if ($global:SourcePath -ne "") {
                $global:btnSync.Enabled = $true
                $global:btnPowerClone.Enabled = $true
                $global:btnGenG350.Enabled = $true # Enforced here!
            }
        }
        
        $global:lblStatus.Text = "MASTER: $($global:SourcePath)`r`nTARGET: $($global:DestPath)"
    }
}

# Function 4.5: Full System Scan & Report Generation
function Invoke-Audit {
    param($Path, $FileName)
    if (-not ([System.IO.Directory]::Exists($Path))) { return }

    $w = $script:ReportWidth

    # --- UI Header ---
    $global:Log.AppendText("`r`n" + ("=" * $w) + "`r`n")
    Update-Log "INITIATING AUDIT: $Path" $true

    $LogTemplate = "{0,-5} | {1,-22} | {2,-15} | {3,-11} | {4,5} | {5,5} | {6,4} | {7,4} | {8,7}"
    $headerRow = $LogTemplate -f "ID", "System Name", "Folder", "Alias", "Games", "Art", "List", "Supp", "MB"
    $global:Log.AppendText("$headerRow`r`n" + ("-" * $w) + "`r`n")

    # --- File Storage ---
    $fileResults = @()
    $fileResults += "--- AUDIT REPORT: $Path ---"
    $fileResults += "Generated: $(Get-Date)"
    $fileResults += $headerRow
    $fileResults += ("-" * $w)

    # CSV setup (only if enabled)
    $csvResults = @()
    if ($script:GenerateAuditCsv) {
        $csvResults += "ID,SystemName,Folder,Alias,Games,Art,Lists,Support,SizeMB"
    }

    $folders = Get-ChildItem $Path -Directory | Sort-Object Name
    $totalGames = 0; $totalArt = 0; $totalList = 0; $totalSupport = 0; $totalSize = 0

    foreach ($folderObj in $folders) {

        $allFiles = Get-ChildItem $folderObj.FullName -File -Recurse -ErrorAction SilentlyContinue

        # ---- Categorize files (mutually exclusive) ----
        $games    = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        $boxart   = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        $gamelist = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        $support  = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

        foreach ($file in $allFiles) {
            $ext = $file.Extension.ToLower()

            if (($global:GameExtensions -contains $ext) -or 
                ($ext -eq ".png" -and $file.FullName -match "pico-8")) {
                $games.Add($file)
            }
            elseif ($global:BoxArtExtensions -contains $ext) {
                $boxart.Add($file)
            }
            elseif ($global:GamelistExtensions -contains $ext) {
                $gamelist.Add($file)
            }
            elseif ($global:SupportExtensions -contains $ext) {
                $support.Add($file)
            }
        }

        $sizeMB = if ($games.Count -gt 0) {
            [math]::Round(($games | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
        } else { 0 }

        # ---- Database lookup ----
        $allMatches = $global:SystemDatabase | Where-Object { 
            ($_.Folder -eq $folderObj.Name) -or ($_.Folder -split '[\\/]' -contains $folderObj.Name)
        }
        $dbMatch = $allMatches | Sort-Object { $_.Folder.Length } | Select-Object -First 1

        $id    = if ($dbMatch.ID)    { $dbMatch.ID }    else { "???" }
        $name  = if ($dbMatch.Name)  { $dbMatch.Name }  else { "---" }
        $alias = if ($dbMatch.Alias) { $dbMatch.Alias } else { "---" }

        # ---- Output line (text report) ----
        $line = $LogTemplate -f $id, $name, $folderObj.Name, $alias, 
                               $games.Count, $boxart.Count, $gamelist.Count, $support.Count, $sizeMB

        $global:Log.AppendText("$line`r`n")
        $fileResults += $line

        # ---- CSV row ----
        if ($script:GenerateAuditCsv) {
            $csvResults += "$id,`"$name`",`"$($folderObj.Name)`",`"$alias`",$($games.Count),$($boxart.Count),$($gamelist.Count),$($support.Count),$sizeMB"
        }

        # Running totals
        $totalGames   += $games.Count
        $totalArt     += $boxart.Count
        $totalList    += $gamelist.Count
        $totalSupport += $support.Count
        $totalSize    += $sizeMB

        [System.Windows.Forms.Application]::DoEvents()
    }

    # ============================================================
    # TOTALS LINE
    # ============================================================
    $separator = ("-" * $w)
    $global:Log.AppendText($separator + "`r`n")
    $fileResults += $separator

    $totalsLine = $LogTemplate -f "", "TOTALS", $folders.Count, "", 
                                 $totalGames, $totalArt, $totalList, $totalSupport, 
                                 ("{0:N1}" -f $totalSize)

    $global:Log.AppendText($totalsLine + "`r`n")
    $fileResults += $totalsLine

if ($script:GenerateAuditCsv) {
    $csvResults += "TOTALS,,$($folders.Count),,$totalGames,$totalArt,$totalList,$totalSupport,$([math]::Round($totalSize,1))"

    # Summary line for CSV
    $csvResults += "SUMMARY,$($folders.Count) Folders,$totalGames Games,$totalArt Art,$totalList Lists,$totalSupport Support,$([math]::Round($totalSize,1)) MB,($([math]::Round($totalSize / 1024, 2)) GB)"
}

    # ============================================================
    # SUMMARY LINE
    # ============================================================
    $summary = "`r`nSUMMARY: $($folders.Count) Folders | $totalGames Games | $totalArt Art | $totalList Lists | $totalSupport Support | " +
               "$([math]::Round($totalSize, 1)) MB ($([math]::Round($totalSize / 1024, 2)) GB)"

    $global:Log.AppendText($summary + "`r`n" + ("=" * $w) + "`r`n")
    $fileResults += $summary
    $fileResults += ("=" * $w)

# ============================================================
# SAVE FILES
# ============================================================

# Text report
if ($script:GenerateAuditTxt) {
    $OutputPathTxt = Join-Path $Path $FileName
    $fileResults | Out-File -FilePath $OutputPathTxt -Force -Encoding utf8
    Update-Log "TEXT REPORT SAVED: $OutputPathTxt"
}

# CSV report
if ($script:GenerateAuditCsv) {
    $csvFileName = [System.IO.Path]::ChangeExtension($FileName, ".csv")
    $OutputPathCsv = Join-Path $Path $csvFileName
    $csvResults | Out-File -FilePath $OutputPathCsv -Force -Encoding utf8
    Update-Log "CSV REPORT SAVED:  $OutputPathCsv"
}
}

# Function 4.5.1: Report Generation Orchestrator, Master first, Target Second
function Invoke-FullAudit {
    Reset-ActionDisplay
    
    # 1. Audit Master FIRST (Top of Log)
    if ($global:SourcePath) {
        $global:lblAction.Text = "Auditing Master..."
        Invoke-Audit $global:SourcePath "Master_Audit.txt"
    }

    # 2. Audit Target LAST (Bottom of Log / Screen)
    if ($global:DestPath) {
        $global:lblAction.Text = "Auditing Target..."
        Invoke-Audit $global:DestPath "Target_Audit.txt"
    }
    
    $global:lblAction.Text = "Audit Complete."
}

# Function 4.6.0: Universal Folder logger
function Update-ActionLog {
    param([string]$Action, [string]$ID, [string]$Name)

    # Clean alignment for the Log Window
    $logMsg = "[{0,-7}] ({1,3}) {2}" -f $Action, $ID, $Name
    $global:Log.AppendText("$logMsg`r`n")
    
    # Auto-scroll
    $global:Log.SelectionStart = $global:Log.Text.Length
    $global:Log.ScrollToCaret()

    # DO NOT update the lblAction here anymore, 
    # let Update-UIProgress handle the fast-moving file names.
    [System.Windows.Forms.Application]::DoEvents()
}

# Function 4.6.1: OS-Specific Folder Creation (RE-Aware)
function Invoke-Generation {
    param([string]$OSTarget)
    
    # 1. DYNAMIC PATH CHECK: G350 requires BOTH paths, ArkOS variants only require Target!
    $isDestOnly = ($OSTarget -ne "G350Src")
    if (-not (Test-PathsReady "Generation ($OSTarget)" $isDestOnly)) { return }

    Reset-ActionDisplay
    $global:Log.AppendText("`r`n" + ("*" * $w) + "`r`n")
    Update-Log "GENERATING $OSTarget STRUCTURE..." $true
    $count = 0
    
    foreach ($sys in $global:SystemDatabase) {
        # --- RESTORED LOGIC GATE ---
        # G350 MUST evaluate physical paths on the Master drive to filter correctly!
        if ($OSTarget -eq "G350Src") {
            $srcFolder = if ($sys.G350_Src -ne "---") { $sys.G350_Src } else { $sys.Folder }
            $shouldCreate = ($sys.G350_Src -ne "---" -and ([System.IO.Directory]::Exists((Join-Path $global:SourcePath $srcFolder))))
        }
        elseif ($OSTarget -match "RE") {
            $shouldCreate = ($sys.dArkOS -eq $true)
        }
        else {
            $shouldCreate = ($sys.$OSTarget -eq $true)
        }

        if ($shouldCreate) {
            # Determine the exact name the target folder should have
            $folderName = if ($OSTarget -eq "G350Src") { $sys.G350_Src } else { $sys.Folder }
            $targetPath = Join-Path $global:DestPath $folderName

            # --- THE SAFETY GATE: Check for Subfolders ---
            if ($folderName -match '[\\/]') {
                $parentDir = Split-Path $targetPath -Parent
                if (!([System.IO.Directory]::Exists($parentDir)) -and (Split-Path $parentDir -Leaf)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }
            }

            if (!([System.IO.Directory]::Exists($targetPath))) {
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                
                # --- LOGGING ---
                $displayID = if ($OSTarget -match "RE") { $sys.RE_ID } else { $sys.ID }
                Update-ActionLog -Action "CREATED" -ID $displayID -Name $sys.Name
                $count++
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    # --- UI SANITIZATION ---
    $global:ProgressBar.Value = 100 
    [System.Windows.Forms.Application]::DoEvents()
    $global:ProgressBar.Visible = $false
    Update-Log "GEN COMPLETE: $count clean folders prepared for migration." $true
}

# Function 4.7: Centralized File Transfer Logic (v1.1.0 - Timer Optimized)
function Start-FileTransfer {
    param($FileList, $Title)

    # --- 1. INITIALIZATION: Resetting the "Relays" ---
    $global:btnSync.Enabled = $false
    $global:btnPowerClone.Enabled = $false
    $global:AbortSync = $false
    $global:btnAbort.Enabled = $true
    
    $global:ProgressBar.Value = 0
    $global:ProgressBar.Visible = $true
    $global:lblAction.Visible = $true
    Update-Log "STARTING: $Title" $true

    # --- 2. DATA PREP: Discovery & Metadata Gathering ---
    $totalBytes = 0
    $processedFiles = foreach ($f in $FileList) {
        # Fix for potential path-as-object vs path-as-string issues
        $path = if ($f.Path) { $f.Path } else { $f }
        
        if ([System.IO.File]::Exists($path)) {
            $fInfo = New-Object System.IO.FileInfo($path)
            $totalBytes += $fInfo.Length
            [PSCustomObject]@{ 
                Path      = $path; 
                Size      = $fInfo.Length; 
                Name      = $fInfo.Name; 
                Dir       = $fInfo.DirectoryName; 
                LastWrite = $fInfo.LastWriteTime 
            }
        }
    }

    if ($processedFiles.Count -eq 0) {
        Update-Log "ERROR: No valid files found for transfer." $true
        $global:btnSync.Enabled = $true
        $global:btnPowerClone.Enabled = $true
        return
    }

    # --- 3. PREPARATION: High-Speed Timer Ignition ---
    $global:TotalJobBytes = $totalBytes     # Sets the 100% mark
    $global:CurrentBytes = 0               # Resets the counter
    $global:TransferWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $global:TransferActive = $true          # Wakes up the Background Timer
    
    $lastFolder = ""
    $count = 0
    $bytesDone = 0

    # --- 4. ENGINE ROOM: The Transfer Loop ---
    foreach ($file in $processedFiles) {
        if ($global:AbortSync) { break }

        # Update filename so Timer can display it immediately
        $global:CurrentFile = $file.Name

        # Path Logic: Stripping Source and joining to Destination
        $relPath = $file.Path.Replace($global:SourcePath, "").TrimStart('\')
        $targetFile = Join-Path $global:DestPath $relPath
        $targetDir = Split-Path $targetFile
        $currentFolder = Split-Path $file.Dir -Leaf

        # --- GPS LOGGING (System/Folder Level) ---
        if ($currentFolder -ne $lastFolder) {
            $dbMatch = $global:SystemDatabase | Where-Object { $_.Folder -eq $currentFolder }
            $id = if ($dbMatch.ID) { $dbMatch.ID } else { "---" }
            $name = if ($dbMatch.Name) { $dbMatch.Name } else { $currentFolder }
            Update-ActionLog -Action "COPYING" -ID $id -Name $name
            $lastFolder = $currentFolder
        }

        # --- EXECUTION: Professional Robocopy for Large Files ---
        # Logic: If file doesn't exist OR source is newer than target
        if (!([System.IO.File]::Exists($targetFile)) -or ($file.LastWrite -gt (Get-Item -LiteralPath $targetFile).LastWriteTime)) {
            if (!([System.IO.Directory]::Exists($targetDir))) { 
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null 
            }
            
            # THE WORKHORSE: Keeping your high-integrity flags
            robocopy $file.Dir $targetDir $file.Name /J /Z /MT:8 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
            $count++
        } 
        else {
            # THE SKIPPING DIALOGUE: For files that are already perfect
            # This makes the "Resume" feel fast and intelligent
            Update-Log "SKIPPING: $($file.Name)"
        }

        # --- PROGRESS UPDATE (The Clean Version) ---
        $bytesDone += $file.Size
        $global:CurrentBytes = $bytesDone # Only do this ONCE!
        
        # Use Byte Volume for the Percentage for 1:1 accuracy with the timer
        if ($global:TotalJobBytes -gt 0) {
            $percent = [int](($global:CurrentBytes / $global:TotalJobBytes) * 100)
            
            # Professional SQA "Safety Guard"
            if ($percent -gt 100) { $percent = 100 }
            
            $global:ProgressBar.Value = $percent
        }

        # Keep UI responsive for the Abort button
        [System.Windows.Forms.Application]::DoEvents()
    }

    # --- 5. FINALIZE: Powering Down the Relays ---
    $global:TransferActive = $false # Stop the background clock
    $global:TransferWatch.Stop()
    
    $global:btnAbort.Enabled = $false
    $global:ProgressBar.Visible = $false
    $global:btnSync.Enabled = $true
    $global:btnPowerClone.Enabled = $true

    if ($global:AbortSync) {
        Update-Log "!!! OPERATION HALTED BY USER !!!" $true
        $global:lblAction.Text = "ABORTED: Process Stopped."
        $global:lblAction.ForeColor = [System.Drawing.Color]::Red
    }
    else {
        Update-Log "SUCCESS: $count files processed." $true
        $global:lblAction.Text = "Operation Complete."
        Invoke-Audit $global:DestPath "Target_Audit.txt"
    }
}

# Function 4.8: Smart Sync & Brute Clone Handlers (v1.0.0 Stable)
function Invoke-UniversalSync {
    if (-not (Test-PathsReady "Universal Sync")) { return }

    # --- RESET THE RELAYS ---
    $global:AbortSync = $false
    $global:lblAction.ForeColor = [System.Drawing.Color]::Black
    $global:btnAbort.Enabled = $true
    
    # Disable the Clone button so they don't fight!
    $global:btnPowerClone.Enabled = $false 

    # 1. Update Log with Header
    $global:Log.AppendText("`r`n" + ("-" * 60) + "`r`n")
    Update-Log "Scanning for ROMs (Filtered Sync)..." $true

    # 2. Discovery with Filter
    $allFiles = [System.IO.Directory]::GetFiles($global:SourcePath, "*.*", [System.IO.SearchOption]::AllDirectories) | Where-Object { 
        $ext = [System.IO.Path]::GetExtension($_).ToLower()
        ($global:RomExtensions -contains $ext) -and ($ext -ne ".png" -or $_ -match "pico-8") 
    }

    if ($allFiles.Count -eq 0) {
        Update-Log "No matching ROMs found in Master folder." $true
        $global:btnPowerClone.Enabled = $true # Re-enable on fail
        return
    }

    # 3. Hand-off to Master Engine
    Start-FileTransfer -FileList $allFiles -Title "UNIVERSAL SYNC"
}

function Invoke-PowerClone {
    if (-not (Test-PathsReady "Power Clone")) { return }
    Reset-ActionDisplay

    # --- CHOICE A: FOLDERS ONLY ---
    if ($global:rbFoldersOnly.Checked) {
        $global:Log.AppendText("`r`n" + ("=" * 60) + "`r`n")
        Update-Log "CLONING DIRECTORY STRUCTURE ONLY..." $true
        robocopy $global:SourcePath $global:DestPath /E /XF * /R:1 /W:1 /NJH /NJS /NFL /NDL | Out-Null
        $folderCount = (Get-ChildItem $global:DestPath -Directory).Count
        Update-Log "CLONE COMPLETE: $folderCount System Folders verified/created." $true
        $global:ProgressBar.Value = 100
        $global:ProgressBar.Visible = $false
        Invoke-Audit $global:DestPath "Target_Audit.txt"
        return
    }

    # --- CHOICE B: ROMS ONLY (No System Folders) ---
    elseif ($global:rbRomsOnly.Checked) {
        $global:Log.AppendText("`r`n" + ("=" * 60) + "`r`n")
        Update-Log "SCANNING FOR ROMS ONLY (Excluding Systems)..." $true
        
        # Define what we consider "System" to exclude from the ROM scan
        $excludeFolders = "(\\bios\\|\\ports\\|\\tools\\|\\.system\\|\\themes\\|\\cheats\\)"

        $romFiles = [System.IO.Directory]::GetFiles($global:SourcePath, "*.*", [System.IO.SearchOption]::AllDirectories) | Where-Object {
            $ext = [System.IO.Path]::GetExtension($_).ToLower()
            $isRom = $global:RomExtensions -contains $ext
            $isNotSystem = $_ -notmatch $excludeFolders
            
            # Logic: Must be a ROM extension AND not in a system folder
            $isRom -and $isNotSystem
        }

        if ($romFiles.Count -gt 0) {
            Start-FileTransfer -FileList $romFiles -Title "ROMS ONLY CLONE"
            return
        }
        else {
            Update-Log "No ROMs found outside of system folders." $true
        }
    }

    # --- CHOICE C: SYSTEM FOLDERS ONLY ---
    elseif ($global:rbSystemOnly.Checked) {
        $global:Log.AppendText("`r`n" + ("=" * 60) + "`r`n")
        Update-Log "CLONING SYSTEM FOLDERS (BIOS, Ports, Tools)..." $true
        $systemFolders = @("bios", "ports", "tools")
        $systemFiles = @()
        foreach ($folder in $systemFolders) {
            $path = Join-Path $global:SourcePath $folder
            if (Test-Path $path) {
                $systemFiles += [System.IO.Directory]::GetFiles($path, "*.*", [System.IO.SearchOption]::AllDirectories)
            }
        }
        if ($systemFiles.Count -gt 0) {
            Start-FileTransfer -FileList $systemFiles -Title "SYSTEM FOLDER CLONE"
            return
        }
        else {
            Update-Log "No system files found." $true
        }
    }

    # --- CHOICE D: EVERYTHING (Brute Force) ---
    else {
        $global:Log.AppendText("`r`n" + ("=" * 60) + "`r`n")
        Update-Log "SCANNING ALL FILES (Full System Mirror)..." $true
        $allFiles = [System.IO.Directory]::GetFiles($global:SourcePath, "*.*", [System.IO.SearchOption]::AllDirectories)
        if ($allFiles.Count -gt 0) {
            Start-FileTransfer -FileList $allFiles -Title "POWER CLONE (FULL)"
            return
        }
        else {
            Update-Log "Master folder is empty!" $true
        }
    }
}

# Function 4.9: Advanced Mirror/Cleanup Logic
function Invoke-Cleanup {
    # Dynamically pass $true if Delete Empty is checked, telling the checker to ignore Master
    if (-not (Test-PathsReady "Cleanup Mode" $global:rbDeleteEmpty.Checked)) { return }

    # --- 1. Safety Confirmation Based on Selection ---
    if ($global:rbMirrSource.Checked) {
        $msg = "MIRROR MODE: This will PERMANENTLY DELETE files and FOLDERS on the TARGET (SD) that do not exist on the MASTER (PC).`n`nProceed?"
    }
    else {
        $msg = "DELETE EMPTY FOLDERS: This will scan the TARGET (SD) and permanently remove all empty directories.`n`nProceed?"
    }

    if ([System.Windows.Forms.MessageBox]::Show($msg, "Critical Warning", [System.Windows.Forms.MessageBoxButtons]::YesNo,
     [System.Windows.Forms.MessageBoxIcon]::Warning) -ne [System.Windows.Forms.DialogResult]::Yes) { 
        return 
    }

    # Reset the abort trigger & text color
    $global:AbortSync = $false 
    $global:lblAction.ForeColor = [System.Drawing.Color]::Black 

    # 2. Reset UI for Action
    $global:btnAbort.Enabled = $true
    $global:Log.AppendText("`r`n" + ("!" * $w) + "`r`n")
    
    # ----------------------------------------------------
    # MODE 1: DELETE EMPTY FOLDERS LOGIC
    # ----------------------------------------------------
    if ($global:rbDeleteEmpty.Checked) {
        Update-Log "STARTING PURGE OF EMPTY FOLDERS..." $true
        
        # Get all subdirectories sorted by depth (deepest first so nested empty folders delete correctly)
        $targetDirs = Get-ChildItem $global:DestPath -Recurse -Directory | 
        Sort-Object { $_.FullName.Length } -Descending

        $total = $targetDirs.Count
        $current = 0

        foreach ($dir in $targetDirs) {
            if ($global:AbortSync) {
                Update-Log "CLEANUP HALTED BY USER." $true
                break
            }

            # Check if the directory contains any files or folders
            if ((Get-ChildItem $dir.FullName -Force).Count -eq 0) {
                Update-Log "REMOVING EMPTY FOLDER: $($dir.Name)"
                Remove-Item $dir.FullName -Force -ErrorAction SilentlyContinue
            }

            # UI Keep-Alive and Progress
            [System.Windows.Forms.Application]::DoEvents()
            $current++
            if ($total -gt 0) {
                $percent = [int](($current / $total) * 100)
                $global:ProgressBar.Value = $percent
                $global:ProgressBar.Visible = $true
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    # ----------------------------------------------------
    # MODE 2: ORIGINAL MIRROR LOGIC
    # ----------------------------------------------------
    else {
        Update-Log "STARTING CLEANUP (MIRROR MODE)..." $true

        # --- THE GHOST PURGE ---
        $masterFolderNames = Get-ChildItem $global:SourcePath -Directory | Select-Object -ExpandProperty Name
        $targetFolders = Get-ChildItem $global:DestPath -Directory
        foreach ($tFolder in $targetFolders) {
            if ($masterFolderNames -notcontains $tFolder.Name) {
                Update-Log "PURGING GHOST FOLDER: $($tFolder.Name)"
                Remove-Item $tFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        # Execution (Folder by Folder Mirroring)
        $masterDirs = Get-ChildItem $global:SourcePath -Directory
        $total = $masterDirs.Count
        $current = 0

        foreach ($dir in $masterDirs) {
            if ($global:AbortSync) {
                Update-Log "CLEANUP HALTED BY USER." $true
                break
            }

            $targetPath = Join-Path $global:DestPath $dir.Name
            if ([System.IO.Directory]::Exists($targetPath)) {
                # ← CHANGED THIS LINE From Test-Paths
                Update-Log "Mirroring: $($dir.Name)..."
                robocopy $dir.FullName $targetPath /MIR /R:1 /W:1 /NP /NFL /NDL /NJH /NJS /MT:8 | Out-Null
            }

            [System.Windows.Forms.Application]::DoEvents()
            $current++
            $percent = [int](($current / $total) * 100)
            $global:ProgressBar.Value = $percent
            $global:ProgressBar.Visible = $true
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    # 4. Finalize
    $global:ProgressBar.Visible = $false
    $global:btnAbort.Enabled = $false

    if ($global:AbortSync) {
        Update-Log "!!! CLEANUP ABORTED BY USER !!!" $true
        $global:lblAction.Text = "ABORTED: Process Halted."
        $global:lblAction.ForeColor = [System.Drawing.Color]::Red
    }
    else {
        # Check what finished to give the correct log/label message
        if ($global:rbDeleteEmpty.Checked) {
            Update-Log "CLEANUP FINISHED. All empty folders removed." $true
            $global:lblAction.Text = "Purge Complete."
        }
        else {
            Update-Log "CLEANUP FINISHED. Target is now a perfect 1:1 mirror." $true
            $global:lblAction.Text = "Clean Complete."
        }
        $global:lblAction.ForeColor = [System.Drawing.Color]::Black 
        Invoke-Audit $global:DestPath "Target_Audit.txt" 
    }
    
    $global:Log.AppendText(("!" * $w) + "`r`n")
}

# --- Function 4.10: G350 to ArkOS Smart Migration ---
function Invoke-G350Src {
    # 1. PATH ENFORCEMENT: Enforce both Master and Target paths ($false = not destination-only)
    if (-not (Test-PathsReady "G350 Migration" $false)) { return }
    
    Reset-ActionDisplay
    Update-Log "G350 SMART MIGRATION: Building File List..." $true
    
    # 2. Build the "Smart List" (Filters based on your 130-system DB)
    $migrationList = @()
    foreach ($sys in $global:SystemDatabase) {
        # Check G350_Src folder name; fall back to primary folder name if blank
        $srcName = if ($sys.G350_Src -ne "---") { $sys.G350_Src } else { $sys.Folder }
        $srcFull = Join-Path $global:SourcePath $srcName
        
        if ([System.IO.Directory]::Exists($srcFull)) {
            # Recursively collect all existing ROM files inside this valid system folder
            $files = Get-ChildItem $srcFull -File -Recurse -ErrorAction SilentlyContinue
            if ($files) {
                $migrationList += $files.FullName
            }
        }
    }
    
    # 3. Execution Hand-Off
    if ($migrationList.Count -gt 0) {
        # Sends your filtered file array straight to your robust universal transfer UI
        Start-FileTransfer -FileList $migrationList -Title "G350 TO ARKOS MIGRATION"
    }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "No matching G350 folders containing ROM files were found inside the selected Master path.", 
            "Migration Empty", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
}

# Function 4.11: Total UI & Variable Reset
function Reset-ActionDisplay {
    # 1. Reset the "Kill Switch"
    $global:AbortSync = $false
    
    # 2. Reset the Status Ribbon
    $global:lblAction.ForeColor = [System.Drawing.Color]::Black
    $global:lblAction.Text = "Ready..."
    
    # 3. Clean the Progress Bar
    $global:ProgressBar.Value = 0
    $global:ProgressBar.Visible = $false
    
    # 4. Process pending UI updates
    [System.Windows.Forms.Application]::DoEvents()
}

function Reset-AllSelections {
    $global:SourcePath = ""
    $global:DestPath = ""
    $global:lblStatus.Text = "Ready"
    $global:lblAction.Text = "All selections cleared."
    $global:lblAction.Visible = $false
    $global:Log.Clear()
    $global:ProgressBar.Value = 0
    $global:ProgressBar.Visible = $false
    
    # Disable Action Buttons
    $global:btnSync.Enabled = $false
    $global:btnPowerClone.Enabled = $false
    $global:btnCleanup.Enabled = $false
    $global:btnGenArk.Enabled = $false
    $global:btnGenDark.Enabled = $false
    $global:btnGenDarkRE.Enabled = $false
    $global:btnGenG350.Enabled = $false
    
    Update-Log "SYSTEM RESET COMPLETE."
}

# Function 4.12: Emergency Stop
function Invoke-Abort {
    $global:AbortSync = $true
    Update-Log "!!! STOP SIGNAL SENT: ABORTING CURRENT TASK !!!" $true
}

# Function 4.13: Help
function Show-HelpManual {
    $global:Log.Clear()

    # In your Startup or Help function:
    $global:Log.AppendText($HeaderArt + "`r`n`r`n")

    # 2. Add 2 blank lines for "Breathing Room"
    $global:Log.AppendText("`r`n`r`n") 

    $hr = "=" * $script:ReportWidth
    $global:Log.AppendText("$hr`r`n")   
    $global:Log.AppendText("                            *****ARKOS UTILITY - QUICK REFERENCE GUIDE*****`r`n")
    $global:Log.AppendText("$hr`r`n`r`n")

    
    $global:Log.AppendText("    ***** Select a TARGET, or MASTER and TARGET folders to activate the functional buttons. *****`r`n`r`n")
    $HelpItems = @(
        @{ Cmd = "[ Sel MASTER ]" ; Desc = "Sets the path to your Master PC 'Gold Standard' ROM collection folder." },
        @{ Cmd = "[ Sel TARGET ]" ; Desc = "Sets the path to your Target SD Card, directory, or handheld device folder." },
        @{ Cmd = "[ UNIV SYNC ]"  ; Desc = "SAFE. Copies only missing files from Master to Target based on extension." },
        @{ Cmd = "[ CLEANUP ]"    ; Desc = "Cleans the TARGET based on the selected Cleanup Mode.  Master is unchanged." },
        @{ Cmd = " (Mirr Source)" ; Desc = "Removes ._ files, empty folders, and junk to match the Target to the Master." },
        @{ Cmd = " (Delete Empty)"; Desc = "Removes ALL empty folders on the Target, ignores the Master if selected." },
        @{ Cmd = "[ PWR CLONE ]"  ; Desc = "BRUTE FORCE. Options: Folders Only, ROMs Only, System Only, or EVERYTHING." },
        @{ Cmd = " (System Only)" ; Desc = "Clones BIOS, Ports, Themes, and Tools folders with sub-folders only." },
        @{ Cmd = " (ROMs Only)"   ; Desc = "Clones ROMs only.  Geared for SD2 setups (Skips BIOS, Ports, and Tools)." },
        @{ Cmd = "[ SYS AUDIT ]"  ; Desc = "Generates a pipe-separated report (.txt) for review or (.csv) for import." },
        @{ Cmd = "[ ABORT ]"      ; Desc = "Halts/Pauses the current operation. Re-click the operation to resume." },
        @{ Cmd = "[ GEN xxxOS ]"  ; Desc = "Creates the specific folder structure for ArkOS / dArkOS / dArkOS-RE." },
        @{ Cmd = "[ G350 Src  ]"  ; Desc = "Uses a stock G350 SD card as the source to append a clean ArkOS structure." },
        @{ Cmd = "[ G350 Src. ]"  ; Desc = "Creates ONLY the folders with ROMs if synched to an empty target folder." }
    )

    foreach ($item in $HelpItems) {
        $row = "{0,-15} : {1}" -f $item.Cmd, $item.Desc
        $global:Log.AppendText("$row`r`n")
    }
    
    $global:Log.AppendText("`r`n$hr`r`n")
    $global:Log.AppendText("       **This tool is continually under development.  Use with CAUTION, at your own risk.**`r`n")
    $global:Log.AppendText("$hr")

}

# 4.14 Check4Update Set your current version
function Test-Update {
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send("1.1.1.1", 1000)
        if ($reply.Status -ne "Success") { return }
    }
    catch { return }

    try {
        $apiUrl = "https://api.github.com/repos/$($global:RepoOwner)/$($global:RepoName)/releases/latest"
        $userAgent = "ArkOS-Utility-Script"
        
        $release = Invoke-RestMethod -Uri $apiUrl -Method Get -UserAgent $userAgent -ContentType "application/json" -ErrorAction Stop 
        
        if ($null -eq $release) { return } 
        
        $rawTagName = $release.tag_name
        
        $latestStr = $rawTagName -replace '[^0-9.]', '' 
        $currentStr = $global:Cvers -replace '[^0-9.]', '' 
        
        if ([string]::IsNullOrWhiteSpace($latestStr) -or [string]::IsNullOrWhiteSpace($currentStr)) { 
            return 
        } 
        
        if ([version]$latestStr -gt [version]$currentStr) { 
            # Turn the GitHub link CYAN to indicate an update is available
            $global:lblGitHub.LinkColor = [System.Drawing.Color]::Purple
            
            Add-Type -AssemblyName System.Windows.Forms 
            Add-Type -AssemblyName System.Drawing
            
            $downloadUrl = "https://github.com/$($global:RepoOwner)/$($global:RepoName)/releases/latest"
            
            # Create a custom form with clickable link
            $form = New-Object System.Windows.Forms.Form
            $form.Text = "Update Available"
            $form.Width = 450
            $form.Height = 210
            $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
            $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
            $form.MaximizeBox = $false
            $form.MinimizeBox = $false
            
            # Add title label
            $titleLabel = New-Object System.Windows.Forms.Label
            $titleLabel.Text = "A new version of $($global:ScriptTitle) ($rawTagName) is available!"
            $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
            $titleLabel.Width = 410
            $titleLabel.Height = 30
            $titleLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
            $form.Controls.Add($titleLabel)
            
            # Add message with clickable link
            $messagePanel = New-Object System.Windows.Forms.Panel
            $messagePanel.Location = New-Object System.Drawing.Point(20, 60)
            $messagePanel.Width = 410
            $messagePanel.Height = 50
            $messagePanel.AutoSize = $true
            
            # "To Download: " text
            $downloadLabel = New-Object System.Windows.Forms.Label
            $downloadLabel.Text = "To Download: "
            $downloadLabel.Location = New-Object System.Drawing.Point(0, 0)
            $downloadLabel.Width = 100
            $downloadLabel.Height = 25
            $downloadLabel.AutoSize = $true
            $messagePanel.Controls.Add($downloadLabel)
            
            # "Click Here" link (keep dark blue)
            $clickLink = New-Object System.Windows.Forms.LinkLabel
            $clickLink.Text = "Click Here"
            $clickLink.Location = New-Object System.Drawing.Point(90, 0)
            $clickLink.Width = 100
            $clickLink.Height = 25
            $clickLink.AutoSize = $true
            $clickLink.LinkColor = [System.Drawing.Color]::Blue
            $clickLink.add_LinkClicked({
                    [System.Diagnostics.Process]::Start($downloadUrl)
                })
            $messagePanel.Controls.Add($clickLink)
            
            $form.Controls.Add($messagePanel)
            
            # Add OK button
            $okButton = New-Object System.Windows.Forms.Button
            $okButton.Text = "OK"
            $okButton.Location = New-Object System.Drawing.Point(185, 115)
            $okButton.Width = 80
            $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Controls.Add($okButton)
            $form.AcceptButton = $okButton
            
            # Add "Check for Updates" link at bottom left (blue reminder)
            $updateLink = New-Object System.Windows.Forms.LinkLabel
            $updateLink.Text = "Check for Updates"
            $updateLink.Location = New-Object System.Drawing.Point(20, 175)
            $updateLink.Width = 150
            $updateLink.Height = 25
            $updateLink.AutoSize = $true
            $updateLink.LinkColor = [System.Drawing.Color]::Blue
            $updateLink.add_LinkClicked({
                    [System.Diagnostics.Process]::Start($downloadUrl)
                })
            $form.Controls.Add($updateLink)
            
            $form.ShowDialog() | Out-Null
        }
        else {
            # User is on the latest version - turn the GitHub link back to GRAY
            $global:lblGitHub.LinkColor = [System.Drawing.Color]::Gray
        }
    } 
    catch { 
        Write-Debug "Update check failed: $($_.Exception.Message)" 
    } 
}

# ============================================================
# Function 4.15: SD Card / USB Speed Benchmark (WinSAT)
# ============================================================
Add-Type -AssemblyName Microsoft.VisualBasic
function Invoke-SdBenchmark {
    # --- Admin check ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).
            IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Update-Log "WARNING: Not running as Administrator. WinSAT may fail."
}

    $w = $script:ReportWidth

    # --- Header in log ---
    $global:Log.AppendText("`r`n" + ("=" * $w) + "`r`n")
    Update-Log "INITIATING SD CARD SPEED TEST" $true

    # --- User input via pop-ups ---
    $cardModel = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter Card / Device Model`n(e.g. Lexar Silver 64GB, Samsung EVO 256GB)",
        "SD Card Benchmark",
        "")

    if ([string]::IsNullOrWhiteSpace($cardModel)) {
        Update-Log "Test cancelled by user."
        return
    }

    $driveInput = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter Drive Letter (e.g. F: or G:)",
        "SD Card Benchmark",
        "")

    if ([string]::IsNullOrWhiteSpace($driveInput)) {
        Update-Log "Test cancelled by user."
        return
    }

    $driveLetter = ($driveInput -replace '[:\\]', '').ToUpper()
    if ($driveLetter -notmatch '^[A-Z]$') {
        Update-Log "Invalid drive letter. Test aborted."
        return
    }

    $drivePath = "${driveLetter}:"
    if (-not (Test-Path $drivePath)) {
        Update-Log "Drive $drivePath not found or not accessible. Test aborted."
        return
    }

    Update-Log "Card Model : $cardModel"
    Update-Log "Drive      : $drivePath"
    Update-Log "Running WinSAT (this usually takes 15-90 seconds)..."
    [System.Windows.Forms.Application]::DoEvents()

    # --- Run WinSAT ---
    try {
        $rawOutput = & winsat.exe disk -drive $driveLetter 2>&1
    }
    catch {
        Update-Log "ERROR running winsat: $_"
        return
    }

    Update-Log "WinSAT finished. Parsing results..."

    # --- Parse results ---
    $seqRead = $null; $seqReadScore = $null
    $seqWrite = $null; $seqWriteScore = $null
    $ranRead = $null; $ranReadScore = $null
    $totalRunTime = $null
    $latSeqWrite = $null; $lat95 = $null; $latMax = $null; $latRanWrite = $null

    foreach ($line in $rawOutput) {
        if ($line -match 'Disk\s+Sequential\s+64\.0\s+Read\s+([\d\.]+)\s+MB/s\s+([\d\.]+)') {
            $seqRead = [double]$Matches[1]; $seqReadScore = [double]$Matches[2]
        }
        elseif ($line -match 'Disk\s+Sequential\s+64\.0\s+Write\s+([\d\.]+)\s+MB/s\s+([\d\.]+)') {
            $seqWrite = [double]$Matches[1]; $seqWriteScore = [double]$Matches[2]
        }
        elseif ($line -match 'Disk\s+Random\s+16\.0\s+Read\s+([\d\.]+)\s+MB/s\s+([\d\.]+)') {
            $ranRead = [double]$Matches[1]; $ranReadScore = [double]$Matches[2]
        }
        elseif ($line -match 'Total Run Time\s+(\d{2}:\d{2}:\d{2}\.\d{2})') {
            $totalRunTime = $Matches[1]
        }
        elseif ($line -match 'Average Read Time with Sequential Writes\s+([\d\.]+)\s+ms\s+([\d\.]+)') {
            $latSeqWrite = [double]$Matches[2]
        }
        elseif ($line -match 'Latency:\s+95th Percentile\s+([\d\.]+)\s+ms\s+([\d\.]+)') {
            $lat95 = [double]$Matches[2]
        }
        elseif ($line -match 'Latency:\s+Maximum\s+([\d\.]+)\s+ms\s+([\d\.]+)') {
            $latMax = [double]$Matches[2]
        }
        elseif ($line -match 'Average Read Time with Random Writes\s+([\d\.]+)\s+ms\s+([\d\.]+)') {
            $latRanWrite = [double]$Matches[2]
        }
    }

    # --- Averages ---
    $speedScores   = @($seqReadScore, $seqWriteScore, $ranReadScore) | Where-Object { $_ -ne $null }
    $latencyScores = @($latSeqWrite, $lat95, $latMax, $latRanWrite) | Where-Object { $_ -ne $null }

    $speedAvg    = if ($speedScores.Count)   { [math]::Round(($speedScores   | Measure-Object -Average).Average, 1) } else { $null }
    $latencyAvg  = if ($latencyScores.Count) { [math]::Round(($latencyScores | Measure-Object -Average).Average, 1) } else { $null }
    $overallAvg  = if (($speedScores + $latencyScores).Count) {
        [math]::Round((($speedScores + $latencyScores) | Measure-Object -Average).Average, 1)
    } else { $null }

    # --- Build report ---
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $report = @()
    $report += ("=" * $w)
    $report += "  SD CARD BENCHMARK REPORT"
    $report += ("=" * $w)
    $report += "Date/Time     : $timestamp"
    $report += "Card Model    : $cardModel"
    $report += "Drive Letter  : $driveLetter`:"
    $report += "Total Run Time: $totalRunTime"
    $report += ("-" * $w)
    $report += ""
    $report += ('  Sequential 64K Read  : {0:N2} MB/s   (Score {1})' -f $seqRead,  $seqReadScore)
    $report += ('  Sequential 64K Write : {0:N2} MB/s   (Score {1})' -f $seqWrite, $seqWriteScore)
    $report += ('  Random 16K Read      : {0:N2} MB/s   (Score {1})' -f $ranRead,  $ranReadScore)
    $report += ('  Speed Average        : {0}' -f $speedAvg)
    $report += ""
    $report += ('  Latency Average      : {0}' -f $latencyAvg)
    $report += ('  Overall Average      : {0}' -f $overallAvg)
    $report += ""
    $report += ("-" * $w)
    $report += "Notes: Higher MB/s and Score is better. Scores are WinSAT 1.0-9.9 scale."
    $report += "Rating: 7.0+ = Excellent | 6.0-6.9 = Good | 5.0-5.9 = Average | Below 5.0 = Slow"
    $report += ("=" * $w)

    # --- Show in log window ---
    foreach ($line in $report) {
        $global:Log.AppendText("$line`r`n")
    }
    $global:Log.AppendText("`r`n")

    # --- Save files (respect toggles) ---
    $safeName = ($cardModel -replace '[\\/:*?"<>|]', '_').Trim()

    if ($script:GenerateSdTxt) {
        $txtPath = Join-Path $PSScriptRoot ("SDCard_{0}_{1:yyyyMMdd_HHmmss}.txt" -f $safeName, (Get-Date))
        $report | Out-File -FilePath $txtPath -Encoding utf8 -Force
        Update-Log "TEXT REPORT SAVED: $txtPath"
    }

    if ($script:GenerateSdCsv) {
        $CsvPath = Join-Path $PSScriptRoot "SDCard_Benchmark.csv"
        $csvHeader = "Date,CardModel,DriveLetter,SeqRead_MBps,SeqRead_Score,SeqWrite_MBps,SeqWrite_Score,RanRead_MBps,RanRead_Score,SpeedAvg,LatencyAvg,OverallAvg,TotalRunTime"

        $csvRow = '"{0}","{1}","{2}",{3},{4},{5},{6},{7},{8},{9},{10},{11},"{12}"' -f `
            $timestamp, $cardModel, "$driveLetter`:", `
            $seqRead, $seqReadScore, $seqWrite, $seqWriteScore, $ranRead, $ranReadScore, `
            $speedAvg, $latencyAvg, $overallAvg, $totalRunTime

        if (-not (Test-Path $CsvPath)) {
            $csvHeader | Out-File -FilePath $CsvPath -Encoding utf8
        }
        Add-Content -Path $CsvPath -Value $csvRow -Encoding utf8
        Update-Log "CSV RESULTS APPENDED: $CsvPath"
    }

    Update-Log "SD CARD SPEED TEST COMPLETE"
}

# ==============================================================================
# SECTION 5: THE NERVOUS SYSTEM (Event Handlers)
# ==============================================================================

# --- 5.1: PATH SELECTION EVENTS ---
# Links the PC and SD folder pickers
$global:btnMaster.Add_Click({ Reset-ActionDisplay; Set-Path "Master" })
$global:btnSD.Add_Click({ Reset-ActionDisplay; Set-Path "Target" })

# --- 5.2: CORE ACTION EVENTS ---
# Links Sync, Clone, and Cleanup logic

# 1. Sync Button
$global:btnSync.Add_Click({
        try {
            Set-UIState -IsWorking $true
            Start-Sleep -Milliseconds 100
            Reset-ActionDisplay
            Invoke-UniversalSync
        }
        finally {
            Set-UIState -IsWorking $false
        }
    })

# 2. PowerClone Button
$global:btnPowerClone.Add_Click({
        try {
            Set-UIState -IsWorking $true
            Start-Sleep -Milliseconds 100
            Reset-ActionDisplay
            Invoke-PowerClone
        }
        finally {
            Set-UIState -IsWorking $false
        }
    })

# 3. Cleanup Button
$global:btnCleanup.Add_Click({
        try {
            Set-UIState -IsWorking $true
            Start-Sleep -Milliseconds 100
            Reset-ActionDisplay
            Invoke-Cleanup
        }
        finally {
            Set-UIState -IsWorking $false
        }
    })

# --- 5.3: GENERATION & FIX EVENTS ---
# Links the Green/Yellow OS buttons
$global:btnGenArk.Add_Click({
        try {
            Set-UIState -IsWorking $true
            Start-Sleep -Milliseconds 100 # The "Sighted" Pause
            Reset-ActionDisplay
            Invoke-Generation "ArkOS"
        }
        finally {
            Set-UIState -IsWorking $false
        }
    })

$global:btnGenDark.Add_Click({
        try {
            Set-UIState -IsWorking $true
            Start-Sleep -Milliseconds 100
            Reset-ActionDisplay
            Invoke-Generation "dArkOS"
        }
        finally {
            Set-UIState -IsWorking $false
        }
    })

$global:btnGenDarkRE.Add_Click({
        try {
            Set-UIState -IsWorking $true
            Start-Sleep -Milliseconds 100
            Reset-ActionDisplay
            Invoke-Generation "dArkOSRE"
        }
        finally {
            Set-UIState -IsWorking $false
        }
    })

$global:btnGenG350.Add_Click({
        try {
            Set-UIState -IsWorking $true
            Start-Sleep -Milliseconds 100
            Reset-ActionDisplay
        
            # FIX: Call the actual smart ROM migration function, not the folder generator!
            Invoke-G350Src
        } 
        finally {
            Set-UIState -IsWorking $false
        }
    })

    $global:chkToggleAtxt.Add_CheckedChanged({
    $script:GenerateAuditTxt = $global:chkToggleAtxt.Checked
})

$global:chkToggleAcsv.Add_CheckedChanged({
    $script:GenerateAuditCsv = $global:chkToggleAcsv.Checked
})

# --- 5.4: UTILITY & SAFETY EVENTS ---
# Audit now handles the file generation logic
# Update this line to match your new name!

# Ref: Function 4.5.1: function Invoke-FullAudit
$global:btnAudit.Add_Click({ Invoke-FullAudit })

$global:btnAbort.Add_Click({
        $global:AbortSync = $true
        $global:lblAction.Text = "ABORTING... PLEASE WAIT"
        $global:lblAction.ForeColor = [System.Drawing.Color]::Red

        # This "kills" the actual Robocopy engine immediately
        Stop-Process -Name "robocopy" -Force -ErrorAction SilentlyContinue
    
        Update-Log "!!! ABORT COMMAND ISSUED !!!" $true
    })

# WinSAT SPEED TEST Event handlers
$global:btnSDSpeed.Add_Click({
    Invoke-SdBenchmark
})
    $global:chkToggleStxt.Add_CheckedChanged({
    $script:GenerateSdTxt = $global:chkToggleStxt.Checked
})

$global:chkToggleScsv.Add_CheckedChanged({
    $script:GenerateSdCsv = $global:chkToggleScsv.Checked
})

# This is now your "Master Reset"
$global:btnReset.Add_Click({   
        Reset-AllSelections  # Clears the folder paths
        $Log.Clear()         # Wipes the text window
        $global:lblAction.Text = "System Reset. Ready for new selection."
    
        # Optional: Put the Audit button back to sleep until a new path is picked
        $global:btnAudit.Enabled = $false
        $global:btnAudit.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#e0e0e0")
    })


# --- 5.4: GITHUB DYNAMIC LINK (Cleaned) ---
$global:lblGitHub.add_LinkClicked({
        # We use the Global RepoName we defined in Section 0
        $url = "https://github.com/$($global:RepoOwner)/$($global:RepoName)/releases/latest"
    
        # Start the browser
        Start-Process $url
    })


# --- 5.5: THE NEW HELP SYSTEM ---
# 1. Clicking the [?] in the header now prints the Manual to the Log Window
$global:lblHelpHint.add_LinkClicked({ Show-HelpManual })

# 2. (Optional) If you want a button to trigger the manual too:
# $global:btnHelp.Add_Click({ Show-HelpManual })


# ==============================================================================
# SECTION 6: THE ASSEMBLY & LAUNCH
# ==============================================================================

# --- 6.1: FORM CONTROL AGGREGATION ---
# This physically adds every button, label, and box to the window.
# Order here doesn't affect logic, but it affects "Tab" order for keyboards.
$global:Form.Controls.AddRange(@(
        $global:lblHelpHint
        $global:btnMaster, 
        $global:btnSD, 
        $global:lblStatus, 
        $global:btnReset,
        $global:btnSync, 
        $global:btnAbort, 
        $global:btnCleanup,
        $global:gbCleanMode,
        $global:btnGenArk, 
        $global:btnGenDark, 
        $global:btnGenDarkRE, 
        $global:btnGenG350,
        $global:btnPowerClone,
        $global:gbCloneMode, 
        $global:btnAudit,
        $global:gbToggleAudit,
        $global:btnSDSpeed,
        $global:gbToggleSDSpeed,
        $global:lblAction, 
        $global:ProgressBar, 
        $global:Log, 
        $global:lblGitHub,
        $global:lblSupportText,
        $global:lblSupport
        
    ))

# --- 6.2: FINAL UI TWEAKS ---
# Ensures the Log window starts at the top and the focus is neutral
Reset-AllSelections # <--- Forces a clean start every time!
$global:Log.SelectionStart = 0
$global:Log.SelectionStart = 0
$global:Log.DeselectAll()

# --- 6.3: THE FINAL LAUNCHER ---

# Trigger the update check right before showing the UI
Test-Update

# This is the very last line of the script. It opens the window and 
# keeps the script running until you close the X.
$global:Form.ShowDialog()

# --- END OF SCRIPT ---
# Cleaning up memory after the form closes (optional but good practice)
$global:Form.add_FormClosing({
        $global:UITimer.Stop()
        $global:UITimer.Dispose()
    })
$global:Form.Dispose()
