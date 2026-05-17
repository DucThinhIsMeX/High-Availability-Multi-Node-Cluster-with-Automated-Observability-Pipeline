# 📋 KẾ HOẠCH TRIỂN KHAI CHI TIẾT (A → Z)
## High-Availability Multi-Node Cluster with Automated Observability Pipeline

---

## TỔNG QUAN DỰ ÁN

**Mục tiêu:** Xây dựng hệ thống hạ tầng mạng phân tán Multi-node, đảm bảo tính sẵn sàng cao (HA), tự phục hồi (Self-healing), kèm hệ thống giám sát tập trung và cảnh báo sự cố tự động qua Telegram.

**Thời gian ước tính:** 3–5 ngày (tùy kinh nghiệm)

**Yêu cầu tối thiểu:** 1 máy tính cá nhân có RAM ≥ 8 GB, CPU ≥ 4 cores, ổ cứng trống ≥ 50 GB

---

## PHASE 1: CHUẨN BỊ MÔI TRƯỜNG (Ngày 1)

### 1.1. Cài đặt phần mềm ảo hóa

- Tải và cài đặt **VirtualBox** (miễn phí) hoặc **VMware Workstation Player**
- Tải file ISO **Ubuntu Server 22.04 LTS** từ trang chủ Ubuntu

### 1.2. Tạo 3 máy ảo (VM)

| VM | Vai trò | RAM | CPU | Disk | IP tĩnh (ví dụ) |
|---|---|---|---|---|---|
| VM1 | **Master Node** (Prometheus, Grafana, Alertmanager) | 2 GB | 2 cores | 20 GB | 192.168.56.10 |
| VM2 | **Worker Node 1** (App Container + Node Exporter) | 1 GB | 1 core | 15 GB | 192.168.56.11 |
| VM3 | **Worker Node 2** (App Container + Node Exporter) | 1 GB | 1 core | 15 GB | 192.168.56.12 |

> **Ghi chú:** Nginx Load Balancer có thể chạy trên Master Node hoặc tạo thêm VM4 riêng. Trong plan này, Nginx sẽ chạy trên Master Node để tiết kiệm tài nguyên.

### 1.3. Cài đặt Ubuntu Server cho từng VM

Thao tác lặp lại cho cả 3 VM:

```
1. Khởi động VM từ file ISO Ubuntu Server 22.04
2. Chọn ngôn ngữ → English
3. Cấu hình mạng → Đặt IP tĩnh theo bảng trên
4. Chọn ổ đĩa → Sử dụng toàn bộ disk
5. Đặt tên máy: master-node / worker-01 / worker-02
6. Tạo user: admin (hoặc tên bạn chọn)
7. Tích chọn "Install OpenSSH server"
8. Hoàn tất cài đặt → Reboot
```

### 1.4. Cấu hình mạng giữa các VM

```bash
# Trên mỗi VM, chỉnh file /etc/netplan/00-installer-config.yaml
# Ví dụ cho Master Node:
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    enp0s8:                    # Adapter Host-Only
      addresses:
        - 192.168.56.10/24     # IP tĩnh tương ứng
      dhcp4: false
    enp0s3:                    # Adapter NAT (để VM ra internet)
      dhcp4: true
```

```bash
sudo netplan apply
```

### 1.5. Kiểm tra kết nối giữa các VM

```bash
# Từ Master, ping sang 2 Worker
ping 192.168.56.11
ping 192.168.56.12

# Từ Worker, ping ngược lại Master
ping 192.168.56.10
```

### 1.6. Cài đặt Docker trên cả 3 VM

Chạy lần lượt trên **mỗi VM**:

```bash
# Cập nhật hệ thống
sudo apt update && sudo apt upgrade -y

# Cài đặt các gói phụ thuộc
sudo apt install -y ca-certificates curl gnupg lsb-release

# Thêm Docker GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Thêm Docker repository
echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Cài đặt Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Thêm user vào nhóm docker (không cần sudo mỗi lần)
sudo usermod -aG docker $USER
newgrp docker

# Kiểm tra
docker --version
docker compose version
```

---

## PHASE 2: KHỞI TẠO CỤM DOCKER SWARM (Ngày 1–2)

### 2.1. Khởi tạo Swarm trên Master Node

```bash
# Trên Master Node (192.168.56.10)
docker swarm init --advertise-addr 192.168.56.10
```

Kết quả sẽ hiển thị một câu lệnh dạng:

