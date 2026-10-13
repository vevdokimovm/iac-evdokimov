# ---------- сеть и подсети (вариант 11: зона A по варианту — b, но машины в ней не создавались, взята e; зона B — d) ----------

resource "yandex_vpc_network" "net" {
  name = "evdokimov-11-hw2-net"
}

resource "yandex_vpc_subnet" "a" {
  name           = "evdokimov-11-hw2-subnet-a"
  zone           = "ru-central1-e"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.21.1.0/24"]
}

resource "yandex_vpc_subnet" "b" {
  name           = "evdokimov-11-hw2-subnet-b"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.21.2.0/24"]
}

# ---------- образ ----------

data "yandex_compute_image" "os" {
  family = "debian-12"
}

# ---------- веб-серверы ----------

resource "yandex_compute_instance" "web" {
  count = 2 # число серверов из варианта 11

  name        = "evdokimov-11-hw2-web-${count.index + 1}"
  hostname    = "evdokimov-11-hw2-web-${count.index + 1}"
  platform_id = "standard-v3"

  # чётные номера идут в зону e, нечётные в зону d: машины делят две зоны поровну
  zone = count.index % 2 == 0 ? "ru-central1-e" : "ru-central1-d"

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.os.id
      # 10 ГБ: квота на HDD в зоне около 30 ГБ, две машины по 20 ГБ в одной зоне не помещаются
      size = 10
      type = "network-hdd"
    }
  }

  network_interface {
    subnet_id = count.index % 2 == 0 ? yandex_vpc_subnet.a.id : yandex_vpc_subnet.b.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.tpl.yaml", {
      app_port = 8033
      greeting = "devlab"
      ssh_key  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGhSpOj+xX2WM3CHjObZkHDMexhvOD7ac3+9Ko9YCpme evdokimov-iac-2026"
    })
  }

  labels = {
    env   = "test"
    owner = "evdokimov-11"
  }
}

# ---------- целевая группа и балансировщик ----------

resource "yandex_lb_target_group" "web" {
  name = "evdokimov-11-hw2-tg"

  # по блоку на каждую машину: сколько бы их ни было, группа включает все
  dynamic "target" {
    for_each = yandex_compute_instance.web
    content {
      subnet_id = target.value.network_interface.0.subnet_id
      # внутренний адрес: с публичным группа создастся, но цели не станут HEALTHY
      address = target.value.network_interface.0.ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "lb" {
  name = "evdokimov-11-hw2-lb"

  listener {
    name        = "http"
    port        = 80
    target_port = 8033
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web.id

    healthcheck {
      name                = "http"
      interval            = 2
      timeout             = 1
      unhealthy_threshold = 2
      healthy_threshold   = 2
      http_options {
        port = 8033
        path = "/"
      }
    }
  }
}
