# Work In Progress: eBay Integration

## Project Overview

**Goal**: Pivot from Shopify-first to eBay-first marketplace integration while maintaining existing Shopify functionality.

**Status**: Planning phase completed, ready for implementation

## Background

The application currently has a working Shopify integration with:
- OAuth authentication flow
- Product publishing/updating/removal
- Order synchronization via webhooks
- External account and product management

We need to add eBay integration using the same architectural patterns while making the system flexible enough to support both marketplaces simultaneously.

## Research Findings

### eBay Ruby Gem
**Selected**: `ebay-ruby` by hakanensari
- Supports OAuth authentication
- Covers Browse, Finding, Merchandising, and Shopping APIs
- Actively maintained on GitHub
- Clean, developer-friendly interface

### Current Architecture Analysis

**Existing Models**:
- `ExternalAccount` - hardcoded to only support "shopify"
- `ExternalAccountProduct` - hardcoded to use Shopify service
- `Shopify` service class - handles all Shopify API operations
- `ShopifyAuthentication` - OAuth flow management

**Key Files**:
- `app/models/external_account.rb:2` - SERVICE_NAMES limited to shopify
- `app/models/external_account_product.rb:11` - hardcoded Shopify service usage
- `app/models/shopify.rb` - Shopify API wrapper
- `app/services/shopify_authentication.rb` - OAuth implementation

## Implementation Plan

### Phase 1: Architecture Foundation
1. **Add ebay-ruby gem** to Gemfile
2. **Update ExternalAccount model** to support "ebay" in SERVICE_NAMES
3. **Create BaseExternalService** abstract class with common interface
4. **Refactor Shopify service** to inherit from BaseExternalService

### Phase 2: eBay Integration
5. **Create Ebay service class** implementing BaseExternalService interface
6. **Create EbayAuthentication service** for OAuth flow
7. **Add eBay credentials** to Rails credentials
8. **Update ExternalAccountProduct** to use service factory pattern

### Phase 3: Testing & Validation
9. Test both Shopify and eBay integrations work independently
10. Test mixed scenarios (accounts with both marketplaces)
11. Ensure existing Shopify functionality remains intact

## Detailed Implementation Strategy

### Service Factory Pattern
```ruby
# app/services/external_service_factory.rb
class ExternalServiceFactory
  def self.for(external_account)
    case external_account.service_name
    when 'shopify'
      Shopify.new(...)
    when 'ebay'
      Ebay.new(...)
    end
  end
end
```

### Base Service Interface
```ruby
# app/services/base_external_service.rb
class BaseExternalService
  def initialize(external_account:)
    # Common initialization
  end

  def publish_product(product_params)
    raise NotImplementedError
  end

  def remove_product(product_id)
    raise NotImplementedError
  end

  def get_products
    raise NotImplementedError
  end
end
```

### eBay Service Structure
- OAuth client credentials flow for authentication
- Product publishing using eBay Browse/Trading APIs
- Error handling and token refresh
- Mapping between local product structure and eBay requirements

### Authentication Flow Changes
- Extend authentication controller to handle multiple service types
- Separate authentication services for each marketplace
- Consistent OAuth state management across services

## Technical Challenges Expected

1. **eBay OAuth Flow**: Different from Shopify's flow, needs separate implementation
2. **API Mapping**: eBay's product structure may differ from Shopify's
3. **Field Requirements**: eBay may have different required/optional fields
4. **Error Handling**: Each API has different error formats and retry logic
5. **Testing**: Need to ensure both integrations work without conflicts

## Success Criteria

- [x] Research completed
- [x] Architecture designed
- [ ] eBay gem integrated
- [ ] Base service classes created
- [ ] eBay service implemented
- [ ] eBay authentication working
- [ ] ExternalAccountProduct refactored
- [ ] Both marketplaces working simultaneously
- [ ] Existing Shopify functionality preserved
- [ ] Tests passing

## Next Steps

1. Start with adding the ebay-ruby gem
2. Update ExternalAccount model to support eBay
3. Create base service architecture
4. Implement eBay-specific services
5. Test integration thoroughly

## Notes

- Maintain backward compatibility with existing Shopify integration
- Use consistent patterns between Shopify and eBay implementations
- Keep authentication flows separate but follow similar patterns
- Focus on eBay as primary marketplace while preserving Shopify functionality