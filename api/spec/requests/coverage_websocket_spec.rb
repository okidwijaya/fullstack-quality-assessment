require 'rails_helper'

RSpec.describe CoverageWebsocketMiddleware, type: :request do
  let(:tenant) do
    Organization.create!(
      name: 'Coverage WebSocket Tenant',
      scheme: 'coverage-websocket-test',
      identifier: 'coverage-websocket-test',
      host: 'coverage-websocket-test.example.com'
    )
  end

  let(:assessor) { create(:user, role: 'admin') }

  let(:session) do
    assessment = Assessment.unscoped.create!(
      tenant_id: tenant.id,
      created_by: assessor.id,
      name: 'Coverage WebSocket assessment',
      time_limit_min: 30
    )

    Session.unscoped.create!(tenant_id: tenant.id, assessment_id: assessment.id)
  end

  it 'rejects a valid same-tenant JWT with a role outside the assessor allowlist' do
    user = create(:user, role: 'user')
    token = JsonWebToken.encode(
      user_id: user.id,
      role: user.role,
      scheme: tenant.scheme
    )
    middleware, socket, callbacks = open_coverage_socket(session.id)

    expect(middleware).not_to receive(:send_current_state)
    expect(middleware).not_to receive(:subscribe_to_coverage_updates)
    expect(socket).to receive(:send) do |payload|
      expect(JSON.parse(payload)).to include(
        'type' => 'error',
        'code' => 'auth_failed'
      )
    end
    expect(socket).to receive(:close)

    callbacks.fetch(:message).call(
      double(data: { type: 'auth', token: token }.to_json)
    )
  end

  it 'accepts an admin JWT for a session in the same tenant' do
    token = JsonWebToken.encode(
      user_id: assessor.id,
      role: assessor.role,
      scheme: tenant.scheme
    )
    middleware, socket, callbacks = open_coverage_socket(session.id)

    expect(middleware).to receive(:send_current_state).with(socket, session)
    expect(middleware).to receive(:subscribe_to_coverage_updates)
      .with(socket, session.id.to_s)
      .and_return(:subscription)
    expect(socket).not_to receive(:send)
    expect(socket).not_to receive(:close)

    callbacks.fetch(:message).call(
      double(data: { type: 'auth', token: token }.to_json)
    )
  end

  def open_coverage_socket(session_id)
    env = Rack::MockRequest.env_for(
      "/ws/sessions/#{session_id}/coverage",
      'HTTP_UPGRADE' => 'websocket',
      'HTTP_CONNECTION' => 'Upgrade'
    )
    socket = double('Faye WebSocket', rack_response: [101, {}, []])
    callbacks = {}
    middleware = described_class.new(double('Rack app'))

    allow(Faye::WebSocket).to receive(:websocket?).with(env).and_return(true)
    allow(Faye::WebSocket).to receive(:new).and_return(socket)
    allow(socket).to receive(:on) do |event, &callback|
      callbacks[event] = callback
    end
    allow(middleware).to receive(:send_current_state)
    allow(middleware).to receive(:subscribe_to_coverage_updates)
      .and_return(:subscription)

    middleware.call(env)
    callbacks.fetch(:open).call(nil)

    [middleware, socket, callbacks]
  end
end