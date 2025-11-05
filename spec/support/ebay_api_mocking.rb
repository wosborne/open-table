module EbayApiMocking
  def mock_ebay_api_responses
    allow_any_instance_of(EbayApiClient).to receive(:make_request).and_call_original
    allow_any_instance_of(EbayApiClient).to receive(:refresh_access_token).and_return(true)
  end

  def mock_successful_fulfillment_policy_creation
    {
      success: true,
      status_code: 201,
      data: {
        "fulfillmentPolicyId" => "12345678",
        "name" => "Test Fulfillment Policy",
        "marketplaceId" => "EBAY_GB",
        "categoryTypes" => [
          {
            "name" => "ALL_EXCLUDING_MOTORS_VEHICLES",
            "default" => true
          }
        ],
        "handlingTime" => {
          "value" => 1,
          "unit" => "DAY"
        },
        "shippingOptions" => [
          {
            "costType" => "FLAT_RATE",
            "shippingServices" => [
              {
                "shippingServiceCode" => "UK_RoyalMailFirstClassStandard",
                "freeShipping" => false,
                "shippingCost" => {
                  "value" => "2.50",
                  "currency" => "GBP"
                }
              }
            ]
          }
        ]
      }
    }
  end

  def mock_successful_payment_policy_creation
    {
      success: true,
      status_code: 201,
      data: {
        "paymentPolicyId" => "87654321",
        "name" => "Test Payment Policy",
        "marketplaceId" => "EBAY_GB",
        "categoryTypes" => [
          {
            "name" => "ALL_EXCLUDING_MOTORS_VEHICLES",
            "default" => true
          }
        ],
        "paymentMethods" => [
          {
            "paymentMethodType" => "PAYPAL",
            "recipientAccountReference" => {
              "referenceId" => "test@example.com",
              "referenceType" => "PAYPAL_EMAIL"
            }
          }
        ],
        "immediatePay" => true
      }
    }
  end

  def mock_successful_return_policy_creation
    {
      success: true,
      status_code: 201,
      data: {
        "returnPolicyId" => "11223344",
        "name" => "Test Return Policy",
        "marketplaceId" => "EBAY_GB",
        "categoryTypes" => [
          {
            "name" => "ALL_EXCLUDING_MOTORS_VEHICLES",
            "default" => true
          }
        ],
        "returnsAccepted" => true,
        "returnPeriod" => {
          "value" => 30,
          "unit" => "DAY"
        },
        "returnShippingCostPayer" => "BUYER",
        "returnMethod" => "REPLACEMENT"
      }
    }
  end

  def mock_api_error_response(error_code = 25001, message = "Required field missing")
    {
      success: false,
      status_code: 400,
      error: {
        "errors" => [
          {
            "errorId" => error_code,
            "domain" => "API_ACCOUNT",
            "subdomain" => "Selling",
            "category" => "REQUEST",
            "message" => message,
            "longMessage" => "The #{message.downcase} field is required for this operation.",
            "parameters" => [
              {
                "name" => "field_name",
                "value" => "name"
              }
            ]
          }
        ]
      },
      detailed_errors: [
        {
          error_id: error_code,
          domain: "API_ACCOUNT",
          subdomain: "Selling",
          category: "REQUEST",
          message: message,
          long_message: "The #{message.downcase} field is required for this operation.",
          parameters: [ { "name" => "field_name", "value" => "name" } ],
          severity: "high"
        }
      ]
    }
  end

  def mock_network_error_response
    {
      success: false,
      status_code: nil,
      error: "Connection timeout",
      error_type: "network_error",
      detailed_errors: []
    }
  end

  def mock_auth_error_response
    {
      success: false,
      status_code: 401,
      error: {
        "errors" => [
          {
            "errorId" => 1001,
            "domain" => "ACCESS",
            "category" => "REQUEST",
            "message" => "Invalid access token",
            "longMessage" => "The access token provided is invalid or has expired."
          }
        ]
      }
    }
  end

  def stub_ebay_fulfillment_policy_creation(response = nil)
    response ||= mock_successful_fulfillment_policy_creation
    allow_any_instance_of(EbayApiClient).to receive(:post)
      .with("/sell/account/v1/fulfillment_policy", anything)
      .and_return(response)
  end

  def stub_ebay_payment_policy_creation(response = nil)
    response ||= mock_successful_payment_policy_creation
    allow_any_instance_of(EbayApiClient).to receive(:post)
      .with("/sell/account/v1/payment_policy", anything)
      .and_return(response)
  end

  def stub_ebay_return_policy_creation(response = nil)
    response ||= mock_successful_return_policy_creation
    allow_any_instance_of(EbayApiClient).to receive(:post)
      .with("/sell/account/v1/return_policy", anything)
      .and_return(response)
  end
end
