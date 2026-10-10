require 'rails_helper'

RSpec.describe 'Rack::Attack rate limiting', type: :request do
  before do
    Rack::Attack.cache.store.clear
  end

  it 'throttles login requests after five requests from the same IP' do
    5.times do
      post '/api/v1/auth/login', params: {}
    end

    expect(response).not_to have_http_status(:too_many_requests)

    post '/api/v1/auth/login', params: {}

    expect(response).to have_http_status(:too_many_requests)

    body = JSON.parse(response.body)
    expect(body['error']).to eq(
      'Too many requests. Please try again later.'
    )
  end
end
