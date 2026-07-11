# Script dọn dẹp sạch cụm Swarm giả lập để giải phóng RAM/CPU

Write-Host "=== ĐANG DỌN DẸP CỤM DOCKER SWARM DIND ===" -ForegroundColor Red

# 1. Xóa các container node
$nodes = @("swarm-master", "swarm-worker1", "swarm-worker2")
foreach ($name in $nodes) {
    $check = docker ps -a --filter name=$name -q
    if ($check) {
        docker rm -f $name > $null
        Write-Host "-> Đã xóa container $name." -ForegroundColor Green
    }
}

# 2. Xóa mạng ảo
$networkCheck = docker network ls --filter name=swarm-network -q
if ($networkCheck) {
    docker network rm swarm-network > $null
    Write-Host "-> Đã xóa mạng ảo swarm-network." -ForegroundColor Green
}

Write-Host "=== ĐÃ DỌN DẸP XONG ===" -ForegroundColor Green
