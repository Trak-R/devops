locals {
  name_prefix = "trakr-${var.environment}"

  tags = merge(
    {
      app         = "trakr"
      environment = var.environment
      managed_by  = "terraform"
    },
    var.extra_tags,
  )
}
