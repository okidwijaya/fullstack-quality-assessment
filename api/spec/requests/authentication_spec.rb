require 'rails_helper'

RSpec.describe 'Authentication API', type: :request do
  before do
    Rack::Attack.cache.store.clear
  end

  describe 'POST /api/v1/auth/login' do
    let!(:admin) do
      create(
        :user,
        email: 'admin@example.com',
        password: 'Password123!',
        role: 'admin'
      )
    end

    it 'authenticates a valid admin user' do
      post '/api/v1/auth/login', params: {
        email: admin.email,
        password: 'Password123!'
      }

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)

      expect(body['token']).to be_present
      expect(body['user']).to include(
        'id' => admin.id,
        'email' => 'admin@example.com',
        'role' => 'admin'
      )
    end

    it 'rejects an incorrect password' do
      post '/api/v1/auth/login', params: {
        email: admin.email,
        password: 'WrongPassword!'
      }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects an unknown email' do
  post '/api/v1/auth/login', params: {
    email: 'unknown@example.com',
    password: 'Password123!'
  }

  expect(response).to have_http_status(:unauthorized)

  body = JSON.parse(response.body)

  expect(body.dig('errors', 0, 'message')).to eq(
    'Invalid email or password'
  )
end

    it 'rejects a non-admin user' do
      user = create(
        :user,
        email: 'user@example.com',
        password: 'Password123!',
        role: 'user'
      )

      post '/api/v1/auth/login', params: {
        email: user.email,
        password: 'Password123!'
      }

      expect(response).to have_http_status(:unauthorized)

      body = JSON.parse(response.body)

          expect(body.dig('errors', 0, 'message')).to eq(
        'Invalid email or password'
      )
    end

it 'authenticates an admin with uppercase email' do
  post '/api/v1/auth/login', params: {
    email: 'ADMIN@EXAMPLE.COM',
    password: 'Password123!'
  }

  expect(response).to have_http_status(:ok)

  body = JSON.parse(response.body)

  expect(body['token']).to be_present
  expect(body.dig('user', 'email')).to eq('admin@example.com')
end

it 'rejects a request with missing credentials' do
  post '/api/v1/auth/login', params: {}

  expect(response).to have_http_status(:unauthorized)

  body = JSON.parse(response.body)

  expect(body.dig('errors', 0, 'message')).to eq(
    'Invalid email or password'
  )
end
  end
end
