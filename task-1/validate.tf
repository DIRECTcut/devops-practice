# SSH Key Validation

locals {
  # Define valid SSH key type prefixes
  valid_ssh_prefixes = [
    "ssh-rsa",
    "ssh-dss",
    "ssh-ed25519",
    "ecdsa-sha2-nistp256",
    "ecdsa-sha2-nistp384",
    "ecdsa-sha2-nistp521"
  ]

  # Check if the key starts with a valid prefix
  ssh_key_parts   = split(" ", trim(var.ssh_public_key, " \n\r"))
  ssh_key_type    = length(local.ssh_key_parts) > 0 ? local.ssh_key_parts[0] : ""
  is_valid_prefix = contains(local.valid_ssh_prefixes, local.ssh_key_type)

  # Basic validation checks
  has_three_parts = length(local.ssh_key_parts) >= 2 # At least type and key
  has_key_data    = length(local.ssh_key_parts) > 1 ? length(local.ssh_key_parts[1]) > 20 : false
}

# Validation rules
resource "null_resource" "validate_ssh_key" {
  # This will fail during plan/apply if conditions aren't met
  lifecycle {
    precondition {
      condition     = length(trimspace(var.ssh_public_key)) > 0
      error_message = "SSH public key cannot be empty. Please provide a valid SSH public key."
    }

    precondition {
      condition     = local.is_valid_prefix
      error_message = "SSH public key must start with a valid type: ${join(", ", local.valid_ssh_prefixes)}. Got: '${local.ssh_key_type}'"
    }

    precondition {
      condition     = local.has_three_parts
      error_message = "SSH public key format is invalid. Expected format: 'ssh-type base64-key-data [comment]'"
    }

    precondition {
      condition     = local.has_key_data
      error_message = "SSH public key data appears to be too short or invalid."
    }

    # precondition {
    #   condition     = !can(regex("^(?:ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-ed25519|ssh-dss)\s+[A-Za-z0-9+/=]+\s+.*$", var.ssh_public_key))
    #   error_message = "SSH public key appears to be truncated (contains '....'). Please provide the complete key."
    # }
  }
}

# Output validation status (for debugging)
output "ssh_key_validation" {
  value = {
    key_type   = local.ssh_key_type
    is_valid   = local.is_valid_prefix && local.has_three_parts && local.has_key_data
    key_length = length(var.ssh_public_key)
  }
  description = "SSH key validation details"
}