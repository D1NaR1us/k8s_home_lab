path "kv/data/*" {
  capabilities = ["read"]
}

# home-media apps: sonarr/radarr init containers read postgres creds
path "kv/data/home-media/*" {
  capabilities = ["read"]
}