```
docker swarm join --token SWMTKN-1-xxxxx 192.168.56.10:2377
```

**Copy toàn bộ câu lệnh này.**

### 2.2. Kết nối Worker Nodes vào cụm

```bash
# Trên Worker Node 1 (192.168.56.11)
docker swarm join --token SWMTKN-1-xxxxx 192.168.56.10:2377

# Trên Worker Node 2 (192.168.56.12)
docker swarm join --token SWMTKN-1-xxxxx 192.168.56.10:2377
```

### 2.3. Xác nhận cụm Swarm hoạt động

```bash
# Trên Master Node
docker node ls
```

Kết quả mong đợi:

```
ID            HOSTNAME       STATUS    AVAILABILITY   MANAGER STATUS
abc123 *      master-node    Ready     Active         Leader
def456        worker-01      Ready     Active
ghi789        worker-02      Ready     Active
```

### 2.4. Gán label cho các node (hữu ích khi deploy)

```bash
docker node update --label-add role=worker worker-01
docker node update --label-add role=worker worker-02
```

---

## PHASE 3: TRIỂN KHAI ỨNG DỤNG WEB (Ngày 2)

### 3.1. Tạo cấu trúc thư mục dự án

```bash
# Trên Master Node
mkdir -p ~/ha-cluster/{infrastructure,monitoring}
cd ~/ha-cluster
```

### 3.2. Tạo ứng dụng web demo đơn giản

Tạo một app Node.js hoặc Nginx static page để kiểm chứng hệ thống:

```bash
mkdir -p ~/ha-cluster/app
nano ~/ha-cluster/app/index.html
```

```html
<!DOCTYPE html>
<html>
<head><title>HA Cluster Demo</title></head>
<body>
  <h1>Hello from Container: HOSTNAME_PLACEHOLDER</h1>
  <p>Server Time: <!-- sẽ thay bằng script --></p>
</body>
</html>
```

Hoặc dùng image có sẵn như `nginx:alpine` hay `httpd:alpine`.

### 3.3. Viết file Docker Compose cho ứng dụng

```bash
nano ~/ha-cluster/infrastructure/docker-compose-app.yml
```

```yaml
version: "3.8"

services:
  webapp:
    image: nginx:alpine
    deploy:
      replicas: 4                    # 4 bản sao, chia đều 2 worker
      placement:
        constraints:
          - node.role == worker      # Chỉ chạy trên worker
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      update_config:
        parallelism: 1
        delay: 10s
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
    ports:
      - "8080:80"
    networks:
      - app-network

networks:
  app-network:
    driver: overlay
```

### 3.4. Deploy ứng dụng lên cụm Swarm

```bash
docker stack deploy -c infrastructure/docker-compose-app.yml my_app
```

### 3.5. Kiểm tra trạng thái triển khai

```bash
# Xem danh sách service
docker service ls

# Xem chi tiết các task (container) đang chạy ở đâu
docker service ps my_app_webapp

# Kết quả mong đợi: 4 container phân bố trên worker-01 và worker-02
```

---

## PHASE 4: CẤU HÌNH NGINX LOAD BALANCER (Ngày 2)

### 4.1. Cài đặt Nginx trên Master Node

```bash
sudo apt install -y nginx
```

### 4.2. Viết file cấu hình Load Balancer

```bash
nano ~/ha-cluster/infrastructure/nginx-loadbalancer.conf
```

```nginx
upstream backend_servers {
    # Thuật toán Round Robin (mặc định)
    server 192.168.56.11:8080;    # Worker Node 1
    server 192.168.56.12:8080;    # Worker Node 2

    # Tùy chọn: Health check
    # server 192.168.56.11:8080 max_fails=3 fail_timeout=30s;
    # server 192.168.56.12:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://backend_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeout settings
        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }

    # Trang kiểm tra sức khỏe LB
    location /health {
        return 200 "Load Balancer is healthy\n";
        add_header Content-Type text/plain;
    }
}
```

### 4.3. Áp dụng cấu hình

