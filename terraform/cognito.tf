# Cognito User Pool
resource "aws_cognito_user_pool" "ut_user_pool" {
  count               = var.enable_cognito ? 1 : 0
  name                = "UT-Platform-UserPool"
  deletion_protection = "ACTIVE"

  # Password Policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  # Auto-verified attributes
  auto_verified_attributes = ["email"]

  # Alias attributes (allow login with email)
  alias_attributes = ["email"]

  # Username configuration
  username_configuration {
    case_sensitive = false
  }

  # MFA Configuration
  mfa_configuration = "OFF"

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Verification message template
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  # Admin create user config
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  # Account recovery settings
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  # User attribute update settings
  user_attribute_update_settings {
    attributes_require_verification_before_update = []
  }

  # Schema attributes - only defining the required ones and custom ones
  # Standard attributes are included by default
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = "0"
      max_length = "2048"
    }
  }

}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "ut_user_pool_client" {
  count        = var.enable_cognito ? 1 : 0
  name         = "ut-platform-client"
  user_pool_id = aws_cognito_user_pool.ut_user_pool[0].id

  # Token validity
  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 5
  auth_session_validity  = 3

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Auth flows
  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # OAuth configuration
  supported_identity_providers = ["COGNITO"]

  callback_urls = [
    "https://${local.frontend_domain}/api/openid/callback"
  ]

  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = [
    "email",
    "openid",
    "phone",
    "profile"
  ]
  allowed_oauth_flows_user_pool_client = true

  # Security settings
  prevent_user_existence_errors                 = "LEGACY"
  enable_token_revocation                       = false
  enable_propagate_additional_user_context_data = false

  # Generate client secret
  generate_secret = true
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "ut_user_pool_domain" {
  count        = var.enable_cognito ? 1 : 0
  domain       = "ut-platform-${random_string.cognito_domain_suffix[0].result}"
  user_pool_id = aws_cognito_user_pool.ut_user_pool[0].id
}

# Random string for unique domain name
resource "random_string" "cognito_domain_suffix" {
  count   = var.enable_cognito ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

# Store Cognito configuration in Secrets Manager
resource "aws_secretsmanager_secret" "ut_cognito_config" {
  #checkov:skip=CKV2_AWS_57:Not Need for rotation here
  count                   = var.enable_cognito ? 1 : 0
  name                    = "ut-cognito-configuration"
  description             = "Cognito configuration for UT Platform"
  recovery_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            var.admin_role_arn,
            var.deployment_role_arn
          ]
        }
        Action   = "secretsmanager:*"
        Resource = "*"
      }
    ]
  })

}

resource "aws_secretsmanager_secret_version" "ut_cognito_config_version" {
  count     = var.enable_cognito ? 1 : 0
  secret_id = aws_secretsmanager_secret.ut_cognito_config[0].id
  secret_string = jsonencode({
    user_pool_id           = aws_cognito_user_pool.ut_user_pool[0].id
    client_id              = aws_cognito_user_pool_client.ut_user_pool_client[0].id
    client_secret          = aws_cognito_user_pool_client.ut_user_pool_client[0].client_secret
    domain                 = aws_cognito_user_pool_domain.ut_user_pool_domain[0].domain
    issuer_url             = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.ut_user_pool[0].id}"
    jwks_uri               = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.ut_user_pool[0].id}/.well-known/jwks.json"
    authorization_endpoint = "https://${aws_cognito_user_pool_domain.ut_user_pool_domain[0].domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/authorize"
    token_endpoint         = "https://${aws_cognito_user_pool_domain.ut_user_pool_domain[0].domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/token"
    userinfo_endpoint      = "https://${aws_cognito_user_pool_domain.ut_user_pool_domain[0].domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/userInfo"
  })
}
