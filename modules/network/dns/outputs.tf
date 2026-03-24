output "internal_zone_id" { value = aws_route53_zone.internal.zone_id }
output "resolver_inbound_endpoint_id" { value = aws_route53_resolver_endpoint.inbound.id }
output "resolver_inbound_ips" { value = aws_route53_resolver_endpoint.inbound.ip_address[*].ip }
output "resolver_outbound_endpoint_id" { value = aws_route53_resolver_endpoint.outbound.id }
