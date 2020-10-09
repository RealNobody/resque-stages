# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Stages do
  it "has a version number" do
    expect(Resque::Plugins::Stages::VERSION).not_to be nil
  end

  context "full resque calls" do
    around(:each) do |spec_proxy|
      inline = Resque.inline?

      begin
        Resque.inline = false
        spec_proxy.call
      ensure
        Resque.inline = inline
      end
    end

    context BasicJob do
      let(:group) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid) }
      let(:stage) { group.current_stage }
      let(:job) { stage.enqueue(BasicJob, *options) }
      let(:load_job) { Resque::Plugins::Stages::StagedJob.new(job.job_id) }
      let(:worker) { Resque::Worker.new(BasicJob.queue) }
      let(:options) { ["This", 1, "is", "an" => "arglist"] }

      before(:each) do
        worker.register_worker
        allow(load_job).to receive(:notify_stage).and_return nil
        allow(Resque::Plugins::Stages::StagedJob).to receive(:perform_job).and_return load_job
      end

      it "records that the job is running" do
        job.enqueue_job

        allow(BasicJob).to receive(:perform) do
          expect(load_job.status).to eq :running
        end

        worker_job = worker.reserve

        worker.perform worker_job
        worker.done_working
      end

      it "records that the job succeeded" do
        job.enqueue_job

        worker_job = worker.reserve

        worker.perform worker_job
        worker.done_working

        expect(load_job.status).to eq :successful
      end

      it "records that the job failed" do
        allow(BasicJob).to receive(:perform).and_raise "This is an error"

        job.enqueue_job

        worker_job = worker.reserve

        worker.perform worker_job
        worker.done_working

        expect(load_job.status).to eq :failed
      end
    end

    context RetryJob do
      let(:group) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid) }
      let(:stage) { group.current_stage }
      let(:job) { stage.enqueue(RetryJob, *options) }
      let(:load_job) { Resque::Plugins::Stages::StagedJob.new(job.job_id) }
      let(:worker) { Resque::Worker.new(RetryJob.queue) }
      let(:options) { ["This", 1, "is", "an" => "arglist"] }

      before(:each) do
        worker.register_worker
        allow(load_job).to receive(:notify_stage).and_return nil
        allow(Resque::Plugins::Stages::StagedJob).to receive(:perform_job).and_return load_job
      end

      it "records that the job succeeded" do
        job.enqueue_job

        worker_job = worker.reserve

        worker.perform worker_job
        worker.done_working

        expect(load_job.status).to eq :successful
      end

      it "records that the job re-queued" do
        allow(RetryJob).to receive(:perform).and_raise "This is an error"

        job.enqueue_job

        worker_job = worker.reserve

        worker.perform worker_job
        worker.done_working

        expect(load_job.status).to eq :pending_re_run
      end

      it "records that the job failed" do
        allow(RetryJob).to receive(:perform).and_raise "This is an error"

        6.times do
          job.enqueue_job

          worker_job = worker.reserve

          worker.perform worker_job
          worker.done_working
        end

        expect(load_job.status).to eq :failed
      end
    end
  end

  context "inline" do
    context RetryJob do
      let(:group) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid) }
      let(:stage) { group.current_stage }
      let(:job) { stage.enqueue(RetryJob, *options) }
      let(:load_job) { Resque::Plugins::Stages::StagedJob.new(job.job_id) }
      let(:options) { ["This", 1, "is", "an" => "arglist"] }

      before(:each) do
        allow(load_job).to receive(:notify_stage).and_return nil
        allow(Resque::Plugins::Stages::StagedJob).to receive(:perform_job).and_return load_job
      end

      it "records that the job succeeded" do
        job.enqueue_job

        expect(load_job.status).to eq :successful
      end

      it "records that the job faileds" do
        allow(RetryJob).to receive(:perform).and_raise "This is an error"

        expect { job.enqueue_job }.to raise_error

        expect(load_job.status).to eq :failed
      end
    end
  end
end
