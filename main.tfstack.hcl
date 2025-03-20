required_providers {
  google = {
    source = "hashicorp/google"
    version = "6.10.0"
  }
  local_file = {
    source = "hashicorp/local-file"
    version = "2.4.0"
  }
}

provider "google" "this" {
  config {
    credentials = jsonencode(var.identity_token)
  }
}


variable "identity_token" {
  type = string
  ephemeral = true
}

component "storage_buckets" {
    source = "./buckets"

    providers = {
        google    = provider.google.this
    }
}

component "local_file" {
  source = "./local_file"

  providers = {
    local_file = provider.local_file.this
  }
}
