# PASO 1: En tu PC, crea el archivo con la codificación correcta
$content = @'
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

$sourcePath = Get-ChildItem $extractPath -Directory | Select-Object -First 1
if (-not $sourcePath) { $sourcePath = $extractPath }

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

# RESUMEN FINAL
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ✅ ¡INSTALACIÓN COMPLETADA!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[i] Archivos instalados en: $gamePath" -ForegroundColor Gray
Write-Host ""
Write-Host "INSTRUCCIONES:" -ForegroundColor Yellow
Write-Host "  1. Ejecuta VBS.cmd (una sola vez, requiere reinicio)" -ForegroundColor White
Write-Host "  2. Ejecuta HV-PlugNPlay.bat (ANTES de jugar)" -ForegroundColor White
Write-Host "  3. Ejecuta el juego desde el acceso directo" -ForegroundColor White

Read-Host "`nPresiona ENTER para salir"
'@

# Guardar con codificación UTF-8 con BOM (la que entiende PowerShell)
$content | Out-File -FilePath "$env:USERPROFILE\Desktop\AC-BlackFlag-AutoSetup.ps1" -Encoding UTF8

# Subir a GitHub (desde PowerShell)
Write-Host "Subiendo script a GitHub..." -ForegroundColor Cyan

# Usar GitHub CLI si está instalado
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh auth status
    gh repo clone teflay/AC-BlackFlag "$env:TEMP\AC-Repo"
    Copy-Item "$env:USERPROFILE\Desktop\AC-BlackFlag-AutoSetup.ps1" "$env:TEMP\AC-Repo\" -Force
    cd "$env:TEMP\AC-Repo"
    git add AC-BlackFlag-AutoSetup.ps1
    git commit -m "Fix encoding for AutoSetup script"
    git push
    cd ..
    Remove-Item "$env:TEMP\AC-Repo" -Recurse -Force
    Write-Host "[✓] Script actualizado en GitHub" -ForegroundColor Green
} else {
    Write-Host "[!] GitHub CLI no instalado. Sube manualmente el archivo desde:" -ForegroundColor Yellow
    Write-Host "    $env:USERPROFILE\Desktop\AC-BlackFlag-AutoSetup.ps1" -ForegroundColor White
}