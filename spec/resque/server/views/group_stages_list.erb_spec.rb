# frozen_string_literal: true

require "rails_helper"

RSpec.describe "groups.erb" do
  let(:group) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid) }
  let(:numbers) { Array.new(5) { |index| index } }
  let!(:stages) do
    numbers.map do |number|
      group.stage(number)
    end
  end

  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  context "actions" do
    before(:each) do
      allow(Resque::Plugins::Stages::StagedGroup).to receive(:new).and_return group
      allow(group).to receive(:delete)
      allow(group).to receive(:initiate)
    end

    it "should respond to /stages/initiate_group" do
      post "/stages/initiate_group?group_id=#{group.group_id}"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/stages$/)
      expect(group).to have_received(:initiate)
    end

    it "should respond to /stages/delete_group" do
      post "/stages/delete_group?group_id=#{group.group_id}"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/stages$/)
      expect(group).to have_received(:delete)
    end
  end

  it "should respond to /stages/group_stages_list" do
    get "/stages/group_stages_list?group_id=#{group.group_id}"

    expect(last_response).to be_ok

    expect(last_response.body).to match %r{action="/stages/delete_group\?group_id=#{group.group_id}"}
    expect(last_response.body).to match %r{action="/stages/initiate_group\?group_id=#{group.group_id}"}

    stages.each do |stage|
      expect(last_response.body).to match %r{#{stage.number}\n +</a>}
      expect(last_response.body).to match %r{/stages/stage\?#{{ group_stage_id: stage.group_stage_id }.to_param.gsub("+", "\\\\+")}}
    end
  end

  it "pages queues" do
    get "/stages/group_stages_list?group_id=#{group.group_id}&page_size=2"

    expect(last_response).to be_ok

    expect(last_response.body).to match(%r{href="/stages/group_stages_list?.*group_id=#{group.group_id}.*page_num=2})
    expect(last_response.body).to match(%r{href="/stages/group_stages_list?.*group_id=#{group.group_id}.*page_num=3})
    expect(last_response.body).not_to match(%r{href="/stages/group_stages_list?.*group_id=#{group.group_id}.*page_num=4})
  end
end
