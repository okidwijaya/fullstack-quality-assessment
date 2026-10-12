require 'rails_helper'

RSpec.describe 'Health API', type: :request do
  describe 'GET /api/v1/health' do
    it 'returns a healthy status' do
      get '/api/v1/health'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq('status' => 'ok')
    end
  end
end

# require 'rails_helper'

# RSpec.describe 'Health API', type: :request do
#   describe 'GET /api/v1/health' do
#     it 'returns a healthy status' do
#       get '/api/v1/health'

#       expect(response).to have_http_status(:ok)
#       expect(response.content_type).to include('application/json')
#       expect(JSON.parse(response.body)).to eq('status' => 'ok')
#     end
#   end
# end
