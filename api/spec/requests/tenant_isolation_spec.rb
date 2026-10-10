require 'rails_helper'

RSpec.describe 'Tenant isolation API', type: :request do
  it 'does not export a portfolio belonging to another tenant' do
    tenant_a = Organization.create!(
      name: 'Tenant A',
      scheme: 'tenant-a-isolation-test',
      identifier: 'tenant-a-isolation-test',
      host: 'tenant-a-isolation-test.example.com'
    )
    tenant_b = Organization.create!(
      name: 'Tenant B',
      scheme: 'tenant-b-isolation-test',
      identifier: 'tenant-b-isolation-test',
      host: 'tenant-b-isolation-test.example.com'
    )
    assessor = create(:user, role: 'admin')

    same_tenant_assessment = Assessment.unscoped.create!(
      tenant_id: tenant_a.id,
      created_by: assessor.id,
      name: 'Tenant A assessment',
      time_limit_min: 30
    )
    same_tenant_session = Session.unscoped.create!(
      tenant_id: tenant_a.id,
      assessment_id: same_tenant_assessment.id
    )
    same_tenant_portfolio = Portfolio.create!(
      session: same_tenant_session,
      generation_status: 'complete'
    )

    assessment = Assessment.unscoped.create!(
      tenant_id: tenant_b.id,
      created_by: assessor.id,
      name: 'Tenant B assessment',
      time_limit_min: 30
    )
    session = Session.unscoped.create!(
      tenant_id: tenant_b.id,
      assessment_id: assessment.id
    )
    portfolio = Portfolio.create!(
      session: session,
      generation_status: 'complete'
    )
    token = JsonWebToken.encode(
      user_id: assessor.id,
      role: 'admin',
      scheme: tenant_a.scheme
    )

    get "/api/v1/portfolios/#{same_tenant_portfolio.id}/export",
        params: { format: 'json' },
        headers: { 'Authorization' => "Bearer #{token}" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig('portfolio', 'id')).to eq(same_tenant_portfolio.id)

    get "/api/v1/portfolios/#{portfolio.id}/export",
        params: { format: 'json' },
        headers: { 'Authorization' => "Bearer #{token}" }

    expect(response).to have_http_status(:not_found)
  end

  it 'does not allow an assessor to override a portfolio skill belonging to another tenant' do
    tenant_a = Organization.create!(
      name: 'Tenant A',
      scheme: 'tenant-a-skill-isolation-test',
      identifier: 'tenant-a-skill-isolation-test',
      host: 'tenant-a-skill-isolation-test.example.com'
    )
    tenant_b = Organization.create!(
      name: 'Tenant B',
      scheme: 'tenant-b-skill-isolation-test',
      identifier: 'tenant-b-skill-isolation-test',
      host: 'tenant-b-skill-isolation-test.example.com'
    )
    assessor = create(:user, role: 'admin')
    create_portfolio_skill = lambda do |tenant, skill_label|
      assessment = Assessment.unscoped.create!(
        tenant_id: tenant.id,
        created_by: assessor.id,
        name: "#{tenant.name} assessment",
        time_limit_min: 30
      )
      session = Session.unscoped.create!(
        tenant_id: tenant.id,
        assessment_id: assessment.id
      )
      portfolio = Portfolio.create!(
        session: session,
        generation_status: 'complete'
      )
      PortfolioSkill.create!(
        portfolio: portfolio,
        skill_label: skill_label,
        ai_level: 3,
        ai_confidence: 'medium',
        competency_summary: 'Demonstrated the skill in the interview.'
      )
    end
    same_tenant_skill = create_portfolio_skill.call(tenant_a, 'Tenant A skill')
    other_tenant_skill = create_portfolio_skill.call(tenant_b, 'Tenant B skill')
    token = JsonWebToken.encode(
      user_id: assessor.id,
      role: 'admin',
      scheme: tenant_a.scheme
    )
    headers = { 'Authorization' => "Bearer #{token}" }
    params = { override: { override_level: 4, assessor_notes: 'Verified control request' } }

    post "/api/v1/portfolio_skills/#{same_tenant_skill.id}/override",
         params: params,
         headers: headers

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body).dig('override', 'override_level')).to eq(4)

    post "/api/v1/portfolio_skills/#{other_tenant_skill.id}/override",
         params: params,
         headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it 'does not expose a fit-gap report belonging to another tenant' do
    tenant_a = Organization.create!(
      name: 'Tenant A',
      scheme: 'tenant-a-fitgap-isolation-test',
      identifier: 'tenant-a-fitgap-isolation-test',
      host: 'tenant-a-fitgap-isolation-test.example.com'
    )
    tenant_b = Organization.create!(
      name: 'Tenant B',
      scheme: 'tenant-b-fitgap-isolation-test',
      identifier: 'tenant-b-fitgap-isolation-test',
      host: 'tenant-b-fitgap-isolation-test.example.com'
    )
    assessor = create(:user, role: 'admin')
    create_fit_gap_report = lambda do |tenant|
      assessment = Assessment.unscoped.create!(
        tenant_id: tenant.id,
        created_by: assessor.id,
        name: "#{tenant.name} assessment",
        time_limit_min: 30
      )
      session = Session.unscoped.create!(
        tenant_id: tenant.id,
        assessment_id: assessment.id
      )
      portfolio = Portfolio.create!(
        session: session,
        generation_status: 'complete'
      )
      vacancy = Vacancy.unscoped.create!(
        tenant_id: tenant.id,
        created_by: assessor.id,
        role_title: "#{tenant.name} vacancy"
      )
      report = FitGapReport.create!(
        portfolio: portfolio,
        vacancy: vacancy,
        skill_comparisons: [{ skill_label: 'Example skill', result: 'match' }]
      )

      [portfolio, vacancy, report]
    end
    same_tenant_portfolio, same_tenant_vacancy, same_tenant_report = create_fit_gap_report.call(tenant_a)
    other_tenant_portfolio, other_tenant_vacancy, = create_fit_gap_report.call(tenant_b)
    token = JsonWebToken.encode(
      user_id: assessor.id,
      role: 'admin',
      scheme: tenant_a.scheme
    )
    headers = { 'Authorization' => "Bearer #{token}" }

    get "/api/v1/portfolios/#{same_tenant_portfolio.id}/fitgap/#{same_tenant_vacancy.id}",
        headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig('report', 'id')).to eq(same_tenant_report.id)

    get "/api/v1/portfolios/#{other_tenant_portfolio.id}/fitgap/#{other_tenant_vacancy.id}",
        headers: headers

    expect(response).to have_http_status(:not_found)
  end
end