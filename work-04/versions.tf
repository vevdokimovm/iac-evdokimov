terraform {
  required_version = ">= 1.8"

  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      # ~> 0.220.0 — любая 0.220.x, но не 0.221: мелкие исправления берём,
      # смену поведения — нет
      version = "~> 0.220.0"
    }
  }
}

provider "yandex" {
  # ключ сервисного аккаунта лежит вне репозитория, в домашнем каталоге
  service_account_key_file = pathexpand("~/.yc-keys/evdokimov-11-key.json")

  # yc config get cloud-id и yc config get folder-id
  cloud_id  = "b1grvbhm63fj4j63bn6o"
  folder_id = "b1g3k9dacjr2mkm9me1k"
  zone      = "ru-central1-b"
}
