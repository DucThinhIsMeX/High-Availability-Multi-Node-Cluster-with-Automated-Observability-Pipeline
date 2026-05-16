# 📊 High-Availability Multi-Node Cluster with Automated Observability Pipeline

![Linux](https://img.shields.io/badge/OS-Linux%20%7C%20Ubuntu%20Server-orange?style=flat-square&logo=ubuntu)
![Docker](https://img.shields.io/badge/Container-Docker%20%7C%20Swarm-blue?style=flat-square&logo=docker)
![Nginx](https://img.shields.io/badge/Proxy-Nginx%20Load%20Balancer-green?style=flat-square&logo=nginx)
![Prometheus](https://img.shields.io/badge/Monitor-Prometheus-orange?style=flat-square&logo=prometheus)
![Grafana](https://img.shields.io/badge/Dashboard-Grafana-orange?style=flat-square&logo=grafana)

Một hệ thống hạ tầng mạng phân tán dựa trên kiến trúc **Multi-node** nhằm tối ưu hóa khả năng chịu tải, đảm bảo tính sẵn sàng cao (High Availability) và tự phục hồi (Self-healing) cho ứng dụng doanh nghiệp, kết hợp hệ thống "mắt thần" giám sát chỉ số phần cứng tập trung và cảnh báo sự cố tự động qua Telegram.

---

## 🚀 Tính năng nổi bật

- **High Availability (HA):** Ứng dụng được nhân bản và chạy phân tán trên nhiều máy ảo (Worker Nodes). Hệ thống tự động phát hiện và phục hồi dịch vụ (Self-healing) nếu một node gặp sự cố sập nguồn hoặc mất kết nối.
- **Load Balancing:** Sử dụng Nginx làm proxy ngược (Reverse Proxy) và cân bằng tải giúp phân phối đều lưu lượng truy cập của người dùng đến các node phía sau bằng thuật toán *Round Robin*.
- **Centralized Monitoring:** Thu thập toàn bộ chỉ số tài nguyên phần cứng (CPU, RAM, Disk, Network) của tất cả các máy ảo về một trung tâm quản lý duy nhất bằng Prometheus & Node Exporter.
- **Visualized Dashboard:** Biểu diễn dữ liệu trực quan bằng các biểu đồ realtime trên Grafana, giúp quản trị viên nắm bắt sức khỏe hệ thống chỉ trong 5 giây.
- **Instant Alerting:** Cấu hình Alertmanager chủ động gửi tin nhắn cảnh báo tức thời về Telegram/Discord khi phát hiện server bị quá tải tài nguyên (>80%) hoặc dịch vụ bị sập.

---

## 📐 Kiến trúc hệ thống (Architecture)

```text
                      [ Khách hàng truy cập ]
                                 │
                                 ▼
                     ┌───────────────────────┐
                     │ Nginx Load Balancer   │
                     └───────────┬───────────┘
                                 │ (Chia tải Round Robin)
                ┌────────────────┴────────────────┐
                ▼                                 ▼
     ┌─────────────────────┐           ┌─────────────────────┐
     │    Worker Node 1    │           │    Worker Node 2    │
     │  ┌───────────────┐  │           │  ┌───────────────┐  │
     │  │ App Container │  │           │  │ App Container │  │
     │  └───────┬───────┘  │           │  └───────┬───────┘  │
     │          │          │           │          │          │
     │  ┌───────▼───────┐  │           │  ┌───────▼───────┐  │
     │  │ Node Exporter │  │           │  │ Node Exporter │  │
     │  └───────┬───────┘  │           │  └───────┬───────┘  │
     └──────────┼──────────┘           └──────────┼──────────┘
                │                                 │
                └───────────────┬─────────────────┘
                                │ (Thu thập Metrics sau mỗi 5s)
                                ▼
                     ┌───────────────────────┐
                     │      Master Node      │
                     │  ┌─────────────────┐  │
                     │  │   Prometheus    │  │
                     │  └────────┬────────┘  │
                     │           ▼           │
                     │  ┌─────────────────┐  │      ┌─────────────────┐
                     │  │     Grafana     │ ─┼────> │ Cảnh báo Tlg/Dc │
                     │  └─────────────────┘  │      └─────────────────┘
                     └───────────────────────┘
🛠️ Công nghệ sử dụngHệ điều hành: Ubuntu Server 20.04/22.04 LTS (Chạy trên môi trường ảo hóa VMware/VirtualBox).Quản lý Container: Docker & Docker Swarm Orchestration.Điều phối lưu lượng: Nginx Giga-scale Load Balancer.Giám sát & Cảnh báo: Prometheus, Node Exporter, Grafana, Alertmanager.Kịch bản tự động: Shell Scripting / Bash.📂 Cấu trúc thư mục dự ánPlaintext├── infrastructure/
│   ├── docker-compose-app.yml     # File deploy ứng dụng trên cụm Swarm
│   └── nginx-loadbalancer.conf    # Cấu hình chia tải của Nginx
├── monitoring/
│   ├── prometheus.yml             # Cấu hình thu thập target metrics
│   ├── alertmanager.yml           # Cấu hình webhook gửi về Telegram
│   ├── grafana-dashboard.json     # Template giao diện biểu đồ Grafana
│   └── docker-compose-monitor.yml # File khởi chạy bộ công cụ giám sát
└── README.md                      # Báo cáo tổng quan dự án
💻 Hướng dẫn triển khai nhanh (Quick Start)1. Chuẩn bị môi trườngĐảm bảo bạn đã có ít nhất 3 máy ảo Ubuntu Server đã cài đặt sẵn Docker.Khởi tạo cụm Swarm trên máy Master: docker swarm initCopy câu lệnh token được sinh ra và gõ trên các máy Worker để kết nối vào cụm: docker swarm join --token <TOKEN> <MASTER-IP>:23772. Clone dự án và Khởi chạyBash# Clone mã nguồn về máy Master
git clone [https://github.com/your-username/your-repo-name.git](https://github.com/your-username/your-repo-name.git)
cd your-repo-name

# Triển khai ứng dụng lên cụm Swarm
docker stack deploy -c infrastructure/docker-compose-app.yml my_app

# Khởi chạy hệ thống giám sát tập trung
docker-compose -f monitoring/docker-compose-monitor.yml up -d
3. Kiểm tra kết quảỨng dụng Web: Truy cập qua IP của Nginx Load Balancer tại cổng http://<LB-IP>:80Grafana Dashboard: Truy cập tại địa chỉ http://<MASTER-IP>:3000 (Tài khoản mặc định: admin/admin) để xem biểu đồ tài nguyên realtime.📸 Hình ảnh Demo thực tế(Dưới đây là một số hình ảnh chứng minh hệ thống vận hành thực tế trong môi trường ảo hóa)Giao diện Giám sát trực quan trên GrafanaCảnh báo sự cố tự động về Telegram [Thay bằng ảnh chụp màn hình Grafana của bạn] [Thay bằng ảnh chụp tin nhắn Telegram của bạn]
