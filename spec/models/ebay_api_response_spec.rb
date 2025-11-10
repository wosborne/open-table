require 'rails_helper'

RSpec.describe EbayApiResponse, type: :model do
  describe '#initialize' do
    it 'sets all required attributes' do
      response = described_class.new(
        success: true,
        status_code: 200,
        data: { id: '123' },
        error: nil,
        detailed_errors: []
      )

      expect(response.success).to be true
      expect(response.status_code).to eq(200)
      expect(response.data).to eq({ id: '123' })
      expect(response.error).to be_nil
      expect(response.detailed_errors).to eq([])
    end

    it 'sets defaults for optional attributes' do
      response = described_class.new(success: false, status_code: 400)

      expect(response.success).to be false
      expect(response.status_code).to eq(400)
      expect(response.data).to be_nil
      expect(response.error).to be_nil
      expect(response.detailed_errors).to eq([])
    end

    it 'accepts error data' do
      error_data = { message: 'Invalid request' }
      detailed_errors = [{ error_id: 123, message: 'Field required' }]

      response = described_class.new(
        success: false,
        status_code: 400,
        error: error_data,
        detailed_errors: detailed_errors
      )

      expect(response.error).to eq(error_data)
      expect(response.detailed_errors).to eq(detailed_errors)
    end
  end

  describe '#success?' do
    it 'returns true when success is true' do
      response = described_class.new(success: true, status_code: 200)
      expect(response.success?).to be true
    end

    it 'returns false when success is false' do
      response = described_class.new(success: false, status_code: 400)
      expect(response.success?).to be false
    end
  end

  describe '#failure?' do
    it 'returns false when success is true' do
      response = described_class.new(success: true, status_code: 200)
      expect(response.failure?).to be false
    end

    it 'returns true when success is false' do
      response = described_class.new(success: false, status_code: 400)
      expect(response.failure?).to be true
    end
  end

  describe '#code' do
    it 'returns the status code' do
      response = described_class.new(success: true, status_code: 201)
      expect(response.code).to eq(201)
    end

    it 'handles nil status code' do
      response = described_class.new(success: false, status_code: nil)
      expect(response.code).to be_nil
    end
  end

  describe '#body' do
    context 'when data is present' do
      it 'returns JSON string of data' do
        data = { id: '123', name: 'Test Policy' }
        response = described_class.new(success: true, status_code: 200, data: data)
        
        expect(response.body).to eq(data.to_json)
      end

      it 'handles complex nested data' do
        data = {
          policy: {
            id: '123',
            details: { name: 'Test', active: true },
            items: [1, 2, 3]
          }
        }
        response = described_class.new(success: true, status_code: 200, data: data)
        
        expect(response.body).to eq(data.to_json)
      end
    end

    context 'when data is nil' do
      it 'returns nil' do
        response = described_class.new(success: true, status_code: 204, data: nil)
        expect(response.body).to be_nil
      end
    end

    context 'when data is empty hash' do
      it 'returns empty JSON object' do
        response = described_class.new(success: true, status_code: 200, data: {})
        expect(response.body).to eq('{}')
      end
    end
  end

  describe '#error_messages' do
    context 'when detailed_errors is empty' do
      it 'returns empty array' do
        response = described_class.new(success: false, status_code: 400, detailed_errors: [])
        expect(response.error_messages).to eq([])
      end
    end

    context 'when detailed_errors contains messages' do
      it 'extracts long_message when available' do
        detailed_errors = [
          { error_id: 123, message: 'Short message', long_message: 'Long detailed message' },
          { error_id: 456, message: 'Another short message', long_message: 'Another long message' }
        ]
        response = described_class.new(success: false, status_code: 400, detailed_errors: detailed_errors)
        
        expect(response.error_messages).to eq(['Long detailed message', 'Another long message'])
      end

      it 'falls back to message when long_message is not available' do
        detailed_errors = [
          { error_id: 123, message: 'Short message' },
          { error_id: 456, message: 'Another message' }
        ]
        response = described_class.new(success: false, status_code: 400, detailed_errors: detailed_errors)
        
        expect(response.error_messages).to eq(['Short message', 'Another message'])
      end

      it 'uses default message when both are missing' do
        detailed_errors = [
          { error_id: 123 },
          { error_id: 456, severity: 'high' }
        ]
        response = described_class.new(success: false, status_code: 400, detailed_errors: detailed_errors)
        
        expect(response.error_messages).to eq(['Unknown error', 'Unknown error'])
      end

      it 'handles mixed message availability' do
        detailed_errors = [
          { error_id: 123, message: 'Short message', long_message: 'Long message' },
          { error_id: 456, message: 'Only short message' },
          { error_id: 789, severity: 'low' }
        ]
        response = described_class.new(success: false, status_code: 400, detailed_errors: detailed_errors)
        
        expect(response.error_messages).to eq(['Long message', 'Only short message', 'Unknown error'])
      end
    end
  end

  describe '#inspect' do
    it 'provides informative string representation with data keys' do
      data = { policy_id: '123', name: 'Test Policy', active: true }
      response = described_class.new(success: true, status_code: 200, data: data)
      
      expected = "#<EbayApiResponse success=true code=200 data_keys=#{data.keys}>"
      expect(response.inspect).to eq(expected)
    end

    it 'handles nil data gracefully' do
      response = described_class.new(success: false, status_code: 404, data: nil)
      
      expected = "#<EbayApiResponse success=false code=404 data_keys=>"
      expect(response.inspect).to eq(expected)
    end

    it 'handles empty data' do
      response = described_class.new(success: true, status_code: 204, data: {})
      
      expected = "#<EbayApiResponse success=true code=204 data_keys=[]>"
      expect(response.inspect).to eq(expected)
    end
  end

  describe 'real-world usage scenarios' do
    context 'successful eBay API response' do
      it 'models create policy success response' do
        data = {
          'fulfillmentPolicyId' => '123456789',
          'name' => 'UK Standard Shipping',
          'marketplaceId' => 'EBAY_GB',
          'categoryTypes' => [{ 'name' => 'ALL_EXCLUDING_MOTORS_VEHICLES', 'default' => true }]
        }

        response = described_class.new(success: true, status_code: 201, data: data)

        expect(response.success?).to be true
        expect(response.failure?).to be false
        expect(response.status_code).to eq(201)
        expect(response.data['fulfillmentPolicyId']).to eq('123456789')
        expect(response.data['name']).to eq('UK Standard Shipping')
        expect(response.error_messages).to be_empty
      end

      it 'models get policies success response' do
        data = {
          'fulfillmentPolicies' => [
            { 'fulfillmentPolicyId' => '111', 'name' => 'Policy 1' },
            { 'fulfillmentPolicyId' => '222', 'name' => 'Policy 2' }
          ],
          'total' => 2
        }

        response = described_class.new(success: true, status_code: 200, data: data)

        expect(response.success?).to be true
        expect(response.data['fulfillmentPolicies'].size).to eq(2)
        expect(response.data['total']).to eq(2)
      end
    end

    context 'failed eBay API response' do
      it 'models validation error response' do
        error_data = {
          'errors' => [
            {
              'errorId' => 25007,
              'domain' => 'API_ACCOUNT',
              'category' => 'REQUEST',
              'message' => 'Required field missing',
              'longMessage' => 'Required field shippingOptions is missing from the request'
            }
          ]
        }

        detailed_errors = [
          {
            error_id: 25007,
            domain: 'API_ACCOUNT',
            category: 'REQUEST',
            message: 'Required field missing',
            long_message: 'Required field shippingOptions is missing from the request',
            severity: 'high'
          }
        ]

        response = described_class.new(
          success: false,
          status_code: 400,
          error: error_data,
          detailed_errors: detailed_errors
        )

        expect(response.success?).to be false
        expect(response.failure?).to be true
        expect(response.status_code).to eq(400)
        expect(response.error['errors'].first['errorId']).to eq(25007)
        expect(response.error_messages).to eq(['Required field shippingOptions is missing from the request'])
      end

      it 'models authentication error response' do
        error_data = {
          'errors' => [
            {
              'errorId' => 1001,
              'message' => 'Invalid access token'
            }
          ]
        }

        detailed_errors = [
          {
            error_id: 1001,
            message: 'Invalid access token',
            severity: 'critical'
          }
        ]

        response = described_class.new(
          success: false,
          status_code: 401,
          error: error_data,
          detailed_errors: detailed_errors
        )

        expect(response.success?).to be false
        expect(response.status_code).to eq(401)
        expect(response.error_messages).to eq(['Invalid access token'])
      end

      it 'models network error response' do
        response = described_class.new(
          success: false,
          status_code: nil,
          error: 'Connection timeout',
          detailed_errors: []
        )

        expect(response.success?).to be false
        expect(response.status_code).to be_nil
        expect(response.error).to eq('Connection timeout')
        expect(response.error_messages).to be_empty
      end
    end
  end

  describe 'edge cases' do
    it 'handles string data' do
      response = described_class.new(success: true, status_code: 200, data: 'simple string')
      expect(response.body).to eq('"simple string"')
    end

    it 'handles array data' do
      data = [1, 2, 3, 'test']
      response = described_class.new(success: true, status_code: 200, data: data)
      expect(response.body).to eq(data.to_json)
    end

    it 'handles boolean data' do
      response = described_class.new(success: true, status_code: 200, data: false)
      expect(response.body).to eq('false')
    end

    it 'handles detailed_errors with symbol keys' do
      detailed_errors = [
        { error_id: 123, message: 'Test error' }
      ]
      response = described_class.new(success: false, status_code: 400, detailed_errors: detailed_errors)
      expect(response.error_messages).to eq(['Test error'])
    end

    it 'only extracts messages with symbol keys (not string keys)' do
      detailed_errors = [
        { 'error_id' => 123, 'message' => 'String key message' }
      ]
      response = described_class.new(success: false, status_code: 400, detailed_errors: detailed_errors)
      expect(response.error_messages).to eq(['Unknown error'])
    end
  end
end