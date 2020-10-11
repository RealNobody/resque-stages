# frozen_string_literal: true

require "rails_helper"

RSpec.describe "groups.erb" do
  let(:group_list) { Resque::Plugins::Stages::StagedGroupList.new }
  let(:descriptions) { Array.new(5) { Faker::Lorem.sentence } }
  let!(:groups) do
    descriptions.map do |description|
      Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid, description: description)
    end
  end

  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  context "actions" do
    before(:each) do
      allow(Resque::Plugins::Stages::StagedGroupList).to receive(:new).and_return group_list
      allow(group_list).to receive(:delete_all)
      allow(Resque::Plugins::Stages::Cleaner).to receive(:purge_all)
      allow(Resque::Plugins::Stages::Cleaner).to receive(:cleanup_jobs)
    end

    it "should respond to /stages/delete_all_groups" do
      post "/stages/delete_all_groups"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/stages$/)
      expect(group_list).to have_received(:delete_all)
    end

    it "should respond to /stages/purge_all" do
      post "/stages/purge_all"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/stages$/)
      expect(Resque::Plugins::Stages::Cleaner).to have_received(:purge_all)
    end

    it "should respond to /stages/cleanup_jobs" do
      post "/stages/cleanup_jobs"

      expect(last_response).to be_redirect
      expect(last_response.header["Location"]).to match(/stages$/)
      expect(Resque::Plugins::Stages::Cleaner).to have_received(:cleanup_jobs)
    end
  end

  it "should respond to /stages" do
    get "/stages"

    expect(last_response).to be_ok

    expect(last_response.body).to match %r{action="/stages/delete_all_groups"}
    expect(last_response.body).to match %r{action="/stages/purge_all"}
    expect(last_response.body).to match %r{action="/stages/cleanup_jobs"}

    expect(last_response.body).to match %r{&sort=description">(\n *)?Description\n +</a>}
    expect(last_response.body).to match %r{&sort=num_stages">(\n *)?Num Stages\n +</a>}
    expect(last_response.body).to match %r{&sort=created_at">(\n *)?Created\n +</a>}

    groups.each do |group|
      expect(last_response.body).to match %r{#{group.description}\n +</a>}
      expect(last_response.body).to match %r{/group_stages_list\?#{{ group_id: group.group_id }.to_param.gsub("+", "\\\\+")}}
    end
  end

  it "pages queues" do
    get "/stages?page_size=2"

    expect(last_response).to be_ok

    expect(last_response.body).to match(%r{href="/stages?.*page_num=2})
    expect(last_response.body).to match(%r{href="/stages?.*page_num=3})
    expect(last_response.body).not_to match(%r{href="/stages?.*page_num=4})
  end
end
