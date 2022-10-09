output "alb_domain_name" {
  value = module.alb.this_lb_dns_name
}

output "notification_domain_name" {
  value = aws_lb.this[0].dns_name
}
