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

  describe 'fit-gap generation tenant isolation' do
    it 'rejects fit-gap generation for a foreign portfolio without enqueueing work' do
      tenant_a = create_tenant('tenant-a-fitgap-generation-test')
      tenant_b = create_tenant('tenant-b-fitgap-generation-test')
      assessor = create(:user, role: 'admin')
      foreign_portfolio = create_portfolio(tenant_b, assessor)
      tenant_a_vacancy = create_vacancy(tenant_a, assessor)
      headers = authorization_headers(assessor, tenant_a)

      expect(FitGapGeneratorWorker).not_to receive(:perform_async)

      post "/api/v1/portfolios/#{foreign_portfolio.id}/fitgap",
           params: { fitgap: { vacancy_id: tenant_a_vacancy.id } },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects fit-gap regeneration for a foreign portfolio without enqueueing work' do
      tenant_a = create_tenant('tenant-a-fitgap-regeneration-test')
      tenant_b = create_tenant('tenant-b-fitgap-regeneration-test')
      assessor = create(:user, role: 'admin')
      foreign_portfolio = create_portfolio(tenant_b, assessor)
      tenant_a_vacancy = create_vacancy(tenant_a, assessor)
      headers = authorization_headers(assessor, tenant_a)

      expect(FitGapGeneratorWorker).not_to receive(:perform_async)

      post "/api/v1/portfolios/#{foreign_portfolio.id}/regenerate_fitgap",
           params: { vacancy_id: tenant_a_vacancy.id },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'queues generation for same-tenant portfolio and vacancy pairs' do
      tenant = create_tenant('tenant-same-fitgap-generation-test')
      assessor = create(:user, role: 'admin')
      portfolio = create_portfolio(tenant, assessor)
      vacancy = create_vacancy(tenant, assessor)
      headers = authorization_headers(assessor, tenant)

      expect(FitGapGeneratorWorker).to receive(:perform_async)
        .with(portfolio.id, vacancy.id).twice.and_return('job-id')

      post "/api/v1/portfolios/#{portfolio.id}/fitgap",
           params: { fitgap: { vacancy_id: vacancy.id } },
           headers: headers

      expect(response).to have_http_status(:accepted)

      post "/api/v1/portfolios/#{portfolio.id}/regenerate_fitgap",
           params: { vacancy_id: vacancy.id },
           headers: headers

      expect(response).to have_http_status(:accepted)
    end

    it 'does not invoke fit-gap generation for a portfolio and vacancy in different tenants' do
      tenant_a = create_tenant('tenant-a-fitgap-worker-test')
      tenant_b = create_tenant('tenant-b-fitgap-worker-test')
      assessor = create(:user, role: 'admin')
      foreign_portfolio = create_portfolio(tenant_b, assessor)
      tenant_a_vacancy = create_vacancy(tenant_a, assessor)

      expect(FitGap::Engine).not_to receive(:new)

      FitGapGeneratorWorker.new.perform(foreign_portfolio.id, tenant_a_vacancy.id)

      expect(
        FitGapReport.exists?(portfolio_id: foreign_portfolio.id, vacancy_id: tenant_a_vacancy.id)
      ).to be(false)
    end

    it 'invokes fit-gap generation for a same-tenant portfolio and vacancy' do
      tenant = create_tenant('tenant-same-fitgap-worker-test')
      assessor = create(:user, role: 'admin')
      portfolio = create_portfolio(tenant, assessor)
      vacancy = create_vacancy(tenant, assessor)
      engine = instance_double(FitGap::Engine, call: nil)

      expect(FitGap::Engine).to receive(:new)
        .with(portfolio: portfolio, vacancy: vacancy).and_return(engine)
      expect(engine).to receive(:call)

      FitGapGeneratorWorker.new.perform(portfolio.id, vacancy.id)
    end
  end

  def create_tenant(scheme)
    Organization.create!(
      name: scheme,
      scheme: scheme,
      identifier: scheme,
      host: "#{scheme}.example.com"
    )
  end

  def create_portfolio(tenant, assessor)
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
    Portfolio.create!(session: session, generation_status: 'complete')
  end

  def create_vacancy(tenant, assessor)
    Vacancy.unscoped.create!(
      tenant_id: tenant.id,
      created_by: assessor.id,
      role_title: "#{tenant.name} vacancy"
    )
  end

  def authorization_headers(assessor, tenant)
    token = JsonWebToken.encode(
      user_id: assessor.id,
      role: 'admin',
      scheme: tenant.scheme
    )
    { 'Authorization' => "Bearer #{token}" }
  end
end