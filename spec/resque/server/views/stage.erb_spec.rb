# frozen_string_literal: true

require "rails_helper"

RSpec.describe "groups.erb" do
  let(:group) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid) }
  let(:stage) { group.current_stage }
  let(:numbers) { Array.new(5) { |index| index } }
  let!(:jobs) do
    numbers.map do |number|
      stage.enqueue BasicJob, number
    end
  end

  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  context "actions" do
    before(:each) do
      allow(Resque::Plugins::Stages::StagedGroupStage).to receive(:new).and_return stage
      allow(stage).to receive(:delete)
      allow(stage).to receive(:initiate)
    end

    it "should respond to /stages/initiate_stage" do
      post "/stages/initiate_stage?group_stage_id=#{stage.group_stage_id}"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/stages$/)
      expect(stage).to have_received(:initiate)
    end

    it "should respond to /stages/delete_stage" do
      post "/stages/delete_stage?group_stage_id=#{stage.group_stage_id}"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/stages$/)
      expect(stage).to have_received(:delete)
    end
  end

  it "should respond to /stages/stage" do
    get "/stages/stage?group_stage_id=#{stage.group_stage_id}"

    expect(last_response).to be_ok

    expect(last_response.body).to match %r{action="/stages/delete_stage\?group_stage_id=#{stage.group_stage_id}"}
    expect(last_response.body).to match %r{action="/stages/initiate_stage\?group_stage_id=#{stage.group_stage_id}"}

    jobs.each do |job|
      expect(last_response.body).to match %r{#{job.class_name}\n +</a>}
      expect(last_response.body).to match %r{/stages/job_details\?#{{ job_id: job.job_id }.to_param.gsub("+", "\\\\+")}}
    end
  end

  it "pages queues" do
    get "/stages/stage?group_stage_id=#{stage.group_stage_id}&page_size=2"

    expect(last_response).to be_ok

    expect(last_response.body).to match(%r{href="/stages/stage?.*group_stage_id=#{stage.group_stage_id}.*page_num=2})
    expect(last_response.body).to match(%r{href="/stages/stage?.*group_stage_id=#{stage.group_stage_id}.*page_num=3})
    expect(last_response.body).not_to match(%r{href="/stages/stage?.*group_stage_id=#{stage.group_stage_id}.*page_num=4})
  end
end
