resource "yandex_vpc_security_group" "app" {
  name       = "${local.stand}-sg"
  network_id = yandex_vpc_network.net.id

  # по одному правилу на каждый порт из списка
  dynamic "ingress" {
    for_each = var.open_ports
    content {
      protocol       = "TCP"
      port           = ingress.value
      v4_cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # весь выход наружу: без него машина при пересоздании не скачает пакеты
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
