$RepoBase = "https://raw.githubusercontent.com/teflay/AC-BlackFlag/refs/heads/main"
$RepoRelease = "https://github.com/teflay/AC-BlackFlag/releases/download/1.0"

$Urls = @{
    "VBS.cmd" = "$RepoBase/VBS.cmd"
    "HV-PlugNPlay.bat" = "$RepoBase/HV-PlugNPlay.bat"
    "AC-BlackFlag-Files.zip" = "$RepoRelease/AC-BlackFlag-Files.zip"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AC Black Flag - Instalador Automatico" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Se necesitan permisos de administrador" -ForegroundColor Yellow
    Write-Host "[i] Reiniciando con privilegios elevados..." -ForegroundColor Cyan
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}
Write-Host "[OK] Ejecutando como administrador" -ForegroundColor Green

# ============================================================
# PASO 1: Buscar el juego usando libraryfolders.vdf
# ============================================================
Write-Host ""
Write-Host "[1] Buscando Assassin's Creed Black Flag..." -ForegroundColor Cyan

$vdfPath = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
$gamePath = $null

if (Test-Path $vdfPath) {
    Write-Host "[OK] Leyendo: $vdfPath" -ForegroundColor Gray
    $content = Get-Content $vdfPath -Raw
    $matches = [regex]::Matches($content, '"path"\s*"([^"]+)"')
    
    foreach ($match in $matches) {
        $basePath = $match.Groups[1].Value
        $testPath = Join-Path $basePath "steamapps\common\Assassin's Creed Black Flag Resynced"
        Write-Host "[DEBUG] Probando: $testPath" -ForegroundColor Gray
        if (Test-Path $testPath) {
            $gamePath = $testPath
            break
        }
    }
} else {
    Write-Host "[ERROR] No se encontro: $vdfPath" -ForegroundColor Red
}

if (-not $gamePath) {
    Write-Host "[!] No se encontro el juego en libraryfolders.vdf" -ForegroundColor Yellow
    $gamePath = Read-Host "Ingresa la ruta manualmente"
    if (-not (Test-Path $gamePath)) {
        Write-Host "[ERROR] Ruta invalida" -ForegroundColor Red
        Read-Host "Presiona ENTER para salir"
        exit 1
    }
}

Write-Host "[OK] Juego encontrado en: $gamePath" -ForegroundColor Green

# ============================================================
# PASO 2: Descargar VBS.cmd y HV-PlugNPlay.bat
# ============================================================
Write-Host ""
Write-Host "[2] Descargando VBS.cmd y HV-PlugNPlay.bat..." -ForegroundColor Cyan

foreach ($file in @("VBS.cmd", "HV-PlugNPlay.bat")) {
    $url = $Urls[$file]
    $dest = Join-Path $gamePath $file
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest
        Write-Host "  OK $file" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR $file: $_" -ForegroundColor Red
    }
}

# ============================================================
# PASO 3: Descargar y extraer el ZIP
# ============================================================
Write-Host ""
Write-Host "[3] Descargando archivos del juego (267 MB)..." -ForegroundColor Cyan

$zipPath = "$env:TEMP\AC-BlackFlag-Files.zip"
try {
    Invoke-WebRequest -Uri $Urls["AC-BlackFlag-Files.zip"] -OutFile $zipPath
    $size = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-Host "[OK] ZIP descargado ($size MB)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] No se pudo descargar: $_" -ForegroundColor Red
    Read-Host "Presiona ENTER para salir"
    exit 1
}

Write-Host ""
Write-Host "[4] Extrayendo archivos en el juego..." -ForegroundColor Cyan

try {
    Expand-Archive -Path $zipPath -DestinationPath $gamePath -Force
    Write-Host "[OK] Archivos extraidos en: $gamePath" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] No se pudo extraer: $_" -ForegroundColor Red
    Read-Host "Presiona ENTER para salir"
    exit 1
}

# Limpiar
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

# ============================================================
# RESUMEN FINAL
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  INSTALACION COMPLETADA" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[i] Todos los archivos estan en: $gamePath" -ForegroundColor Gray
Write-Host ""
Write-Host "INSTRUCCIONES:" -ForegroundColor Yellow
Write-Host "  1. Ejecuta VBS.cmd (una sola vez, requiere reinicio)" -ForegroundColor White
Write-Host "  2. Ejecuta HV-PlugNPlay.bat (ANTES de jugar)" -ForegroundColor White
Write-Host "  3. Ejecuta el juego" -ForegroundColor White

Read-Host "`nPresiona ENTER para salir"