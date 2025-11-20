# eBay Offer Creation Requirements

This document outlines all the requirements we've discovered for successfully creating eBay offers through the Inventory API, based on our implementation experience and troubleshooting.

## Overview

Creating an eBay offer involves multiple steps and prerequisites. Missing any of these will result in API errors that prevent listing creation.

## Prerequisites

### 1. eBay Account Setup

#### Developer Account Requirements
- eBay Developer account with Sandbox and Production keys
- Application credentials (Client ID, Client Secret, Dev ID)
- Proper redirect URLs configured

#### Business Policies Management
- **CRITICAL**: Must opt-in to the `SELLING_POLICY_MANAGEMENT` program via Account API
- Without this opt-in, business policy errors (25007, 25009) will occur
- Use `optInToProgram` call in Account API v1

#### Required Business Policies
Must create **all three** business policy types in eBay account:

1. **Fulfillment Policy (Shipping)**
   - At least one valid shipping service (e.g., Royal Mail 1st Class)
   - Shipping costs and handling time configured
   - **Error if missing**: 25007 - "Please add at least one valid postage service option"

2. **Payment Policy**
   - Accepted payment methods (PayPal, credit cards, etc.)
   - **Error if missing**: Business policy validation errors

3. **Return Policy**
   - Return acceptance period and conditions
   - Must include `ReturnsAcceptedOption` field
   - **Error if missing**: 25002 - "Please specify a valid return policy"

### 2. Authentication & Tokens

#### OAuth Flow Requirements
- Valid access token from eBay OAuth flow
- Refresh token for token renewal
- Proper scope permissions:
  - `https://api.ebay.com/oauth/api_scope/sell.inventory`
  - `https://api.ebay.com/oauth/api_scope/sell.account`
  - `https://api.ebay.com/oauth/api_scope/sell.fulfillment`
  - `https://api.ebay.com/oauth/api_scope/sell.marketing`
  - `https://api.ebay.com/oauth/api_scope/commerce.identity.readonly`

#### API Configuration
- Use `api.ebay.com` for all authentication (NOT country-specific domains)
- Marketplace targeting via `marketplaceId` parameter (e.g., `EBAY_GB`)
- Proper headers: `Authorization`, `Content-Type`, `Content-Language`, `Accept`

## API Call Sequence

### Step 1: Create Inventory Item
**Endpoint**: `PUT /sell/inventory/v1/inventory_item/{sku}`

#### Required Data Structure
```json
{
  "product": {
    "title": "Product Title",
    "description": "Product Description",
    "aspects": {
      "Colour": ["Green"],
      "Brand": ["Apple"],
      "Model": ["iPhone 16"],
      "Storage Capacity": ["256GB"]
    }
  },
  "condition": "USED_EXCELLENT",
  "availability": {
    "shipToLocationAvailability": {
      "quantity": 1
    }
  },
  "packageWeightAndSize": {
    "dimensions": {
      "height": 1,
      "length": 1,
      "width": 1,
      "unit": "CENTIMETER"
    },
    "weight": {
      "value": 1,
      "unit": "KILOGRAM"
    }
  }
}
```

#### Critical Requirements
- **Item Specifics (aspects)**: Required for most categories
  - `Colour` - **Always required** for most categories
  - `Model` - Required for electronics/phones
  - `Brand` - Often required
  - Category-specific attributes
- **Package Information**: Weight and dimensions required
- **Condition**: Must be valid eBay condition code
- **Quantity**: Must be > 0

#### Common Errors
- **25002**: Missing required item specifics (Colour, Model, etc.)
- **Validation errors**: Invalid condition codes, missing package info

### Step 2: Create Offer
**Endpoint**: `POST /sell/inventory/v1/offer`

#### Required Data Structure
```json
{
  "sku": "PRODUCT-SKU-123",
  "marketplaceId": "EBAY_GB",
  "format": "FIXED_PRICE",
  "pricingSummary": {
    "price": {
      "value": "100.00",
      "currency": "GBP"
    }
  },
  "listingDuration": "GTC",
  "categoryId": "9355",
  "merchantLocationKey": "default",
  "listingPolicies": {
    "fulfillmentPolicyId": "250997144010",
    "paymentPolicyId": "251468022010",
    "returnPolicyId": "251468025010"
  }
}
```

#### Critical Requirements
- **Business Policy IDs**: Must fetch and include all three policy types
- **Marketplace ID**: Correct marketplace (EBAY_GB, EBAY_US, etc.)
- **Category ID**: Valid eBay category for the product type
- **Currency**: Must match marketplace (GBP for UK, USD for US)
- **Merchant Location**: Must have default inventory location created