```bash
# Backup cấu hình mặc định
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak

# Copy cấu hình mới
sudo cp ~/ha-cluster/infrastructure/nginx-loadbalancer.conf \
  /etc/nginx/sites-available/default

# Kiểm tra cú pháp
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### 4.4. Kiểm tra Load Balancer hoạt động

```bash
# Gọi nhiều lần, quan sát response thay đổi (container ID khác nhau)
curl http://192.168.56.10
curl http://192.168.56.10
curl http://192.168.56.10
curl http://192.168.56.10
```

---

## PHASE 5: TRIỂN KHAI HỆ THỐNG GIÁM SÁT (Ngày 3)

### 5.1. Cài đặt Node Exporter trên cả 3 VM

Chạy trên **mỗi VM** (Master + 2 Worker):

```bash
docker run -d \
  --name node-exporter \
  --restart always \
  --net host \
  --pid host \
  -v "/:/host:ro,rslave" \
  prom/node-exporter:latest \
  --path.rootfs=/host
```

Kiểm tra:

```bash
curl http://localhost:9100/metrics | head -20
```

### 5.2. Cấu hình Prometheus

```bash
nano ~/ha-cluster/monitoring/prometheus.yml
```

```yaml
global:
  scrape_interval: 5s          # Thu thập mỗi 5 giây
  evaluation_interval: 5s

# Kết nối Alertmanager
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - "alertmanager:9093"

# Nạp file quy tắc cảnh báo
rule_files:
  - "alert-rules.yml"

# Danh sách target cần giám sát
scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "master-node"
    static_configs:
      - targets: ["192.168.56.10:9100"]
        labels:
          instance_name: "master-node"

  - job_name: "worker-01"
    static_configs:
      - targets: ["192.168.56.11:9100"]
        labels:
          instance_name: "worker-01"

  - job_name: "worker-02"
    static_configs:
      - targets: ["192.168.56.12:9100"]
        labels:
          instance_name: "worker-02"
```

### 5.3. Tạo quy tắc cảnh báo (Alert Rules)

```bash
nano ~/ha-cluster/monitoring/alert-rules.yml
```

```yaml
groups:
  - name: hardware_alerts
    rules:
      # Cảnh báo khi CPU > 80% trong 2 phút
      - alert: HighCpuUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "CPU cao trên {{ $labels.instance_name }}"
          description: "CPU đang ở mức {{ $value | printf \"%.1f\" }}% trên {{ $labels.instance_name }}"

      # Cảnh báo khi RAM > 80%
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "RAM cao trên {{ $labels.instance_name }}"
          description: "RAM đang ở mức {{ $value | printf \"%.1f\" }}%"

      # Cảnh báo khi Disk > 85%
      - alert: HighDiskUsage
        expr: (1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100 > 85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk gần đầy trên {{ $labels.instance_name }}"
          description: "Disk đã sử dụng {{ $value | printf \"%.1f\" }}%"

      # Cảnh báo khi một node bị mất kết nối
      - alert: NodeDown
        expr: up == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance_name }} không phản hồi!"
          description: "Không thể thu thập metrics từ {{ $labels.instance }} trong 30 giây."
```

### 5.4. Cấu hình Alertmanager (gửi cảnh báo Telegram)

**Bước chuẩn bị:** Tạo Telegram Bot:

```
1. Mở Telegram, tìm @BotFather
2. Gửi /newbot → đặt tên bot → nhận BOT_TOKEN
3. Tạo một Group Chat, thêm bot vào
4. Gửi một tin nhắn bất kỳ vào group
5. Truy cập: https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
6. Tìm "chat":{"id": -XXXXXXXXX} → đây là CHAT_ID
```

```bash
nano ~/ha-cluster/monitoring/alertmanager.yml
```

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: "telegram-notify"
  group_by: ["alertname", "instance"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: "telegram-notify"
    telegram_configs:
      - bot_token: "YOUR_BOT_TOKEN_HERE"         # Thay token bot
        chat_id: -1001234567890                    # Thay chat ID
        send_resolved: true
        message: |
          {{ if eq .Status "firing" }}🔴 CẢNH BÁO{{ else }}🟢 ĐÃ PHỤC HỒI{{ end }}

          Tên: {{ .CommonLabels.alertname }}
          Server: {{ .CommonLabels.instance_name }}
          Mức độ: {{ .CommonLabels.severity }}
          {{ range .Alerts }}
          📝 {{ .Annotations.description }}
          {{ end }}
```

### 5.5. Viết Docker Compose cho bộ giám sát

```bash
nano ~/ha-cluster/monitoring/docker-compose-monitor.yml
```

