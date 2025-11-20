#!/bin/bash

# eBay Webhook Testing Script
# This script sends test notifications to the local webhook endpoint to verify it's working
#
# HOW TO USE:
# 1. Make sure your Rails server is running: rails server
# 2. Make the script executable: chmod +x test/fixtures/ebay_webhook_test.sh
# 3. Run the script: ./test/fixtures/ebay_webhook_test.sh
# 4. Check Rails logs to see notification processing details

BASE_URL="http://localhost:3000"

echo "🧪 Testing eBay Webhook Endpoints"
echo "================================="

# Test realistic eBay notification XML
echo "📦 Testing AuctionCheckoutComplete notification..."
curl -X POST "${BASE_URL}/webhooks/ebay/notifications" \
  -H "Content-Type: application/xml" \
  -H "X-EBAY-SIGNATURE: test-signature-xml-$(date +%s)" \
  -H "User-Agent: eBay/1.0" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
 <soapenv:Header>
  <ebl:RequesterCredentials soapenv:mustUnderstand="0" xmlns:ns="urn:ebay:apis:eBLBaseComponents" xmlns:ebl="urn:ebay:apis:eBLBaseComponents">
   <ebl:NotificationSignature xmlns:ebl="urn:ebay:apis:eBLBaseComponents">TEST_SIGNATURE_123==</ebl:NotificationSignature>
  </ebl:RequesterCredentials>
 </soapenv:Header>
 <soapenv:Body>
  <GetItemTransactionsResponse xmlns="urn:ebay:apis:eBLBaseComponents">
   <Timestamp>2025-11-17T09:15:33.456Z</Timestamp>
   <Ack>Success</Ack>
   <CorrelationID>9876543210987</CorrelationID>
   <Version>1423</Version>
   <Build>E1289_CORE_APIXO_19220561_R1</Build>
   <NotificationEventName>AuctionCheckoutComplete</NotificationEventName>
   <RecipientUserID>testuser_wosborne_test</RecipientUserID>
   <EIASToken>TEST_TOKEN_123==</EIASToken>
   <PaginationResult>
    <TotalNumberOfPages>1</TotalNumberOfPages>
    <TotalNumberOfEntries>1</TotalNumberOfEntries>
   </PaginationResult>
   <HasMoreTransactions>false</HasMoreTransactions>
   <TransactionsPerPage>100</TransactionsPerPage>
   <PageNumber>1</PageNumber>
   <ReturnedTransactionCountActual>1</ReturnedTransactionCountActual>
   <Item>
    <AutoPay>false</AutoPay>
    <BuyItNowPrice currencyID="USD">0.0</BuyItNowPrice>
    <Currency>USD</Currency>
    <ItemID>110588541086</ItemID>
    <ListingDetails>
     <StartTime>2025-11-15T14:30:15.000Z</StartTime>
     <EndTime>2025-12-15T14:30:15.000Z</EndTime>
    </ListingDetails>
    <ListingType>FixedPriceItem</ListingType>
    <Location>San Francisco</Location>
    <PrimaryCategory>
     <CategoryID>9355</CategoryID>
    </PrimaryCategory>
    <PrivateListing>false</PrivateListing>
    <Quantity>1</Quantity>
    <SecondaryCategory>
     <CategoryID>0</CategoryID>
    </SecondaryCategory>
    <Seller>
     <EIASToken>mY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6AElIOhDZmEqA2dj6x9nY+seQ==</EIASToken>
     <Email>test@phoneflipr.com</Email>
     <FeedbackScore>456</FeedbackScore>
     <PositiveFeedbackPercent>98.7</PositiveFeedbackPercent>
     <FeedbackPrivate>false</FeedbackPrivate>
     <eBayGoodStanding>true</eBayGoodStanding>
     <NewUser>false</NewUser>
     <RegistrationDate>2015-03-12T10:22:45.000Z</RegistrationDate>
     <Site>US</Site>
     <Status>Confirmed</Status>
     <UserID>testuser_wosborne_test</UserID>
     <UserIDChanged>false</UserIDChanged>
     <UserIDLastChanged>2021-08-15T16:42:18.000Z</UserIDLastChanged>
     <VATStatus>NoVATTax</VATStatus>
    </Seller>
    <SellingStatus>
     <ConvertedCurrentPrice currencyID="USD">899.99</ConvertedCurrentPrice>
     <CurrentPrice currencyID="USD">899.99</CurrentPrice>
     <QuantitySold>1</QuantitySold>
     <ListingStatus>Active</ListingStatus>
    </SellingStatus>
    <Site>US</Site>
    <StartPrice currencyID="USD">899.99</StartPrice>
    <Title>Test Phone 256GB Black (Unlocked) Grade A</Title>
    <SKU>TESTPHONE256GBBLACKGRADEA</SKU>
    <ConditionID>2010</ConditionID>
    <ConditionDisplayName>Like New - Refurbished</ConditionDisplayName>
   </Item>
   <TransactionArray>
    <Transaction>
     <AmountPaid currencyID="USD">899.99</AmountPaid>
     <AdjustmentAmount currencyID="USD">0.0</AdjustmentAmount>
     <ConvertedAdjustmentAmount currencyID="USD">0.0</ConvertedAdjustmentAmount>
     <Buyer>
      <EIASToken>nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4CjDJOCpQqdj6x9nY+seQ==</EIASToken>
      <Email>0098765abcd123def456@members.ebay.com</Email>
      <FeedbackScore>234</FeedbackScore>
      <PositiveFeedbackPercent>99.8</PositiveFeedbackPercent>
      <FeedbackPrivate>false</FeedbackPrivate>
      <IDVerified>true</IDVerified>
      <eBayGoodStanding>true</eBayGoodStanding>
      <NewUser>false</NewUser>
      <RegistrationDate>2018-07-22T11:45:18.000Z</RegistrationDate>
      <Site>US</Site>
      <Status>Confirmed</Status>
      <UserID>techbuyer2018</UserID>
      <UserIDChanged>false</UserIDChanged>
      <UserIDLastChanged>2018-07-22T11:47:33.000Z</UserIDLastChanged>
      <VATStatus>NoVATTax</VATStatus>
      <BuyerInfo>
       <ShippingAddress>
        <Name>Michael Rodriguez</Name>
        <Street1>123 Market Street</Street1>
        <Street2>Apt 4B</Street2>
        <CityName>San Francisco</CityName>
        <StateOrProvince>CA</StateOrProvince>
        <Country>US</Country>
        <CountryName>United States</CountryName>
        <Phone>4155551234</Phone>
        <PostalCode>94102</PostalCode>
        <AddressID>20004567890123</AddressID>
        <AddressOwner>eBay</AddressOwner>
       </ShippingAddress>
      </BuyerInfo>
      <UserAnonymized>false</UserAnonymized>
      <StaticAlias>0098765abcd123def456@members.ebay.com</StaticAlias>
      <UserFirstName>Michael</UserFirstName>
      <UserLastName>Rodriguez</UserLastName>
     </Buyer>
     <ShippingDetails>
      <SalesTax>
       <SalesTaxPercent>8.75</SalesTaxPercent>
       <ShippingIncludedInTax>false</ShippingIncludedInTax>
       <SalesTaxAmount currencyID="USD">78.75</SalesTaxAmount>
      </SalesTax>
      <ShippingServiceOptions>
       <ShippingService>USPSPriorityMail</ShippingService>
       <ShippingServiceCost currencyID="USD">15.99</ShippingServiceCost>
       <ShippingServicePriority>1</ShippingServicePriority>
       <ExpeditedService>false</ExpeditedService>
       <ShippingTimeMin>2</ShippingTimeMin>
       <ShippingTimeMax>3</ShippingTimeMax>
      </ShippingServiceOptions>
      <ShippingServiceOptions>
       <ShippingService>LocalPickup</ShippingService>
       <ShippingServiceCost currencyID="USD">0.0</ShippingServiceCost>
       <ShippingServicePriority>2</ShippingServicePriority>
       <ExpeditedService>false</ExpeditedService>
      </ShippingServiceOptions>
      <ShippingType>Flat</ShippingType>
      <SellingManagerSalesRecordNumber>7821</SellingManagerSalesRecordNumber>
      <ShippingServiceUsed>USPSPriorityMail</ShippingServiceUsed>
     </ShippingDetails>
     <ConvertedAmountPaid currencyID="USD">899.99</ConvertedAmountPaid>
     <ConvertedTransactionPrice currencyID="USD">899.99</ConvertedTransactionPrice>
     <CreatedDate>2025-11-17T09:15:32.000Z</CreatedDate>
     <DepositType>None</DepositType>
     <QuantityPurchased>1</QuantityPurchased>
     <Status>
      <eBayPaymentStatus>NoPaymentFailure</eBayPaymentStatus>
      <CheckoutStatus>CheckoutComplete</CheckoutStatus>
      <LastTimeModified>2025-11-17T09:15:32.000Z</LastTimeModified>
      <PaymentMethodUsed>PayPal</PaymentMethodUsed>
      <CompleteStatus>Complete</CompleteStatus>
      <BuyerSelectedShipping>true</BuyerSelectedShipping>
      <PaymentHoldStatus>None</PaymentHoldStatus>
      <InquiryStatus>NotApplicable</InquiryStatus>
      <ReturnStatus>NotApplicable</ReturnStatus>
      <PaymentInstrument>PayPal</PaymentInstrument>
     </Status>
     <TransactionID>10563728010</TransactionID>
     <TransactionPrice currencyID="USD">899.99</TransactionPrice>
     <BestOfferSale>false</BestOfferSale>
     <ShippingServiceSelected>
      <ShippingService>USPSPriorityMail</ShippingService>
      <ShippingServiceCost currencyID="USD">15.99</ShippingServiceCost>
      <ShippingPackageInfo>
       <EstimatedDeliveryTimeMin>2025-11-19T00:00:00.000Z</EstimatedDeliveryTimeMin>
       <EstimatedDeliveryTimeMax>2025-11-20T00:00:00.000Z</EstimatedDeliveryTimeMax>
      </ShippingPackageInfo>
     </ShippingServiceSelected>
     <PaidTime>2025-11-17T09:15:32.200Z</PaidTime>
     <ContainingOrder>
      <OrderID>30-14567-89012</OrderID>
      <OrderStatus>Completed</OrderStatus>
      <CancelStatus>NotApplicable</CancelStatus>
      <ExtendedOrderID>30-14567-89012</ExtendedOrderID>
      <ContainseBayPlusTransaction>false</ContainseBayPlusTransaction>
      <OrderLineItemCount>1</OrderLineItemCount>
     </ContainingOrder>
     <FinalValueFee currencyID="USD">89.99</FinalValueFee>
     <TransactionSiteID>US</TransactionSiteID>
     <Platform>eBay</Platform>
     <BuyerGuaranteePrice currencyID="USD">0.0</BuyerGuaranteePrice>
     <Taxes>
      <TotalTaxAmount currencyID="USD">78.75</TotalTaxAmount>
      <TaxDetails>
       <Imposition>SalesTax</Imposition>
       <TaxDescription>SalesTax</TaxDescription>
       <TaxAmount currencyID="USD">78.75</TaxAmount>
       <TaxOnSubtotalAmount currencyID="USD">78.75</TaxOnSubtotalAmount>
       <TaxOnShippingAmount currencyID="USD">0.0</TaxOnShippingAmount>
       <TaxOnHandlingAmount currencyID="USD">0.0</TaxOnHandlingAmount>
      </TaxDetails>
     </Taxes>
     <ActualShippingCost currencyID="USD">15.99</ActualShippingCost>
     <ActualHandlingCost currencyID="USD">0.0</ActualHandlingCost>
     <OrderLineItemID>110588541086-10563728010</OrderLineItemID>
     <IsMultiLegShipping>false</IsMultiLegShipping>
     <IntangibleItem>false</IntangibleItem>
     <MonetaryDetails>
      <Payments>
       <Payment>
        <PaymentStatus>Succeeded</PaymentStatus>
        <Payer type="eBayUser">techbuyer2018</Payer>
        <Payee type="eBayUser">phonefliprtester</Payee>
        <PaymentTime>2025-11-17T09:15:32.200Z</PaymentTime>
        <PaymentAmount currencyID="USD">899.99</PaymentAmount>
        <ReferenceID type="ExternalTransactionID">9988776655443</ReferenceID>
        <FeeOrCreditAmount currencyID="USD">0.0</FeeOrCreditAmount>
       </Payment>
      </Payments>
     </MonetaryDetails>
     <InventoryReservationID>10563728010</InventoryReservationID>
     <ExtendedOrderID>30-14567-89012</ExtendedOrderID>
     <eBayPlusTransaction>false</eBayPlusTransaction>
     <GuaranteedShipping>false</GuaranteedShipping>
     <eBayCollectAndRemitTax>true</eBayCollectAndRemitTax>
    </Transaction>
   </TransactionArray>
  </GetItemTransactionsResponse>
 </soapenv:Body>
</soapenv:Envelope>'

echo -e "\n\n✅ Webhook tests completed!"
echo "Check your Rails logs to see the notification processing details."
echo ""
echo "To view created notifications in Rails console:"
echo "  rails console"
echo "  Noticed::Event.last(5)"
echo "  # Or view notifications for an account:"
echo "  Account.first.notifications.last(5)"