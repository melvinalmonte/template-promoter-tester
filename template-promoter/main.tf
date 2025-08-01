variable "commit_sha" {
  type        = string
  default     = ""
  description = "Optional commit SHA to mention in the template version."
}

variable "CUSTOM_TF_VARS" {
  type = list(object({
    name  = string
    value = string
  }))
  default     = []
  description = "Extra Terraform variables to add to every template."
}

locals {
  # discover template directories
  template_files       = fileset("${path.module}/../templates", "*/main.tf")
  template_directories = toset([for f in local.template_files : dirname(f)])

  # defaults that every template gets
  default_tf_vars = [
    { name = "namespace", value = "coder" }
  ]

  # merge defaults with custom vars
  all_tf_vars = concat(local.default_tf_vars, []) # List not set as provider will panic. 

  # metadata with fall-backs
  template_metadata = {
    for dir in local.template_directories : dir => try(
      jsondecode(file("${path.module}/../templates/${dir}/template.json")),
      {
        display_name = dir
        description  = "Template: ${dir}"
        icon         = "/emojis/1f4e6.png"
        tags         = []
        category     = "general"
      }
    )
  }
}

# ---------------------------------------------------------------------------
# resources
# ---------------------------------------------------------------------------

resource "coderd_template" "templates" {
  for_each = local.template_metadata

  name         = each.key
  display_name = each.value.display_name
  description  = each.value.description
  icon         = each.value.icon

  versions = [
    {
      name        = "${each.key}-${var.commit_sha}"
      description = var.commit_sha != "" ? "Deployed from commit: ${var.commit_sha}" : "Active version"
      directory   = "../templates/${each.key}"
      active      = true
      tf_vars     = local.all_tf_vars
    }
  ]
}

# ---------------------------------------------------------------------------
# outputs (for debugging)
# ---------------------------------------------------------------------------

output "deployed_templates" {
  description = "List of deployed templates with their metadata"
  value = {
    for k, t in coderd_template.templates : k => {
      display_name = t.display_name
      description  = t.description
      icon         = t.icon
    }
  }
}