# ============================================================================
# Logic App for Email Notifications
# ============================================================================
# This creates a Logic App that sends email alerts when validation fails/passes

resource "azurerm_logic_app_workflow" "email_notifications" {
  name                = "logic-hash-validation-email-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    environment = var.environment
    project     = "hash-validation"
    purpose     = "email-notifications"
  }
}

# Output the Logic App callback URL (will be available after manual configuration)
output "logic_app_name" {
  description = "Name of the Logic App for email notifications"
  value       = azurerm_logic_app_workflow.email_notifications.name
}

output "logic_app_id" {
  description = "Resource ID of the Logic App"
  value       = azurerm_logic_app_workflow.email_notifications.id
}
