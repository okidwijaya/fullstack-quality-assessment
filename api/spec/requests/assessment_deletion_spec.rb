require 'rails_helper'

RSpec.describe 'Assessment deletion API', type: :request do
  let(:tenant) do
    Organization.create!(
      name: 'Assessment deletion tenant',
      scheme: 'assessment-deletion-test',
      identifier: 'assessment-deletion-test',
      host: 'assessment-deletion-test.example.com'
    )
  end
  let(:admin) { create(:user, role: 'admin') }
  let(:headers) do
    token = JsonWebToken.encode(
      user_id: admin.id,
      role: 'admin',
      scheme: tenant.scheme
    )
    { 'Authorization' => "Bearer #{token}" }
  end

  it 'returns an error and preserves an assessment with dependent sessions' do
    assessment = create_assessment
    Session.unscoped.create!(
      tenant_id: tenant.id,
      assessment_id: assessment.id
    )

    delete "/api/v1/assessments/#{assessment.id}", headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(Assessment.unscoped.exists?(assessment.id)).to be(true)
  end

  it 'deletes an assessment without dependent sessions' do
    assessment = create_assessment

    delete "/api/v1/assessments/#{assessment.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(Assessment.unscoped.exists?(assessment.id)).to be(false)
  end

  def create_assessment
    Assessment.unscoped.create!(
      tenant_id: tenant.id,
      created_by: admin.id,
      name: 'Assessment deletion test',
      time_limit_min: 30
    )
  end
end