#### Common Errors
- **25007**: Missing or invalid fulfillment policy
- **25002**: Missing or invalid payment/return policy
- **25009**: Return policy data issues

### Step 3: Publish Offer
**Endpoint**: `POST /sell/inventory/v1/offer/{offerId}/publish`

#### Requirements
- Offer must exist and be unpublished
- All business policies must be valid and complete
- All required item specifics must be present
- Inventory location must be configured

## Dynamic Data Fetching

### Business Policy Retrieval
Since business policies are user-specific and can change, always fetch them dynamically:

```ruby
# Fetch policies for each offer creation
fulfillment_policies = get_fulfillment_policies()
payment_policies = get_payment_policies()  
return_policies = get_return_policies()

# Use first available policy of each type
fulfillment_policy_id = fulfillment_policies.first['fulfillmentPolicyId']
payment_policy_id = payment_policies.first['paymentPolicyId']
return_policy_id = return_policies.first['returnPolicyId']
```

**API Endpoints**:
- `GET /sell/account/v1/fulfillment_policy?marketplace_id=EBAY_GB`
- `GET /sell/account/v1/payment_policy?marketplace_id=EBAY_GB`
- `GET /sell/account/v1/return_policy?marketplace_id=EBAY_GB`

### Item Specifics Extraction
Extract from product variant data:
- Color from variant options
- Storage capacity from variant options or product name
- Brand/model from product name parsing
- Provide fallbacks: `["Not Specified"]` if none found

## Error Handling & Recovery

### Common Error Scenarios

#### Authentication Errors (401)
```json
{
  "errors": [{
    "errorId": 1001,
    "message": "Invalid access token"
  }]
}
```
**Solution**: Refresh access token using refresh token

#### Business Policy Errors (25007)
```json
{
  "errors": [{
    "errorId": 25007,
    "message": "Missing fulfillment policy data"
  }]
}
```
**Solution**: Ensure user has created policies and is opted into business policy management

#### Item Specifics Errors (25002)
```json
{
  "errors": [{
    "errorId": 25002,
    "message": "The item specific Colour is missing"
  }]
}
```
**Solution**: Add required aspects to inventory item

#### Rate Limiting (429)
```json
{
  "errors": [{
    "errorId": 1015,
    "message": "Call limit has been reached"
  }]
}
```
**Solution**: Implement exponential backoff retry

### Recovery Strategies

1. **Token Refresh**: Automatic retry with refreshed token
2. **Policy Fetching**: Re-fetch policies if they become invalid
3. **Offer Recreation**: Delete and recreate offers with missing data
4. **Graceful Degradation**: Provide meaningful error messages to users

## Implementation Notes

### API Call Flow
1. **Setup**: Ensure business policies exist and user is opted in
2. **Inventory Item**: Create with all required specifics and package info
3. **Offer Creation**: Include all business policies and marketplace data
4. **Publishing**: Final step to make listing live

### Data Management
- **Dynamic Policy Fetching**: Never cache policy IDs
- **Error Recovery**: Handle partial failures gracefully
- **State Tracking**: Maintain local records of eBay listing status

### Testing Considerations
- **Sandbox Environment**: Use for development and testing
- **Policy Prerequisites**: Ensure test accounts have required policies
- **Error Simulation**: Test all common error scenarios
- **Marketplace Variations**: Test different marketplaces (US, UK, etc.)

## Lessons Learned

1. **Business Policy Management is Critical**: Most errors stem from missing or invalid policies
2. **Item Specifics are Mandatory**: Categories have strict requirements for product attributes
3. **Dynamic Fetching is Essential**: User-specific data must be fetched fresh each time
4. **Error Messages are Helpful**: eBay provides detailed error information for debugging
5. **Marketplace Targeting**: Use global authentication but marketplace-specific parameters

## Success Criteria

An offer is successfully created when:
- ✅ HTTP 204 response from inventory item creation
- ✅ HTTP 201 response with `offerId` from offer creation  
- ✅ HTTP 200 response with `listingId` from offer publishing
- ✅ Local database record created successfully
- ✅ No business policy or item specific errors

## References

- [eBay Inventory API Documentation](https://developer.ebay.com/api-docs/sell/inventory/)
- [eBay Business Policies Guide](https://developer.ebay.com/api-docs/sell/static/seller-accounts/business-policies.html)
- [eBay Error Code Reference](https://developer.ebay.com/api-docs/sell/static/inventory/inventory-error-details.html)