```yaml
version: "3.8"

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alert-rules.yml:/etc/prometheus/alert-rules.yml
      - prometheus-data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.retention.time=15d"
    networks:
      - monitor-net

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: always
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
    command:
      - "--config.file=/etc/alertmanager/alertmanager.yml"
    networks:
      - monitor-net

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: always
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - monitor-net

volumes:
  prometheus-data:
  grafana-data:

networks:
  monitor-net:
    driver: bridge
```

### 5.6. Khởi chạy bộ giám sát

```bash
cd ~/ha-cluster/monitoring
docker compose -f docker-compose-monitor.yml up -d

# Kiểm tra tất cả container đang chạy
docker ps
```

---

## PHASE 6: CẤU HÌNH GRAFANA DASHBOARD (Ngày 3–4)

### 6.1. Truy cập Grafana

```
URL: http://192.168.56.10:3000
Username: admin
Password: admin123 (đổi ngay sau lần đăng nhập đầu tiên)
```

### 6.2. Thêm Prometheus làm Data Source

```
1. Menu trái → Connections → Data Sources → Add data source
2. Chọn "Prometheus"
3. URL: http://prometheus:9090
4. Click "Save & Test" → phải hiện "Successfully queried the Prometheus API"
```

### 6.3. Import Dashboard có sẵn (nhanh nhất)

```
1. Menu trái → Dashboards → Import
2. Nhập Dashboard ID: 1860 (Node Exporter Full)
3. Chọn Data Source: Prometheus
4. Click Import
```

> Dashboard 1860 là template cộng đồng rất phổ biến, hiển thị đầy đủ CPU, RAM, Disk, Network cho từng node.

### 6.4. Tùy chỉnh Dashboard (tùy chọn)

```
- Thêm panel mới: CPU Usage by Node (biểu đồ line)
- Thêm panel: Memory Usage Overview (gauge)
- Thêm panel: Network Traffic In/Out (biểu đồ area)
- Thêm panel: Disk I/O (biểu đồ bar)
- Lưu dashboard → Export JSON → lưu vào monitoring/grafana-dashboard.json
```

### 6.5. Kiểm tra Prometheus Targets

```
URL: http://192.168.56.10:9090/targets

Kết quả mong đợi: Tất cả 3 target (master, worker-01, worker-02) 
đều hiện trạng thái "UP" màu xanh
```

---

## PHASE 7: KIỂM THỬ TOÀN HỆ THỐNG (Ngày 4)

### 7.1. Test Load Balancing

```bash
# Gửi 100 request liên tục, kiểm tra phân phối đều
for i in $(seq 1 100); do
  curl -s http://192.168.56.10 | grep -o "hostname.*" >> /tmp/lb-test.log
done

# Đếm số lần mỗi container được gọi
sort /tmp/lb-test.log | uniq -c | sort -rn
```

### 7.2. Test High Availability — Self-healing

```bash
# Xem trạng thái ban đầu
docker service ps my_app_webapp

# Tắt Worker Node 2 (mô phỏng sự cố)
# → Vào VirtualBox/VMware, Power Off VM worker-02

# Đợi 30 giây, kiểm tra lại
docker service ps my_app_webapp
# Kết quả: Swarm tự động di chuyển container sang Worker Node 1

# Bật lại Worker Node 2
# → Power On VM worker-02, đợi nó rejoin Swarm

# Kiểm tra lại → container được cân bằng lại
docker service ps my_app_webapp
```

### 7.3. Test Alerting — Telegram Notification

```bash
# Tạo tải CPU giả trên Worker Node 1
# SSH vào worker-01, chạy:
sudo apt install -y stress
stress --cpu 4 --timeout 180s

# Đợi khoảng 2-3 phút → kiểm tra Telegram
# Phải nhận được tin nhắn cảnh báo "HighCpuUsage"

# Sau khi stress kết thúc → nhận tin "ĐÃ PHỤC HỒI"
```

### 7.4. Test Node Down Alert

```bash
# Tắt Node Exporter trên worker-02
ssh admin@192.168.56.12 "docker stop node-exporter"

# Đợi 30 giây → Telegram nhận cảnh báo "NodeDown"

# Bật lại
ssh admin@192.168.56.12 "docker start node-exporter"
# → Nhận thông báo phục hồi
```

---

## PHASE 8: HOÀN THIỆN & TÀI LIỆU (Ngày 4–5)

### 8.1. Push code lên GitHub

```bash
cd ~/ha-cluster
git init
git add .
git commit -m "feat: initial commit - HA cluster with observability"
git remote add origin https://github.com/<username>/<repo-name>.git
git branch -M main
git push -u origin main
```

