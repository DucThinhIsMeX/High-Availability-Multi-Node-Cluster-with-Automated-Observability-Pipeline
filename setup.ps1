# Script tự động hóa toàn bộ việc thiết lập cụm Docker Swarm DinD & Giám sát

Write-Host "=== BẮT ĐẦU THIẾT LẬP CỤM DOCKER SWARM DIND ===" -ForegroundColor Cyan

# 1. Kiểm tra Docker Desktop có đang chạy không
docker info > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker Desktop chưa chạy. Hãy mở Docker Desktop và chạy lại script này!"
    Exit 1
}

# 2. Tạo mạng ảo
Write-Host "1. Khởi tạo mạng ảo..." -ForegroundColor Yellow
$networkCheck = docker network ls --filter name=swarm-network -q
if (-not $networkCheck) {
    docker network create --subnet 192.168.56.0/24 swarm-network > $null
    Write-Host "-> Đã tạo mạng swarm-network." -ForegroundColor Green
} else {
    Write-Host "-> Mạng swarm-network đã tồn tại." -ForegroundColor Gray
}

# 3. Tạo các container node
Write-Host "2. Khởi tạo các container Node (DinD)..." -ForegroundColor Yellow
$nodes = @("swarm-master", "swarm-worker1", "swarm-worker2")
$ips = @("192.168.56.10", "192.168.56.11", "192.168.56.12")

for ($i = 0; $i -lt $nodes.Length; $i++) {
    $name = $nodes[$i]
    $ip = $ips[$i]
    $check = docker ps -a --filter name=$name -q
    if ($check) {
        Write-Host "-> Container $name đã tồn tại. Đang xóa và tái tạo..." -ForegroundColor DarkYellow
        docker rm -f $name > $null
    }
    
    if ($name -eq "swarm-master") {
        docker run -d --privileged --name $name --hostname $name --network swarm-network --ip $ip -p 80:80 -p 3000:3000 -p 9090:9090 docker:dind > $null
    } else {
        docker run -d --privileged --name $name --hostname $name --network swarm-network --ip $ip docker:dind > $null
    }
    Write-Host "-> Đã khởi chạy $name ($ip)" -ForegroundColor Green
}

# Chờ DinD daemon khởi động (khoảng 8 giây)
Write-Host "Đang chờ Docker Engine bên trong các node khởi động (8 giây)..." -ForegroundColor Gray
Start-Sleep -Seconds 8

# 4. Khởi tạo Swarm trên Master
Write-Host "3. Khởi tạo cụm Docker Swarm..." -ForegroundColor Yellow
$swarmInit = docker exec -t swarm-master docker swarm init --advertise-addr 192.168.56.10 > $null
Write-Host "-> Đã khởi tạo Swarm trên swarm-master." -ForegroundColor Green

# Lấy token join
$joinTokenCmd = docker exec -t swarm-master docker swarm join-token worker
$joinTokenLine = ($joinTokenCmd | Select-String "docker swarm join --token").ToString().Trim()

# Cắt chuỗi để lấy phần token và IP manager
if ($joinTokenLine -match "docker swarm join --token\s+(\S+)\s+(\S+)") {
    $token = $Matches[1]
    $managerIp = $Matches[2]
} else {
    Write-Error "Lỗi: Không lấy được token join Swarm tự động."
    Exit 1
}

# 5. Cho các Worker join
Write-Host "4. Kết nối các Worker vào cụm..." -ForegroundColor Yellow
docker exec -t swarm-worker1 docker swarm join --token $token $managerIp > $null
Write-Host "-> swarm-worker1 đã join cụm thành công." -ForegroundColor Green

docker exec -t swarm-worker2 docker swarm join --token $token $managerIp > $null
Write-Host "-> swarm-worker2 đã join cụm thành công." -ForegroundColor Green

# 6. Gán nhãn cho worker
Write-Host "5. Gán nhãn các node..." -ForegroundColor Yellow
docker exec -t swarm-master docker node update --label-add role=worker swarm-worker1 > $null
docker exec -t swarm-master docker node update --label-add role=worker swarm-worker2 > $null
Write-Host "-> Đã gán nhãn role=worker cho worker1 và worker2." -ForegroundColor Green

# 7. Đồng bộ code và deploy webapp
Write-Host "6. Triển khai Ứng dụng Web..." -ForegroundColor Yellow
docker cp infrastructure swarm-master:/infrastructure
docker exec -t swarm-master docker stack deploy -c /infrastructure/docker-compose-app.yml my_app > $null
Write-Host "-> Đã deploy Stack my_app." -ForegroundColor Green

# Chạy Nginx Load Balancer
docker exec -t swarm-master docker run -d --name nginx-lb -p 80:80 -v /infrastructure/nginx-loadbalancer.conf:/etc/nginx/conf.d/default.conf nginx:alpine > $null
Write-Host "-> Đã khởi chạy Nginx Load Balancer container." -ForegroundColor Green

# 8. Triển khai hệ thống giám sát
Write-Host "7. Triển khai Hệ thống giám sát (Observability)..." -ForegroundColor Yellow
# Run Node Exporters
docker exec -d swarm-master docker run -d --name node-exporter --restart always --net host --pid host -v "/:/host:ro,rslave" prom/node-exporter:latest --path.rootfs=/host > $null
docker exec -d swarm-worker1 docker run -d --name node-exporter --restart always --net host --pid host -v "/:/host:ro,rslave" prom/node-exporter:latest --path.rootfs=/host > $null
docker exec -d swarm-worker2 docker run -d --name node-exporter --restart always --net host --pid host -v "/:/host:ro,rslave" prom/node-exporter:latest --path.rootfs=/host > $null
Write-Host "-> Đã chạy Node Exporter trên cả 3 node." -ForegroundColor Green

# Đồng bộ monitoring và khởi chạy stack giám sát
docker cp monitoring swarm-master:/monitoring
docker exec -t swarm-master sh -c "cd /monitoring && docker compose -f docker-compose-monitor.yml up -d" > $null
Write-Host "-> Đã khởi chạy Prometheus, Grafana, Alertmanager." -ForegroundColor Green

Write-Host "=== THIẾT LẬP HOÀN TẤT THÀNH CÔNG ===" -ForegroundColor Green
Write-Host "Bạn có thể truy cập:" -ForegroundColor Cyan
Write-Host "1. Website: http://localhost" -ForegroundColor Gray
Write-Host "2. Prometheus: http://localhost:9090" -ForegroundColor Gray
Write-Host "3. Grafana: http://localhost:3000 (Tài khoản: admin / admin123)" -ForegroundColor Gray
