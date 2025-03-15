# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "tfc_audience" {
  type        = string
  default     = "hcp.workload.identity"
  description = "The audience value to use in run identity tokens"
}

variable "tfc_hostname" {
  type        = string
  default     = "app.terraform.io"
  description = "The hostname of the TFC or TFE instance you'd like to use with AWS"
}

variable "tfc_organization_name" {
  type        = string
  description = "The name of your Terraform Cloud organization"
}

variable "tfc_project_name" {
  type        = string
  description = "The project under which a stack will be created"
}

# Note - this value impacts the length of the assertion.sub, which needs to be <=127 bytes
# So, choose short names
variable "tfc_stack_name" {
  type        = string
  description = "The name of the stack to create"
  default     = "get-jwts"
}

variable "tfc_stack_deployment" {
  type        = string
  description = "Name of the stack deployment"
  default     = "demo"
}

#################################################################

provider "google" {
  region = "global"
}

provider "google-beta" {
  region = "global"
}

locals {
  # APIs required for the project
  gcp_service_list = [
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com"
  ]
}

data "google_project" "project" {
}

# Ensures the required services in the project are enabled
# Will not disable them when being destroyed
resource "google_project_service" "services" {
  for_each                   = toset(local.gcp_service_list)
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false
}

# Creates a workload identity pool to house a workload identity
# pool provider.
resource "google_iam_workload_identity_pool" "tfc_pool" {
  provider                  = google-beta
  workload_identity_pool_id = "stacks-oidc-${random_string.demo.result}"
}

# Creates an identity pool provider which uses an attribute condition
# to ensure that only the specified Terraform Cloud workspace will be
# able to authenticate to GCP using this provider.
#
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider
resource "google_iam_workload_identity_pool_provider" "tfc_provider" {
  provider                           = google-beta
  workload_identity_pool_id          = google_iam_workload_identity_pool.tfc_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "stacks-oidc-${random_string.demo.result}"
  attribute_mapping = {
    "google.subject"                            = "assertion.sub", # WARNING - this value is has to be <=127 bytes, and is "organization:<ORG NAME>:project:<PROJ NAME>:stack:<STACK NAME>:deployment:development:operation:plan
    "attribute.aud"                             = "assertion.aud",
    "attribute.terraform_operation"             = "assertion.terraform_operation",
    "attribute.terraform_project_id"            = "assertion.terraform_project_id",
    "attribute.terraform_project_name"          = "assertion.terraform_project_name",
    "attribute.terraform_stack_id"              = "assertion.terraform_stack_id",
    "attribute.terraform_stack_name"            = "assertion.terraform_stack_name",
    "attribute.terraform_stack_deployment_name" = "assertion.terraform_stack_deployment_name",
    "attribute.terraform_organization_id"       = "assertion.terraform_organization_id",
    "attribute.terraform_organization_name"     = "assertion.terraform_organization_name",
    "attribute.terraform_run_id"                = "assertion.terraform_run_id",
  }
  oidc {
    issuer_uri = "https://${var.tfc_hostname}"
    # The default audience format used by TFC is of the form:
    # //iam.googleapis.com/projects/{project number}/locations/global/workloadIdentityPools/{pool ID}/providers/{provider ID}
    # which matches with the default accepted audience format on GCP.
    #
    # Uncomment the line below if you are specifying a custom value for the audience instead of using the default audience.
    allowed_audiences = [var.tfc_audience]
  }
  attribute_condition = "assertion.sub.startsWith(\"organization:${var.tfc_organization_name}:project:${var.tfc_project_name}:stack\")"
}

# Creates a service account that will be used for authenticating to GCP. - aka the service account that TFC will be use to get authenticated for using GCP
#
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "tfc_service_account" {
  account_id   = "stacks-oidc-${random_string.demo.result}"
  display_name = "Terraform Cloud Service Account"
}

# Allows the service account to act as a workload identity user.
#
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account_iam
resource "google_service_account_iam_member" "tfc_service_account_member" {
  service_account_id = google_service_account.tfc_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.tfc_pool.name}/*"
}

# Updates the IAM policy to grant the service account permissions
# within the project.
#
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
resource "google_project_iam_member" "tfc_project_member" {
  project = data.google_project.project.id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.tfc_service_account.email}"
}
