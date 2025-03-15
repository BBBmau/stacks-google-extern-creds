resource "google_storage_bucket" "stacks_oidc_bucket" {
  name = "stacks-oidc-bucket"
  location = "EU"
}