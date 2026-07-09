# ============================================================
# AC-BlackFlag-AutoSetup.ps1
# ============================================================

$RepoRelease = "https://github.com/teflay/AC-BlackFlag/releases/download/v1.0"
$ZipUrl = "$RepoRelease/AC-BlackFlag-Files.zip"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AC Black Flag - Instalador Automático" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Se necesita permisos de administrador" -ForegroundColor Yellow
    Write-Host "[i] Reiniciando con privilegios elevados..." -ForegroundColor Cyan
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}
Write-Host "[✓] Ejecutando como administrador" -ForegroundColor Green

# Buscar el juego
Write-Host ""
Write-Host "[1] Buscando Assassin's Creed Black Flag..." -ForegroundColor Cyan

$gamePaths = @(
    "C:\Program Files (x86)\Steam\steamapps\common\Assassin's Creed Black Flag Resynced",
    "D:\SteamLibrary\steamapps\common\Assassin's Creed Black Flag Resynced",
    "E:\SteamLibrary\steamapps\common\Assassin's Creed Black Flag Resynced"
)

$gamePath = $null
foreach ($path in $gamePaths) {
    if (Test-Path $path) {
        $gamePath = $path
        break
    }
}

# Si no se encuentra, buscar en libraryfolders.vdf
if (-not $gamePath) {
    $vdfPath = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
    if (Test-Path $vdfPath) {
        $content = Get-Content $vdfPath -Raw
        $matches = [regex]::Matches($content, '"path"\s*"([^"]+)"')
        foreach ($match in $matches) {
            $basePath = $match.Groups[1].Value
            $testPath = Join-Path $basePath "steamapps\common\Assassin's Creed Black Flag Resynced"
            if (Test-Path $testPath) {
                $gamePath = $testPath
                break
            }
        }
    }
}

if (-not $gamePath) {
    Write-Host "[!] No se encontró el juego automáticamente" -ForegroundColor Yellow
    $gamePath = Read-Host "Ingresa la ruta manualmente"
    if (-not (Test-Path $gamePath)) {
        Write-Host "[✗] Ruta inválida" -ForegroundColor Red
        Read-Host "Presiona ENTER para salir"
        exit 1
    }
}

Write-Host "[✓] Juego encontrado en: $gamePath" -ForegroundColor Green

# Descargar el ZIP
Write-Host ""
Write-Host "[2] Descargando archivos del juego..." -ForegroundColor Cyan

$zipPath = "$env:TEMP\AC-BlackFlag-Files.zip"
try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zipPath
    $size = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-Host "[✓] ZIP descargado ($size MB)" -ForegroundColor Green
} catch {
    Write-Host "[✗] Error al descargar: $_" -ForegroundColor Red
    Read-Host "Presiona ENTER para salir"
    exit 1
}

# Extraer
Write-Host ""
Write-Host "[3] Extrayendo archivos..." -ForegroundColor Cyan

$extractPath = "$env:TEMP\AC-Files"
if (Test-Path $extractPath) {
    Remove-Item $extractPath -Recurse -Force
}
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

try {
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Host "[✓] Archivos extraídos" -ForegroundColor Green
} catch {
    Write-Host "[✗] Error al extraer: $_" -ForegroundColor Red
    Read-Host "Presiona ENTER para salir"
    exit 1
}

# Buscar la carpeta extraída
$sourcePath = Get-ChildItem $extractPath -Directory | Select-Object -First 1
if (-not $sourcePath) { $sourcePath = $extractPath }
Write-Host "[✓] Origen: $sourcePath" -ForegroundColor Gray

# Copiar archivos
Write-Host ""
Write-Host "[4] Instalando archivos en el juego..." -ForegroundColor Cyan

$copied = 0
Get-ChildItem -Path $sourcePath -Recurse -File | ForEach-Object {
    $dest = Join-Path $gamePath $_.Name
    Copy-Item $_.FullName $dest -Force -ErrorAction SilentlyContinue
    $copied++
    Write-Host "  ✓ $($_.Name)" -ForegroundColor Green
}
Write-Host "[✓] $copied archivos copiados" -ForegroundColor Green

# Acceso directo
Write-Host ""
Write-Host "[5] Creando acceso directo..." -ForegroundColor Cyan

$desktop = [Environment]::GetFolderPath("Desktop")
$wsh = New-Object -ComObject WScript.Shell
$shortcutPath = "$desktop\Assassins Creed Black Flag.lnk"

$exe = Get-ChildItem $gamePath -Filter "*.exe" -Recurse | 
       Where-Object { $_.Name -notmatch "drvloader|trial|_plus" } | 
       Sort-Object Length -Descending | Select-Object -First 1

if ($exe) {
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exe.FullName
    $shortcut.WorkingDirectory = $gamePath
    $shortcut.Save()
    Write-Host "[✓] Acceso directo creado: $shortcutPath" -ForegroundColor Green
} else {
    Write-Host "[!] No se encontró el .exe del juego" -ForegroundColor Yellow
}

# Descargar VBS.cmd y HV-PlugNPlay.bat (opcional)
Write-Host ""
Write-Host "[6] Descargando herramientas adicionales..." -ForegroundColor Cyan

$toolsPath = "$env:TEMP\HV-Tools"
New-Item -ItemType Directory -Path $toolsPath -Force | Out-Null

$tools = @(
    @{Name = "VBS.cmd"; Url = "https://raw.githubusercontent.com/teflay/AC-BlackFlag/main/VBS.cmd"},
    @{Name = "HV-PlugNPlay.bat"; Url = "https://raw.githubusercontent.com/teflay/AC-BlackFlag/main/HV-PlugNPlay.bat"}
)

foreach ($tool in $tools) {
    try {
        $dest = Join-Path $toolsPath $tool.Name
        Invoke-WebRequest -Uri $tool.Url -OutFile $dest
        Write-Host "  ✓ $($tool.Name)" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ $($tool.Name) - Error" -ForegroundColor Red
    }
}

# RESUMEN FINAL
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ✅ ¡INSTALACIÓN COMPLETADA!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[i] Archivos instalados en: $gamePath" -ForegroundColor Gray
Write-Host "[i] Herramientas descargadas en: $toolsPath" -ForegroundColor Gray
Write-Host ""
Write-Host "📌 INSTRUCCIONES:" -ForegroundColor Yellow
Write-Host "  1. Ejecuta VBS.cmd (una sola vez, requiere reinicio)" -ForegroundColor White
Write-Host "  2. Ejecuta HV-PlugNPlay.bat (ANTES de jugar)" -ForegroundColor White
Write-Host "  3. Ejecuta el juego desde el acceso directo" -ForegroundColor White
Write-Host ""

Read-Host "Presiona ENTER para salir"