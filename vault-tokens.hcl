# List available auth method
path "sys/auth" {
  capabilities = [ "read" ]
}

# Read default token configuration
path "sys/auth/token/tune" {
  capabilities = [ "read", "sudo" ]
}

# Create and manage tokens (renew, lookup, revoke, etc.)
path "auth/token/*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}

# For Advanced Features - list available secrets engines
path "sys/mounts" {
  capabilities = [ "read" ]
}

# For Advanced Features - tune the database secrets engine TTL
path "sys/mounts/database/tune" {
  capabilities = [ "update" ]
}