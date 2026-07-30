<#
.SYNOPSIS
  Arranca la app en local con la configuración inyectada.

.DESCRIPTION
  `AppConfig` lee todo por `--dart-define` (ADR-10): NO hay archivos `.env`
  dentro del bundle. Sin la anon key la app arranca y muestra «Falta
  configuración» — es correcto, pero hace que lanzarla a mano sea fácil de
  equivocar.

  Este script toma la llave del `.env.local` del **frontend de Jurovia**, que ya
  la tiene y es el mismo proyecto de Supabase (`tfhhcokgrpagwwlctjtz`). Así la
  llave nunca se escribe dentro de este repositorio ni queda en el historial de
  la consola.

  La anon key es pública por diseño y está protegida por RLS. La `service_role`
  NUNCA entra aquí: esa vive solo en el backend de Railway.

.EXAMPLE
  .\tool\run_local.ps1
  .\tool\run_local.ps1 -Dispositivo emulator-5554
  .\tool\run_local.ps1 -Accion build
#>
param(
  [string]$Dispositivo = '',
  [ValidateSet('run', 'build')]
  [string]$Accion = 'run',
  [string]$EnvFrontend = 'C:\Users\freddyrs\Desktop\Legal_AI\Legal_AI_Frontend\.env.local'
)

$ErrorActionPreference = 'Stop'
$flutter = 'C:\src\flutter\bin\flutter.bat'
$raiz = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $EnvFrontend)) {
  Write-Error "No encuentro $EnvFrontend. Pasa la ruta con -EnvFrontend."
}

function Leer([string]$clave) {
  $linea = Select-String -Path $EnvFrontend -Pattern "^$clave=" -ErrorAction SilentlyContinue |
           Select-Object -First 1
  if ($null -eq $linea) { return '' }
  return ($linea.Line -replace "^$clave=", '').Trim().Trim('"')
}

$url = Leer 'NEXT_PUBLIC_SUPABASE_URL'
$anon = Leer 'NEXT_PUBLIC_SUPABASE_ANON_KEY'

if ([string]::IsNullOrWhiteSpace($anon)) {
  Write-Error "NEXT_PUBLIC_SUPABASE_ANON_KEY vacía en $EnvFrontend."
}

# Se confirma el proyecto, no se imprime la llave.
Write-Host "Supabase: $url" -ForegroundColor DarkGray
Write-Host "Anon key: ...$($anon.Substring($anon.Length - 6)) (oculta)" -ForegroundColor DarkGray

$args = @(
  $Accion
  if ($Accion -eq 'build') { 'apk' }
  '--debug'
  if ($Dispositivo) { '-d'; $Dispositivo }
  "--dart-define=APP_FLAVOR=development"
  "--dart-define=SUPABASE_URL=$url"
  "--dart-define=SUPABASE_ANON_KEY=$anon"
)

Push-Location $raiz
try { & $flutter @args } finally { Pop-Location }