### 8.2. Chụp ảnh demo cho README

Cần chụp tối thiểu các ảnh sau:

| STT | Nội dung cần chụp | Mục đích |
|---|---|---|
| 1 | `docker node ls` — hiện 3 node Ready | Chứng minh cụm Swarm hoạt động |
| 2 | `docker service ps my_app_webapp` — container phân bố 2 worker | Chứng minh HA deployment |
| 3 | Kết quả `curl` nhiều lần — response khác nhau | Chứng minh Load Balancing |
| 4 | Grafana Dashboard — biểu đồ CPU/RAM/Disk/Network | Chứng minh Monitoring hoạt động |
| 5 | Prometheus Targets — tất cả UP | Chứng minh thu thập metrics |
| 6 | Tin nhắn Telegram — cảnh báo firing + resolved | Chứng minh Alerting hoạt động |
| 7 | `docker service ps` trước/sau khi tắt 1 node | Chứng minh Self-healing |

### 8.3. Cấu trúc thư mục cuối cùng

```
ha-cluster/
├── infrastructure/
│   ├── docker-compose-app.yml
│   └── nginx-loadbalancer.conf
├── monitoring/
│   ├── prometheus.yml
│   ├── alert-rules.yml
│   ├── alertmanager.yml
│   ├── grafana-dashboard.json
│   └── docker-compose-monitor.yml
├── app/                              # (tùy chọn)
│   └── index.html
├── screenshots/                      # Ảnh demo
│   ├── grafana-dashboard.png
│   ├── telegram-alert.png
│   └── ...
├── .gitignore
└── README.md
```

### 8.4. Tạo file .gitignore

```bash
nano ~/ha-cluster/.gitignore
```

```
# Dữ liệu volume
prometheus-data/
grafana-data/

# File nhạy cảm (nếu có token thật)
*.env
secrets/
```

---

## CHECKLIST TỔNG KẾT

| # | Hạng mục | Trạng thái |
|---|---|---|
| 1 | 3 VM Ubuntu Server cài đặt xong, ping được nhau | ☐ |
| 2 | Docker cài đặt trên cả 3 VM | ☐ |
| 3 | Docker Swarm khởi tạo, 3 node join thành công | ☐ |
| 4 | Ứng dụng deploy 4 replicas trên 2 Worker | ☐ |
| 5 | Nginx Load Balancer chia tải Round Robin hoạt động | ☐ |
| 6 | Node Exporter chạy trên cả 3 VM | ☐ |
| 7 | Prometheus thu thập metrics, tất cả target UP | ☐ |
| 8 | Grafana hiển thị dashboard realtime | ☐ |
| 9 | Alertmanager gửi cảnh báo Telegram thành công | ☐ |
| 10 | Test Self-healing: tắt 1 node → container tự di chuyển | ☐ |
| 11 | Test Alert: stress CPU → nhận cảnh báo Telegram | ☐ |
| 12 | Code push lên GitHub, README có ảnh demo | ☐ |

---

## CÁC LỖI THƯỜNG GẶP & CÁCH XỬ LÝ

| Lỗi | Nguyên nhân | Cách xử lý |
|---|---|---|
| Worker không join được Swarm | Firewall chặn port 2377 | `sudo ufw allow 2377/tcp` |
| Prometheus target DOWN | Node Exporter chưa chạy hoặc firewall chặn 9100 | Kiểm tra `docker ps` + `sudo ufw allow 9100/tcp` |
| Grafana không kết nối Prometheus | Sai URL data source | Dùng `http://prometheus:9090` (tên container, không dùng localhost) |
| Telegram không nhận cảnh báo | Sai bot_token hoặc chat_id | Kiểm tra lại qua API `getUpdates` |
| Container không tự phục hồi | `restart_policy` chưa cấu hình | Thêm `condition: on-failure` trong deploy config |
| Nginx 502 Bad Gateway | Worker node chưa sẵn sàng | Kiểm tra app đã chạy trên worker: `docker service ps` |

---

## TÀI LIỆU THAM KHẢO

- Docker Swarm: https://docs.docker.com/engine/swarm/
- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/
- Alertmanager Telegram: https://prometheus.io/docs/alerting/latest/configuration/#telegram_config
- Nginx Load Balancing: https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/
- Node Exporter: https://github.com/prometheus/node_exporter
