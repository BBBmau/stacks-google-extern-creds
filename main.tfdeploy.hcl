identity_token "gcp" {
  audience = ["hcp.workload.identity"]
}

deployment "staging" {
  inputs = {
    identity_token = identity_token.gcp.jwt
  }
}