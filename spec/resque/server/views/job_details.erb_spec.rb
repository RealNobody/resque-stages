# frozen_string_literal: true

require "rails_helper"

RSpec.describe "job_details.erb" do
  let(:group) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid) }
  let(:stage) { group.current_stage }
  let(:test_args) do
    rand_args = []
    rand_args << Faker::Lorem.sentence
    rand_args << Faker::Lorem.paragraph
    rand_args << SecureRandom.uuid.to_s
    rand_args << rand(0..1_000_000_000_000_000_000_000_000).to_s
    rand_args << rand(0..1_000_000_000_000).seconds.ago.to_s
    rand_args << rand(0..1_000_000_000_000).seconds.from_now.to_s
    rand_args << Array.new(rand(1..5)) { Faker::Lorem.word }
    rand_args << Array.new(rand(1..5)).each_with_object({}) do |_nil_value, sub_hash|
      sub_hash[Faker::Lorem.word] = Faker::Lorem.word
    end

    rand_args = rand_args.sample(rand(3..rand_args.length))

    if [true, false].sample
      options_hash                    = {}
      options_hash[Faker::Lorem.word] = Faker::Lorem.sentence
      options_hash[Faker::Lorem.word] = Faker::Lorem.paragraph
      options_hash[Faker::Lorem.word] = SecureRandom.uuid.to_s
      options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000_000_000_000_000).to_s
      options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000).seconds.ago.to_s
      options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000).seconds.from_now.to_s
      options_hash[Faker::Lorem.word] = Array.new(rand(1..5)) { Faker::Lorem.word }
      options_hash[Faker::Lorem.word] = Array.new(rand(1..5)).
          each_with_object({}) do |_nil_value, sub_hash|
        sub_hash[Faker::Lorem.word] = Faker::Lorem.word
      end

      rand_args << options_hash.slice(*options_hash.keys.sample(rand(5..options_hash.keys.length)))
    end

    rand_args
  end
  let(:job_id) { job.job_id }
  let(:job) do
    stage.enqueue BasicJob, *test_args
  end

  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  before(:each) do
    allow(Resque).to receive(:enqueue).and_call_original
    allow(Resque::Plugins::Stages::StagedJob).to receive(:new).and_return job
    allow(job).to receive(:delete)
    allow(job).to receive(:enqueue_job)
  end

  it "should respond to /stages/delete_job" do
    post "/stages/delete_job?job_id=#{job.job_id}"

    expect(last_response).to be_redirect
    expect(last_response.header["Location"]).to match(/stages$/)

    expect(job).to have_received(:delete)
  end

  it "should respond to /stages/queue_job" do
    post "/stages/queue_job?job_id=#{job.job_id}"

    expect(last_response).to be_redirect
    expect(last_response.header["Location"]).to match(/stages$/)

    expect(job).to have_received(:enqueue_job)
  end

  it "should respond to /stages/job_details" do
    get "/stages/job_details?job_id=#{job.job_id}"

    expect(last_response).to be_ok

    expect(last_response.body).to match %r{action="/stages/delete_job\?#{{ job_id: job.job_id }.to_param}"}
    expect(last_response.body).to match %r{action="/stages/queue_job\?#{{ job_id: job.job_id }.to_param}"}

    expect(last_response.body).to match(%r{Enqueued(\n *)</td>})
    expect(last_response.body).to match(%r{Status(\n *)</td>})
    expect(last_response.body).to match(%r{Class(\n *)</td>})
    expect(last_response.body).to match(%r{Params(\n *)</td>})
    expect(last_response.body).to match(%r{Message(\n *)</td>})
  end

  it "shows the parameters for the jobs" do
    get "/stages/job_details?job_id=#{job.job_id}"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("".html_safe + job.args.to_yaml)
  end
end
