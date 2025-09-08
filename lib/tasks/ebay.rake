namespace :ebay do
  desc "Seed a default inventory location for eBay development"
  task seed_location: :environment do
    puts "Setting up eBay inventory location for development..."
    
    ebay_accounts = ExternalAccount.where(service_name: 'ebay')
    
    if ebay_accounts.empty?
      puts "❌ No eBay accounts found. Please authenticate with eBay first."
      exit 1
    end
    
    ebay_accounts.each do |account|
      service = EbayService.new(external_account: account)
      
      begin
        # Try to create location directly (checking locations might require different permissions)
        puts "🔄 Creating inventory location for account #{account.id}..."
        
        # Create default location
        location_data = {
          merchantLocationKey: "default_location_#{account.id}",
          name: "Default Location",
          location: {
            address: {
              addressLine1: "123 Main St",
              city: "Anytown",
              stateOrProvince: "CA",
              postalCode: "12345",
              country: "US"
            }
          },
          locationInstructions: "Default location for inventory management",
          phone: "555-123-4567",
          locationWebUrl: "https://example.com",
          operatingHours: [
            {
              dayOfWeekEnum: "MONDAY",
              intervals: [
                {
                  open: "09:00",
                  close: "17:00"
                }
              ]
            }
          ],
          specialHours: [],
          locationTypes: ["STORE"]
        }
        
        begin
          service.create_inventory_location(location_data)
          puts "✅ Created default inventory location for eBay account #{account.id}"
        rescue => location_error
          if location_error.message.include?("merchantLocationKey already exists")
            puts "ℹ️  Inventory location already exists for account #{account.id}"
          else
            raise location_error
          end
        end
        

        
      rescue => e
        puts "❌ Failed to create inventory location for account #{account.id}: #{e.message}"
      end
    end
    
    puts "🎉 eBay inventory location setup complete!"
  end
end