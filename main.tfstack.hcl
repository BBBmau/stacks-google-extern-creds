required_providers {
  google = {
    source = "hashicorp/google"
    version = "4.81.0"
  }
}

provider "google" "this" {
 
}

variable "jwt" {
  type = string
}

component "storage_buckets" {
    source = "./buckets"

    inputs = {
        jwt = var.jwt
    }

    providers = {
        google    = provider.google.this
    }
}