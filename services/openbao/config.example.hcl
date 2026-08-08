# example single-node shaped config. ha nodes live under ha-openbao/primary/node-N/config/
# copy ideas from here; do not run this file as-is on a 3-node cluster without editing addresses.

ui = true
disable_mlock = true
log_level = "info"

# advertise addresses other nodes / clients use
api_addr     = "http://192.168.1.11:8200"
cluster_addr = "http://192.168.1.11:8201"

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

storage "raft" {
  path    = "/openbao/data"
  node_id = "openbao-node-1"

  # on node 1 you can omit retry_join until peers exist, or list peers anyway
  retry_join {
    leader_api_addr = "http://192.168.1.12:8200"
  }
  retry_join {
    leader_api_addr = "http://192.168.1.13:8200"
  }
}

# later: auto-unseal example (do not enable until you mean it)
# seal "transit" {
#   address         = "http://127.0.0.1:8100"
#   token           = "s.example"
#   disable_renewal = "false"
#   key_name        = "autounseal"
#   mount_path      = "transit/"
# }
