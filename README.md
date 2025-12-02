# Database Management Platform

A Ruby on Rails 8 application providing funtionality similar to Notion's database table or Airtable. User can create custom tables with flexible property types and real-time updates via Hotwire.

The App was originally designed towards inventory management so new accounts start with a default Inventory table.

The project has since pivoted away from this approach but is in a less demo-able state than this repo.

## Features

- **Custom Tables**: Create tables with dynamic schemas
- **Property Types**: Text, number, date, select, checkbox, linked records, and formulas
- **Multiple Views**: Filter and customize column visibility
- **Real-time Updates**: Live UI updates with Hotwire
- **Multi-tenant**: Account-based workspaces

## Tech Stack

- Ruby on Rails 8
- PostgreSQL with JSONB for flexible data storage
- Hotwire (Turbo + Stimulus)
- Bulma CSS

## Getting Started

**Requirements**: Ruby 3.3.5

```bash
bundle install
rails db:create db:migrate
bin/dev
```

## Running Tests

```bash
rspec
```


**CSV Import Feature**: 
Users can create a new table using a csv import.
When creating a new table, upload a CSV file to automatically generate properties from headers and import all rows as records. The system creates text properties for each column.

Example CSV format:
```csv
Name,Price,Category,In Stock
iPhone 15,999,Electronics,Yes
MacBook Pro,2499,Electronics,No
Office Chair,299,Furniture,Yes
```
