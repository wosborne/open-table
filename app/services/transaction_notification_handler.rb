class TransactionNotificationHandler
  def initialize(external_account)
    @external_account = external_account
  end

  def process(xml_body)
    parsed_data = parse_transaction_xml(xml_body)
    
    if parsed_data.nil?
      Rails.logger.error "Transaction handler: Failed to parse XML data"
      return
    end
    
    order = create_or_update_order(parsed_data)
    Rails.logger.info "eBay transaction processed: Order ##{order.name} - $#{order.total_price}"
    
    order
  rescue => e
    Rails.logger.error "Transaction handler failed: #{e.message}"
    raise e
  end

  private

  def parse_transaction_xml(xml_body)
    require 'nokogiri'
    doc = Nokogiri::XML(xml_body)
    
    # Extract transaction data
    transaction_id = doc.at_xpath("//xmlns:TransactionID", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
    item_id = doc.at_xpath("//xmlns:ItemID", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
    
    # Extract order data
    order_id = doc.at_xpath("//xmlns:ContainingOrder/xmlns:OrderID", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
    order_status = doc.at_xpath("//xmlns:ContainingOrder/xmlns:OrderStatus", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
    
    # Extract transaction details
    amount_paid = doc.at_xpath("//xmlns:AmountPaid", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
    currency = doc.at_xpath("//xmlns:AmountPaid/@currencyID", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
    transaction_price = doc.at_xpath("//xmlns:TransactionPrice", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
    
    # Extract item title for notification
    item_title = doc.at_xpath("//xmlns:Item/xmlns:Title", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
    
    # Extract payment status
    payment_status = doc.at_xpath("//xmlns:Status/xmlns:CheckoutStatus", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
    
    # Extract created date
    created_date = doc.at_xpath("//xmlns:CreatedDate", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
    
    if transaction_id.blank? || item_id.blank? || order_id.blank?
      Rails.logger.error "eBay transaction missing data - transaction_id: #{transaction_id}, item_id: #{item_id}, order_id: #{order_id}"
      return nil
    end

    {
      transaction_id: transaction_id,
      item_id: item_id,
      order_id: order_id,
      order_status: order_status,
      amount_paid: amount_paid,
      currency: currency,
      transaction_price: transaction_price,
      item_title: item_title,
      payment_status: payment_status,
      created_date: created_date
    }
  end

  def create_or_update_order(data)
    order = Order.find_or_initialize_by(
      external_account: @external_account,
      external_id: data[:order_id]
    )

    # Parse amount and convert to decimal
    total_price = data[:amount_paid]&.to_f || data[:transaction_price]&.to_f || 0.0
    
    # Parse created date
    external_created_at = data[:created_date] ? Time.parse(data[:created_date]) : Time.current

    order.assign_attributes(
      name: "##{data[:order_id]}",
      currency: data[:currency] || "USD",
      total_price: total_price,
      external_created_at: external_created_at,
      financial_status: map_financial_status(data[:payment_status]),
      payment_status: data[:payment_status],
      fulfillment_status: map_fulfillment_status(data[:order_status]),
      extra_details: build_order_extra_details(data)
    )

    order.save!
    order
  end


  def map_financial_status(payment_status)
    case payment_status
    when "CheckoutComplete"
      "paid"
    when "NoPaymentFailure"
      "paid"
    else
      "pending"
    end
  end

  def map_fulfillment_status(order_status)
    case order_status
    when "Completed"
      "fulfilled"
    when "Active"
      "unfulfilled"
    else
      "unfulfilled"
    end
  end

  def build_order_extra_details(data)
    {
      ebay_transaction_id: data[:transaction_id],
      ebay_item_id: data[:item_id],
      ebay_item_title: data[:item_title],
      ebay_order_status: data[:order_status],
      ebay_payment_status: data[:payment_status]
    }.compact.to_json
  end
end