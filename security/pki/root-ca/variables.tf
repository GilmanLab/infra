variable "aws_account_id" {
  description = "AWS account ID where the root CA KMS key is created."
  type        = string
  default     = "186067932323"
}

variable "aws_region" {
  description = "AWS region in which the root CA KMS key is created."
  type        = string
}

variable "key_alias" {
  description = "KMS alias for the root CA key, without the 'alias/' prefix."
  type        = string
  default     = "glab-pki-root-ca"
}

variable "key_spec" {
  description = "KMS customer_master_key_spec for the root CA key. Must be a SIGN_VERIFY-capable asymmetric key spec."
  type        = string
  default     = "ECC_NIST_P384"
}

variable "deletion_window_in_days" {
  description = "Pending deletion window, in days, when the key is scheduled for deletion. AWS allows 7-30; this stack defaults to the safest maximum."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags to merge onto all created resources."
  type        = map(string)
  default     = {}
}
