# Start MongoDB without Windows service (no admin required)
# Uses a local data folder inside this project.

$mongod = "C:\Program Files\MongoDB\Server\8.3\bin\mongod.exe"
$dbPath = Join-Path $PSScriptRoot "data\db"
$logPath = Join-Path $PSScriptRoot "data\mongod.log"

New-Item -ItemType Directory -Force -Path $dbPath | Out-Null

Write-Host "Starting MongoDB on mongodb://127.0.0.1:27017/chicken_farm"
Write-Host "Data: $dbPath"
Write-Host "Press Ctrl+C to stop."

& $mongod --dbpath $dbPath --port 27017 --bind_ip 127.0.0.1 --logpath $logPath
