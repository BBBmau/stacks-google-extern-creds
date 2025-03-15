identity_token "jwt" {
  audience = ["hcp.workload.identity"]
}

deployment "staging" {
  inputs = {
    jwt = identity_token.jwt.jwt
  }
}