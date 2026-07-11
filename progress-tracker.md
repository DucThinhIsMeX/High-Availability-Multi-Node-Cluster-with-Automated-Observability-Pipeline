# 📊 NHẬT KÝ TIẾN ĐỘ DỰ ÁN (PROJECT PROGRESS TRACKER)

File này lưu trữ chi tiết tiến độ thực hiện dự án **High-Availability Multi-Node Cluster with Automated Observability Pipeline** mô phỏng bằng Docker-in-Docker (DinD).

---

## 📈 TIẾN TRÌNH THỰC HIỆN (CHECKLIST)

- [x] **PHẦN 1: Chuẩn bị môi trường**
  - [x] Kích hoạt ảo hóa (Virtualization) và WSL 2 trên Windows.
  - [x] Tải và cài đặt Docker Desktop trên Windows.
  - [x] Khởi tạo mạng ảo nội bộ `swarm-network` (Subnet: `192.168.56.0/24`).
  - [x] Tạo và khởi chạy 3 container mô phỏng node:
    - [x] `swarm-master` (IP: `192.168.56.10`, Ports: `80`, `3000`, `9090`).
    - [x] `swarm-worker1` (IP: `192.168.56.11`).
    - [x] `swarm-worker2` (IP: `192.168.56.12`).
- [x] **PHẦN 2: Thiết lập cụm Docker Swarm**
  - [x] Khởi tạo Swarm trên `swarm-master`.
  - [x] Join các node `swarm-worker1` và `swarm-worker2` vào cluster.
  - [x] Gán nhãn role cho các worker nodes.
- [x] **PHẦN 3: Triển khai ứng dụng Web**
  - [x] Copy thư mục `infrastructure` từ máy thật vào container `swarm-master`.
  - [x] Deploy stack ứng dụng web (4 replicas).
  - [x] Khởi động Nginx Load Balancer container inside `swarm-master` điều hướng đến các worker.
  - [x] Kiểm thử truy cập web qua `http://localhost`.
- [x] **PHẦN 4: Thiết lập Observability Pipeline (Giám sát & Cảnh báo)**
  - [x] Khởi chạy Node Exporter trên cả 3 nodes (master, worker1, worker2).
  - [x] Cấu hình Telegram Bot Token và Chat ID trong file `monitoring/alertmanager.yml`.
  - [x] Copy thư mục `monitoring` từ máy thật vào container `swarm-master`.
  - [x] Khởi chạy cụm Prometheus, Grafana, Alertmanager trên `swarm-master`.
- [x] **PHẦN 5: Cấu hình Dashboard & Cảnh báo**
  - [x] Truy cập Grafana qua `http://localhost:3000`.
  - [x] Cấu hình Prometheus Data Source.
  - [x] Import Node Exporter Dashboard (ID: `1860`).
- [x] **PHẦN 6: Kiểm thử (Testing Cases)**
  - [x] Test Load Balancing (Round Robin).
  - [x] Test Self-healing (Stop worker 2, verify replicas move to worker 1).
  - [x] Test Alerting (Stress CPU on worker 1, verify Telegram notification / alert states).

---

## 📝 LỊCH SỬ THAO TÁC CHI TIẾT (OPERATION LOG)

### Ngày: 11-07-2026

#### 1. Cài đặt Docker Desktop
*   **Trạng thái:** Hoàn thành.
*   **Chi tiết:** Cài đặt Docker Desktop thành công trên máy Windows, sử dụng WSL 2 engine.

#### 2. Khởi tạo các Docker-in-Docker (DinD) Containers làm Node máy ảo
*   **Trạng thái:** Hoàn thành.
*   **Các lệnh đã chạy trên Windows PowerShell:**
    ```powershell
    # 1. Tạo mạng ảo
    docker network create --subnet 192.168.56.0/24 swarm-network

    # 2. Tạo Master node
    docker run -d --privileged --name swarm-master --hostname swarm-master --network swarm-network --ip 192.168.56.10 -p 80:80 -p 3000:3000 -p 9090:9090 docker:dind

    # 3. Tạo Worker 1 node
    docker run -d --privileged --name swarm-worker1 --hostname swarm-worker1 --network swarm-network --ip 192.168.56.11 docker:dind

    # 4. Tạo Worker 2 node
    docker run -d --privileged --name swarm-worker2 --hostname swarm-worker2 --network swarm-network --ip 192.168.56.12 docker:dind
    ```
*   **Mục tiêu kế tiếp:** Kiểm thử toàn diện hệ thống (Load balancing, Self-healing, Alerting).

#### 3. Kết nối cụm Docker Swarm
*   **Trạng thái:** Hoàn thành.
*   **Chi tiết:** Khởi tạo Swarm thành công trên `swarm-master` làm Leader. Hai worker `swarm-worker1` và `swarm-worker2` đã join thành công. Đã gán nhãn `role=worker` cho cả hai worker.

#### 4. Triển khai ứng dụng Web & Load Balancer
*   **Trạng thái:** Hoàn thành.
*   **Chi tiết:** Sao chép cấu hình hạ tầng vào `swarm-master`. Deploy Stack `my_app` với 4 replicas chạy trên các Worker. Khởi động container `nginx-lb` để cân bằng tải cổng 80 cho cụm. Kiểm tra truy cập qua `http://localhost` hoạt động ổn định.

#### 5. Thiết lập Observability Pipeline
*   **Trạng thái:** Hoàn thành.
*   **Chi tiết:** Khởi chạy Node Exporter trên cả 3 node ảo (Master, Worker 1, Worker 2). Đồng bộ thư mục `monitoring` sang `swarm-master`. Khởi chạy thành công bộ ba Prometheus, Grafana, Alertmanager.

#### 6. Cấu hình Grafana Dashboard
*   **Trạng thái:** Hoàn thành.
*   **Chi tiết:** Truy cập Grafana thành công qua `http://localhost:3000`. Liên kết Prometheus Data Source thành công. Import thành công Dashboard Node Exporter ID 1860 và xem được biểu đồ tài nguyên realtime.

#### 7. Kiểm thử toàn hệ thống (Testing Verification)
*   **Trạng thái:** Hoàn thành.
*   **Chi tiết:**
    *   Truy cập thành công giao diện Cảnh báo (Alerts) của Prometheus tại `http://localhost:9090/alerts` hiển thị 4 rules ở trạng thái `INACTIVE` (khỏe mạnh).
    *   Mô phỏng sập Worker 2 thành công (`docker stop swarm-worker2`), Swarm tự động di chuyển các container sang Worker 1.
    *   Test NodeDown Alert thành công khi dừng Node Exporter.
