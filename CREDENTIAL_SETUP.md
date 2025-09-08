# eBay Credentials Setup

This document explains how to set up environment-specific eBay credentials for the application.

## Prerequisites

1. Create eBay Developer accounts for both Sandbox and Production
2. Generate application keys for each environment

## Setup Instructions

### 1. Development Environment (Sandbox)

```bash
EDITOR='code --wait' rails credentials:edit --environment=development
```

Copy and paste from `config/credentials/development.yml.template`, then replace with your actual sandbox credentials:

```yaml
ebay:
  api_base_url: "https://api.sandbox.ebay.com"
  client_id: "your_actual_sandbox_client_id"
  client_secret: "your_actual_sandbox_client_secret"
  redirect_url: "http://localhost:3000/ebay/callback"
```

### 2. Production Environment

```bash
EDITOR='code --wait' rails credentials:edit --environment=production
```

Copy and paste from `config/credentials/production.yml.template`, then replace with your actual production credentials:

```yaml
ebay:
  api_base_url: "https://api.ebay.com" 
  client_id: "your_actual_production_client_id"
  client_secret: "your_actual_production_client_secret"
  redirect_url: "https://yourdomain.com/ebay/callback"
```

### 3. Test Environment (Sandbox)

```bash
EDITOR='code --wait' rails credentials:edit --environment=test
```

Copy and paste from `config/credentials/test.yml.template`, then replace with your actual test credentials:

```yaml
ebay:
  api_base_url: "https://api.sandbox.ebay.com"
  client_id: "your_actual_test_client_id" 
  client_secret: "your_actual_test_client_secret"
  redirect_url: "http://localhost:3000/ebay/callback"
```

## Getting eBay Credentials

1. **Sandbox**: https://developer.ebay.com/my/keys
2. **Production**: https://developer.ebay.com/my/keys

Required scopes for your eBay application:
- `https://api.ebay.com/oauth/api_scope/sell.inventory`
- `https://api.ebay.com/oauth/api_scope/sell.account`
- `https://api.ebay.com/oauth/api_scope/sell.fulfillment`
- `https://api.ebay.com/oauth/api_scope/sell.marketing`

## Verification

After setting up credentials, you can verify they're working by checking in the Rails console:

```ruby
Rails.application.credentials.ebay.client_id
Rails.application.credentials.ebay.client_secret  
Rails.application.credentials.ebay.api_base_url
```

## Security Notes

- Never commit the actual credential files (`.yml.enc`) to version control
- The master keys for each environment should be stored securely
- Template files are safe to commit as they contain no actual credentials