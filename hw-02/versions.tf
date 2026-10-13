terraform {
  required_version = ">= 1.8"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.220.0"
    }
  }
}

# Блок пустой намеренно: ключ, облако, каталог и зона приходят из переменных
# окружения YC_*. Путь к файлу ключа в блоке сломал бы validate в пайплайне,
# где этого файла нет.
provider "yandex" {}
