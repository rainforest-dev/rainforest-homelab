# finance-audit — 每月信用卡對帳／回饋稽核的靜態儀表板（Nuxt SSG → nginx）。
#
# image 裡沒有任何財務資料：五份 artifacts JSON 一律從下面這個唯讀 bind mount 讀。
# 沒掛載 → 畫面上五個「讀取失敗」，不是「0 筆」；容器仍然 healthy。
#
# image 由 rainforest-finance/apps/finance-audit/Dockerfile 在本機 build，未推 registry。
# docker_container 不會自己 pull，所以 apply 前 `finance-audit:local` 必須已存在於本機 daemon。

locals {
  # 容器內部監聽埠，由 image 決定（Dockerfile 的 EXPOSE 8080）。
  # 必須是非特權 port —— runtime 以 nginx 使用者（非 root）執行。
  internal_port = 8080
}

resource "docker_container" "finance_audit" {
  image   = var.image
  name    = "${var.project_name}-finance-audit"
  restart = "always"

  memory = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (
    can(regex("Gi", var.memory_limit)) ? 1024 * 1024 * 1024 :
    can(regex("Mi", var.memory_limit)) ? 1024 * 1024 : 1
  )
  memory_swap = -1

  # 刻意只綁 loopback，不用其他服務慣用的 0.0.0.0：這個站供應敏感的個人財務資料，
  # 且沒有自己的登入機制，唯一入口必須是過 Cloudflare Access 的隧道。
  # 綁 0.0.0.0 會讓同網段任何裝置用 http://<LAN-IP>:8085 免認證讀到全部內容。
  #
  # 隧道不受影響：cloudflared pod 走 host.docker.internal（Docker Desktop gateway
  # 192.168.65.254），該 gateway 會代理到 host loopback。已實測 pod → 只綁
  # 127.0.0.1 的埠回 200，而同一個埠從區網 IP 連不上。
  ports {
    internal = local.internal_port
    external = var.external_port
    ip       = "127.0.0.1"
  }

  # 每月產出的 artifacts —— 唯讀掛載，這個站永遠只讀不寫。
  # nginx 以 `location ^~ /artifacts/ { root /srv; }` 對外服務這個目錄。
  volumes {
    container_path = "/srv/artifacts"
    host_path      = var.artifacts_path
    read_only      = true
  }

  # /healthz 由 nginx 直接 return 200，不碰檔案系統。
  # 刻意不驗 artifacts：忘了掛載要表現成畫面上的錯誤訊息，不是容器不健康。
  healthcheck {
    test         = ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1:${local.internal_port}/healthz"]
    interval     = "30s"
    timeout      = "3s"
    start_period = "5s"
    retries      = 3
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "service"
    value = "finance-audit"
  }
}
