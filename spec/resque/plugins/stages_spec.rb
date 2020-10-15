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

        allow(BasicJob).to receive(:perform_job).and_wrap_original do |orig_perform, *args|
          new_job = orig_perform.call(*args)

          allow(new_job).to receive(:notify_stage).and_return nil

          new_job
        end
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
        expect(FakeLogger).
            to have_received(:error).with "BasicJob.perform args", { "staged_job_id" => job.job_id }, "This", 1, "is", "an" => "arglist"
        expect(FakeLogger).to have_received(:error).with "BasicJob.perform job.args", "This", 1, "is", "an" => "arglist"
        expect(FakeLogger).to have_received(:error).with "BasicJob.perform job_id", job.job_id
      end

      it "records that the job failed" do
        allow(FakeLogger).to receive(:error).and_raise "This is an error"

        job.enqueue_job

        worker_job = worker.reserve

        worker.perform worker_job
        worker.done_working

        expect(load_job.status).to eq :failed
        expect(FakeLogger).to have_received(:error).with "BasicJob.perform job_id", job.job_id
      end
    end

    context CompressedJob do
      let(:group) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid) }
      let(:stage) { group.current_stage }
      let(:job) { stage.enqueue(CompressedJob, *options) }
      let(:load_job) { Resque::Plugins::Stages::StagedJob.new(job.job_id) }
      let(:worker) { Resque::Worker.new(CompressedJob.queue) }
      let(:options) { ["This", 1, "is", "an" => "arglist"] }

      before(:each) do
        worker.register_worker

        allow(CompressedJob).to receive(:perform_job).and_wrap_original do |orig_perform, *args|
          new_job = orig_perform.call(*args)

          allow(new_job).to receive(:notify_stage).and_return nil

          new_job
        end
      end

      it "records that the job is running" do
        job.enqueue_job

        allow(CompressedJob).to receive(:perform) do
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
        expect(FakeLogger).to have_received(:error).with "CompressedJob.perform args",
                                                         { "staged_job_id" => job.job_id },
                                                         "This",
                                                         1,
                                                         "is",
                                                         "an" => "arglist"
        expect(FakeLogger).to have_received(:error).with "CompressedJob.perform job.args",
                                                         "This",
                                                         1,
                                                         "is",
                                                         "an" => "arglist"
        expect(FakeLogger).to have_received(:error).with "CompressedJob.perform job_id", job.job_id
      end

      it "records that the job failed" do
        allow(FakeLogger).to receive(:error).and_raise "This is an error"

        job.enqueue_job

        worker_job = worker.reserve

        worker.perform worker_job
        worker.done_working

        expect(load_job.status).to eq :failed
        expect(FakeLogger).to have_received(:error).with "CompressedJob.perform job_id", job.job_id
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

        allow(RetryJob).to receive(:perform_job).and_wrap_original do |orig_perform, *args|
          new_job = orig_perform.call(*args)

          allow(new_job).to receive(:notify_stage).and_return nil

          new_job
        end
      end

      it "records that the job succeeded" do
        job.enqueue_job

        worker_job = worker.reserve

        worker.perform worker_job
        worker.done_working

        expect(load_job.status).to eq :successful
        expect(FakeLogger).
            to have_received(:error).with "RetryJob.perform args", { "staged_job_id" => job.job_id }, "This", 1, "is", "an" => "arglist"
        expect(FakeLogger).to have_received(:error).with "RetryJob.perform job.args", "This", 1, "is", "an" => "arglist"
        expect(FakeLogger).to have_received(:error).with "RetryJob.perform job_id", job.job_id
      end

      it "records that the job re-queued" do
        allow(FakeLogger).to receive(:error).and_raise "This is an error"

        job.enqueue_job

        worker_job = worker.reserve

        worker.perform worker_job
        worker.done_working

        expect(load_job.status).to eq :pending_re_run
        expect(FakeLogger).to have_received(:error).with "RetryJob.perform job_id", job.job_id
      end

      it "records that the job failed" do
        allow(FakeLogger).to receive(:error).and_raise "This is an error"

        6.times do
          Resque.enqueue(*job.enqueue_args)

          worker_job = worker.reserve

          worker.perform worker_job
          worker.done_working
        end

        expect(load_job.status).to eq :failed
        expect(FakeLogger).to have_received(:error).exactly(6).times.with("RetryJob.perform job_id", job.job_id)
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
        allow(RetryJob).to receive(:perform_job).and_wrap_original do |orig_perform, *args|
          new_job = orig_perform.call(*args)

          allow(new_job).to receive(:notify_stage).and_return nil

          new_job
        end
      end

      it "records that the job succeeded" do
        job.enqueue_job

        expect(load_job.status).to eq :successful
        expect(FakeLogger).
            to have_received(:error).with "RetryJob.perform args", { "staged_job_id" => job.job_id }, "This", 1, "is", "an" => "arglist"
        expect(FakeLogger).to have_received(:error).with "RetryJob.perform job.args", "This", 1, "is", "an" => "arglist"
        expect(FakeLogger).to have_received(:error).with "RetryJob.perform job_id", job.job_id
      end

      it "records that the job failed" do
        allow(FakeLogger).to receive(:error).and_raise "This is an error"

        expect { job.enqueue_job }.not_to raise_error

        expect(load_job.status).to eq :failed
        expect(FakeLogger).to have_received(:error).with "RetryJob.perform job_id", job.job_id
      end
    end

    context CompressedJob do
      let(:group) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid) }
      let(:stage) { group.current_stage }
      let(:job) { stage.enqueue(CompressedJob, *options) }
      let(:load_job) { Resque::Plugins::Stages::StagedJob.new(job.job_id) }
      let(:options) { ["This", 1, "is", "an" => "arglist"] }

      before(:each) do
        allow(CompressedJob).to receive(:perform_job).and_wrap_original do |orig_perform, *args|
          new_job = orig_perform.call(*args)

          allow(new_job).to receive(:notify_stage).and_return nil

          new_job
        end
      end

      it "records that the job succeeded" do
        job.enqueue_job

        expect(load_job.status).to eq :successful
        expect(FakeLogger).
            to have_received(:error).with "CompressedJob.perform args", { "staged_job_id" => job.job_id }, "This", 1, "is", "an" => "arglist"
        expect(FakeLogger).to have_received(:error).with "CompressedJob.perform job.args", "This", 1, "is", "an" => "arglist"
        expect(FakeLogger).to have_received(:error).with "CompressedJob.perform job_id", job.job_id
      end

      it "records that the job failed" do
        allow(FakeLogger).to receive(:error).and_raise "This is an error"

        expect { job.enqueue_job }.not_to raise_error

        expect(load_job.status).to eq :failed
        expect(FakeLogger).to have_received(:error).with "CompressedJob.perform job_id", job.job_id
      end
    end
  end

  describe "perform_job" do
    let(:stage) do
      instance_double(Resque::Plugins::Stages::StagedGroupStage,
                      add_job:        nil,
                      remove_job:     nil,
                      group_stage_id: SecureRandom.uuid,
                      status:         :pending,
                      "status=":      nil,
                      job_completed:  nil)
    end

    RSpec.shared_examples("it loads from args") do
      it "loads the job by ID" do
        expect(perform_job).to eq load_job
        expect(perform_job.args).to eq ["This", 1, "is", "an" => "arglist"]
      end

      it "creates a new job if the id is deleted" do
        job.delete

        expect(perform_job).to eq load_job
        expect(perform_job.args).to eq match_args
      end

      it "creates a new job if the first paramater is a hash but doesn't have an ID" do
        perform_args[0].delete :staged_job_id
        perform_args[0]["this_is"] = "silly"

        if perform_args.length > 1
          expect(perform_job.args).to eq perform_args
        else
          expect(perform_job.args).to eq match_args
        end
      end

      it "creates a new job if there is no id" do
        if perform_args.length > 1
          perform_args.shift
        else
          perform_args[0].delete :staged_job_id
        end

        expect(perform_job.args).to eq match_args
      end
    end

    context "BasicJob" do
      let(:job) { Resque::Plugins::Stages::StagedJob.create_job(stage, BasicJob, "This", 1, :is, an: "arglist") }
      let(:load_job) { Resque::Plugins::Stages::StagedJob.new(job.job_id) }
      let(:perform_args) { [{ staged_job_id: job.job_id }, "This", 1, "is", "an" => "arglist"] }
      let(:match_args) { ["This", 1, "is", "an" => "arglist"] }
      let(:perform_job) { BasicJob.perform_job(*perform_args) }

      it_behaves_like "it loads from args"
    end

    context "CompressedJob" do
      let(:job) { Resque::Plugins::Stages::StagedJob.create_job(stage, CompressedJob, "This", 1, :is, an: "arglist") }
      let(:load_job) { Resque::Plugins::Stages::StagedJob.new(job.job_id) }
      let(:perform_args) { job.enqueue_compressed_args }
      let(:match_args) { ["This", 1, "is", "an" => "arglist"] }
      let(:perform_job) { CompressedJob.perform_job(*perform_args) }

      it_behaves_like "it loads from args"
    end
  end
end
