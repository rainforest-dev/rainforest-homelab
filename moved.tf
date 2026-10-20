# library.rainforest.tools: the hall's catch-all took over the hostname's DNS record and Access
# application from the /notebooks entry. Moving them keeps one record and one application on
# the hostname through the apply instead of a destroy and a create of the same name.
moved {
  from = module.cloudflare_tunnel.cloudflare_record.services["library-notebooks"]
  to   = module.cloudflare_tunnel.cloudflare_record.services["library"]
}

moved {
  from = module.cloudflare_tunnel.cloudflare_zero_trust_access_application.services["library-notebooks"]
  to   = module.cloudflare_tunnel.cloudflare_zero_trust_access_application.services["library"]
}

moved {
  from = module.cloudflare_tunnel.cloudflare_zero_trust_access_policy.email_policy["library-notebooks"]
  to   = module.cloudflare_tunnel.cloudflare_zero_trust_access_policy.email_policy["library"]
}
