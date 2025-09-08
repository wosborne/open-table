# eBay Integration Setup

## Update Credentials

Your eBay redirect URL in credentials should now be:
```
redirect_url: http://localhost:3000/external_accounts/ebay_callback
```

For production, it would be:
```
redirect_url: https://yourdomain.com/external_accounts/ebay_callback
```

## What Changed

- Now using EbayAuthentication service with proper scopes for inventory management
- Callback route is now `/external_accounts/ebay_callback` (consistent with Shopify pattern)
- Requests all required eBay scopes including sell.inventory, sell.account, and sell.fulfillment
- Better error handling and token management

## Next Steps

1. Update your eBay Developer Console redirect URI to match the new callback URL
2. Update your credentials file with the new redirect_url
3. Test the integration in development