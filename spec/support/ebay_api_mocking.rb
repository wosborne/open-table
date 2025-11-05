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

  def mock_fulfillment_policies_response
    {
      success: true,
      status_code: 200,
      data: {
        "fulfillmentPolicies" => [
          {
            "fulfillmentPolicyId" => "123456789",
            "name" => "Standard Fulfillment",
            "marketplaceId" => "EBAY_GB"
          },
          {
            "fulfillmentPolicyId" => "987654321",
            "name" => "Express Fulfillment",
            "marketplaceId" => "EBAY_GB"
          }
        ]
      }
    }
  end

  def mock_payment_policies_response
    {
      success: true,
      status_code: 200,
      data: {
        "paymentPolicies" => [
          {
            "paymentPolicyId" => "111111111",
            "name" => "PayPal Payment",
            "marketplaceId" => "EBAY_GB"
          },
          {
            "paymentPolicyId" => "222222222",
            "name" => "Card Payment",
            "marketplaceId" => "EBAY_GB"
          }
        ]
      }
    }
  end

  def mock_return_policies_response
    {
      success: true,
      status_code: 200,
      data: {
        "returnPolicies" => [
          {
            "returnPolicyId" => "333333333",
            "name" => "30 Day Returns",
            "marketplaceId" => "EBAY_GB"
          },
          {
            "returnPolicyId" => "444444444",
            "name" => "No Returns",
            "marketplaceId" => "EBAY_GB"
          }
        ]
      }
    }
  end

  def stub_ebay_policy_fetching
    allow_any_instance_of(EbayApiClient).to receive(:get_fulfillment_policies)
      .and_return(mock_fulfillment_policies_response)
    allow_any_instance_of(EbayApiClient).to receive(:get_payment_policies)
      .and_return(mock_payment_policies_response)
    allow_any_instance_of(EbayApiClient).to receive(:get_return_policies)
      .and_return(mock_return_policies_response)
  end

  def mock_empty_policies_response
    {
      success: true,
      status_code: 200,
      data: {}
    }
  end

  def mock_policy_api_error
    {
      success: false,
      status_code: 400,
      error: "Failed to fetch policies"
    }
  end
end
