# Local build + push. Usage: .\build.ps1 -Image ghcr.io/<owner>/pterodactyl-mssql:2022
param(
    [Parameter(Mandatory = $true)][string]$Image,
    [int]$Uid = 988
)
$ErrorActionPreference = 'Stop'
docker build --platform linux/amd64 --build-arg CONTAINER_UID=$Uid -t $Image .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
docker push $Image
