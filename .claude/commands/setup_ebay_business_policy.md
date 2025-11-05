---
description: Set up a new eBay business policy type (payment, return, etc.)
argument-hint: [policy-type]
---

# Set up eBay Business Policy: $type

Create a new eBay business policy type following the established pattern.

**What to use:**
- `EbayBusinessPolicy` model (already supports all types)
- `EbayApiClient` for API calls
- Copy fulfillment_policies controller/views as template
- Set `policy_type: '$type'`
- eBay endpoint: `/sell/account/v1/$type_policy`

**What NOT to do:**
- Don't create new database tables → Use existing `EbayBusinessPolicy` model
- Don't store detailed policy data locally → Store only eBay policy ID, use eBay API for details
- Don't hardcode policy options → Fetch from eBay API or use fallback approach like shipping services

**Quick Steps:**
1. Add routes: `resources :$type_policies, only: [:new, :create]`
2. Generate controller: `rails generate controller ${type}Policies new create --skip-routes`
3. Copy fulfillment_policies controller pattern, update `policy_type: '$type'`
4. Add `create_$type_policy` method to `EbayApiClient`
5. Copy views and update form fields for $1-specific options