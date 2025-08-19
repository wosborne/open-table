# Phone Flipr - Inventory Management System

## Overview

Phone Flipr is a Rails-based inventory management system specifically designed for small startup sellers who focus on secondhand e-commerce, particularly on platforms like eBay and Shopify. The application has evolved from a general-purpose table management platform (similar to Airtable) into a specialized inventory management solution for entrepreneurs selling secondhand goods.

## Current Architecture

### Core Domain Models

#### Products & Variants System
- **Products** (`app/models/product.rb`): Main product catalog with up to 3 customizable options (size, color, condition, etc.)
- **Variants** (`app/models/variant.rb`): Specific product variations with unique SKUs and pricing
  - Auto-generates SKUs from product name + option values
  - Has versioning system using PaperTrail for SKU/price history
  - Prevents SKU changes after creation (except via regeneration)
- **Product Options & Values**: Flexible attribute system for product variations
- **Inventory Units** (`app/models/inventory_unit.rb`): Individual trackable items with serial numbers and status (in_stock, sold, reserved)

#### Order Management
- **Orders** (`db/schema.rb:154-166`): External orders from marketplaces
- **Order Line Items** (`db/schema.rb:139-152`): Individual items within orders, can be linked to inventory units
- Integration with external marketplaces via webhook system

#### External Marketplace Integration
- **External Accounts** (`app/models/external_account.rb`): OAuth connections to marketplaces (currently Shopify)
- **External Account Products**: Links between local products and marketplace listings
- **Shopify Integration** (`app/models/shopify.rb`, `app/services/shopify_authentication.rb`):
  - Full OAuth flow with refresh token support
  - Product publishing/updating/removal
  - Webhook handling for order synchronization
  - Automatic webhook registration

### Custom Tables System (Legacy/Secondary Feature)

The application retains its original flexible table system for users who need custom data structures:

- **Tables** (`app/models/table.rb`): User-created custom tables
- **Records** (`app/models/record.rb`): Rows within tables with JSON property storage
- **Properties** (`app/models/property.rb`): Column definitions with multiple types:
  - Text, Number, Date, Select, Checkbox
  - Linked Record (relationships between tables)
  - Formula (calculated fields)
  - ID (auto-incrementing with custom prefixes)
- **Views** (`db/schema.rb:297-306`): Different perspectives on table data with filtering
- **Links** (`db/schema.rb:127-137`): Relationships between records across tables

### User & Account Management
- **Multi-tenant architecture** with account-based data isolation
- **User authentication** via Devise
- **Account Users** join table for team collaboration

## Key Features

### Inventory Management
- Track individual items with serial numbers
- Product variant system with automatic SKU generation
- Inventory status tracking (in stock, sold, reserved)
- SKU versioning and history tracking
- Product option management (up to 3 options per product)

#### SKU Versioning & History Tracking
- **PaperTrail Integration**: Complete audit trail for all SKU and price changes
- **Smart Change Detection**: UI warnings when product option changes would affect existing SKUs
- **Version History**: Track SKU evolution with `sku_version_number`, `sku_history`, and `previous_sku` methods
- **Safe SKU Regeneration**: `regenerate_sku!` method for controlled SKU updates
- **User-Friendly Warnings**: Visual indicators in variant forms when changes will impact SKUs
- **History Modals**: Detailed SKU change history accessible via UI
- **Change Prevention**: Prevents accidental SKU modifications while allowing intentional regeneration

### Marketplace Integration
- Shopify OAuth integration with token refresh
- Automatic product publishing to external stores
- Order synchronization via webhooks
- External ID tracking for marketplace listings

### Custom Data Management
- Flexible table creation system
- Multiple property types including linked records
- Formula calculations
- Views and filtering system
- CSV import capabilities

### User Interface
- Rails views with Hotwire/Turbo for dynamic interactions
- Product management forms with variant generation
- Inventory unit creation with product/variant selection
- Custom table management interface

## Technical Implementation

### Key Technologies
- **Ruby on Rails 8.0** with PostgreSQL
- **Hotwire/Turbo** for dynamic UI updates
- **PaperTrail** for audit trails and versioning
- **ShopifyAPI** for marketplace integration
- **Devise** for authentication
- **JWT** for secure state management in OAuth flows

### Database Design
- PostgreSQL with JSONB for flexible property storage
- Foreign key constraints for data integrity
- Indexes on frequently queried fields
- Support for both structured (products/variants) and unstructured (custom tables) data

### Architecture Patterns
- Service objects for complex operations (Shopify integration)
- STI (Single Table Inheritance) for property types
- Polymorphic associations for external marketplace connections
- Webhook handling with HMAC verification

## Current Focus & Direction

### Primary Goal: eBay Integration
The application is pivoting to prioritize **eBay integration** as the primary marketplace, as it's more accessible for new entrepreneurs compared to Shopify. This represents the next major development priority.

### Target Users
- Small startup sellers focusing on secondhand goods
- Entrepreneurs selling on eBay and eventually Shopify
- Users who need both structured inventory management and flexible custom data tables

### Key Strengths
1. **Dual Architecture**: Combines structured inventory management with flexible custom tables
2. **Marketplace Ready**: Existing Shopify integration provides template for eBay integration
3. **Audit Trail**: Complete tracking of SKU changes and inventory movements
4. **Scalable**: Multi-tenant architecture supports business growth

### Development Priorities
1. **eBay API Integration**: OAuth, product listing, order synchronization
2. **Enhanced Inventory Features**: Better tracking for secondhand goods (condition, photos, etc.)
3. **Improved User Experience**: Streamlined workflows for common seller tasks
4. **Mobile Optimization**: Better mobile experience for on-the-go inventory management

## File Structure Highlights

### Core Models
- `app/models/product.rb` - Main product catalog
- `app/models/variant.rb` - Product variations with SKU management
- `app/models/inventory_unit.rb` - Individual trackable items
- `app/models/external_account.rb` - Marketplace connections

### Integration Layer
- `app/models/shopify.rb` - Shopify API wrapper
- `app/services/shopify_authentication.rb` - OAuth flow handling
- `app/controllers/shopify_webhooks_controller.rb` - Webhook processing

### Custom Tables
- `app/models/table.rb` - Custom table definitions
- `app/models/record.rb` - Flexible record storage
- `app/models/property.rb` - Column type definitions
- `app/models/properties/` - Specific property type implementations

### Controllers
- `app/controllers/products_controller.rb` - Product management
- `app/controllers/inventory_units_controller.rb` - Inventory tracking
- `app/controllers/tables_controller.rb` - Custom table management

This application successfully bridges the gap between a flexible data management platform and a specialized inventory management system, positioning it well for the secondhand e-commerce market while maintaining the flexibility that power users need for custom workflows.