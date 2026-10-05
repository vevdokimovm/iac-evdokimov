# ---------- сеть ----------

resource "yandex_vpc_network" "net" {
  name = "evdokimov-11-tf-net"
}

resource "yandex_vpc_subnet" "subnet" {
  name = "evdokimov-11-tf-subnet"
  zone = "ru-central1-b"

  # ссылка на атрибут другого ресурса: отсюда Terraform узнаёт,
  # что сеть надо создать раньше подсети. Порядок нигде не задан явно
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.21.1.0/24"]
}

# ---------- образ ----------

# запрос к облаку во время планирования: какой сейчас свежий образ
# нужного семейства. Вместо строки-идентификатора, которая устареет
data "yandex_compute_image" "base" {
  family = "debian-12"
}

# ---------- машина ----------

resource "yandex_compute_instance" "app" {
  name        = "evdokimov-11-tf-app"
  hostname    = "evdokimov-11-tf-app"
  zone        = "ru-central1-b"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }

  scheduling_policy {
    preemptible = true # прерываемая: дешевле, для учебного стенда достаточно
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.base.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true # публичный адрес
  }

  metadata = {
    # templatefile подставляет значения в шаблон — то же, что делал envsubst
    # во второй работе, только без внешней программы.
    # path.module — каталог, в котором лежит этот файл
    user-data = templatefile("${path.module}/cloud-init.tpl.yaml", {
      ssh_key = trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))
    })
  }

  labels = {
    env   = "test"
    owner = "evdokimov-11"
  }
}

# ---------- что вернуть после применения ----------

output "app_ip" {
  description = "публичный адрес машины"
  # у машины может быть несколько сетевых интерфейсов, поэтому к первому
  # обращаются по номеру: .0
  value = yandex_compute_instance.app.network_interface.0.nat_ip_address
}
