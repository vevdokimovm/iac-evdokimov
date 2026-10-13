output "lb_url" {
  description = "адрес балансировщика"
  # слушатель и его внешний адрес описаны множествами, по индексу не взять:
  # разворачиваем циклом и берём единственное значение
  value = "http://${one(flatten([
    for l in yandex_lb_network_load_balancer.lb.listener : [
      for spec in l.external_address_spec : spec.address
    ]
  ]))}"
}

output "web_ips" {
  description = "публичные адреса веб-серверов"
  value       = yandex_compute_instance.web[*].network_interface.0.nat_ip_address
}
