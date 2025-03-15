required_providers {
  google = {
    source = "hashicorp/google"
    version = "4.81.0"
  }
}

provider "google" "this" {
 
}

component "storage_buckets" {
    source = "./buckets"

    inputs = {
        jwt = identity_token.gcp.jwt
    }

    providers = {
        google    = provider.google.this
    }
}