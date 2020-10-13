# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Stages::StagedJob do
  let(:stage) do
    instance_double(Resque::Plugins::Stages::StagedGroupStage,
                    add_job:        nil,
                    remove_job:     nil,
                    group_stage_id: SecureRandom.uuid,
                    status:         :pending,
                    "status=":      nil,
                    job_completed:  nil)
  end
  let(:job) { Resque::Plugins::Stages::StagedJob.create_job(stage, BasicJob, "This", 1, :is, an: "arglist") }
  let(:load_job) { Resque::Plugins::Stages::StagedJob.new(job.job_id) }

  context "compressed job" do
    let(:job) { Resque::Plugins::Stages::StagedJob.create_job(stage, CompressedJob, "This", 1, :is, an: "arglist") }
    let(:enqueue_args) do
      [{ resque_compressed: true,
         payload:           CompressedJob.compressed_args([{ "staged_job_id" => job.job_id }, "This", 1, :is, an: "arglist"]),
         staged_job_id:     job.job_id }]
    end

    describe "create" do
      it "creates a new job" do
        travel_to(Time.now) do
          job
          load_job

          expect(load_job.class_name).to eq "CompressedJob"
          expect(load_job.staged_group_stage.group_stage_id).to eq stage.group_stage_id
          expect(load_job.enqueue_args).to eq [CompressedJob, *enqueue_args]
          expect(load_job.args).to eq ["This", 1, "is", "an" => "arglist"]
          expect(load_job.uncompressed_args).to eq ["This", 1, "is", "an" => "arglist"]
          expect(load_job.status).to eq :pending
          expect(load_job.queue_time).to eq Time.now
        end
      end
    end

    describe "enqueue_job" do
      it "enqueues a job with the staging parameters" do
        allow(Resque).to receive(:enqueue)

        load_job.enqueue_job

        expect(Resque).to have_received(:enqueue).with(CompressedJob, *enqueue_args)
      end
    end

    describe "enqueue_args" do
      it "returns the args for enqueing the job" do
        expect(load_job.enqueue_args).to eq [CompressedJob, *enqueue_args]
      end
    end

    describe "args" do
      it "returns the args for the job" do
        expect(load_job.args).to eq ["This", 1, "is", "an" => "arglist"]
      end

      it "returns the uncompressed args for the job" do
        expect(load_job.uncompressed_args).to eq ["This", 1, "is", "an" => "arglist"]
      end

      it "defaults args to a blank array if nil" do
        job.args = nil
        job.save!

        expect(load_job.args).to eq []
      end
    end
  end

  describe "create" do
    it "creates a new job" do
      travel_to(Time.now) do
        job
        load_job

        expect(load_job.class_name).to eq "BasicJob"
        expect(load_job.staged_group_stage.group_stage_id).to eq stage.group_stage_id
        expect(load_job.args).to eq ["This", 1, "is", "an" => "arglist"]
        expect(load_job.uncompressed_args).to eq ["This", 1, "is", "an" => "arglist"]
        expect(load_job.status).to eq :pending
        expect(load_job.queue_time).to eq Time.now
      end
    end

    it "adds the job to the staged_group_stage" do
      job
      expect(stage).to have_received(:add_job).with(job)
    end
  end

  describe "<=>" do
    it "returns true for identical IDs" do
      expect(job <=> load_job).to be_zero
    end

    it "returns false for different IDs" do
      expect(Resque::Plugins::Stages::StagedJob.new(SecureRandom.uuid) <=> job).not_to be_zero
    end

    it "returns false for different objects" do
      expect(job <=> job.job_id).to be_nil
    end
  end

  describe "status" do
    it "saves upon setting" do
      job.status = :successful

      expect(load_job.status).to eq :successful
    end

    it "pending sets the group to pending if the stage is completed" do
      allow(stage).to receive(:status).and_return :complete

      job.status = :pending

      expect(stage).to have_received(:status=).with(:pending)
    end

    it "pending does nothing if the stage is pending" do
      allow(stage).to receive(:status).and_return :pending

      job.status = :pending

      expect(stage).not_to have_received(:status=)
    end

    it "pending does nothing if the stage is running" do
      allow(stage).to receive(:status).and_return :running

      job.status = :pending

      expect(stage).not_to have_received(:status=)
    end

    it "queued? changes the stage to running if stage is pending" do
      allow(stage).to receive(:status).and_return :pending

      job.status = :queued

      expect(stage).to have_received(:status=).with(:running)
    end

    it "queued? does nothing if stage is running" do
      allow(stage).to receive(:status).and_return :running

      job.status = :queued

      expect(stage).not_to have_received(:status=)
    end

    it "queued? changes the stage to running if stage is completed" do
      allow(stage).to receive(:status).and_return :complete

      job.status = :queued

      expect(stage).to have_received(:status=).with(:running)
    end

    it "complete? changes notifies the stage" do
      job.status = :failed

      expect(stage).to have_received(:job_completed)
    end
  end

  describe "status_message" do
    it "saves upon setting" do
      job.status_message = "This is a large status that we're just telling you about"

      expect(load_job.status_message).to eq "This is a large status that we're just telling you about"
    end
  end

  describe "delete" do
    it "deletes the object" do
      job.delete
      expect(load_job.args).to be_empty
    end

    it "removes the object from the group stage" do
      job.delete
      expect(stage).to have_received(:remove_job).with(job)
    end
  end

  describe "enqueue_job" do
    it "enqueues a job with the staging parameters" do
      allow(Resque).to receive(:enqueue)

      load_job.enqueue_job

      expect(Resque).to have_received(:enqueue).with(BasicJob, { staged_job_id: load_job.job_id }, "This", 1, "is", "an" => "arglist")
    end

    it "sets the jobs status to queued" do
      allow(Resque).to receive(:enqueue)

      load_job.enqueue_job

      expect(load_job.status).to eq :queued
    end

    it "enqueues delayed jobs" do
      allow(Resque).to receive(:enqueue_delayed_selection)

      job.status = :pending_re_run

      load_job.enqueue_job

      expect(Resque).to have_received(:enqueue_delayed_selection)
    end
  end

  describe "enqueue_args" do
    it "returns the args for enqueing the job" do
      expect(load_job.enqueue_args).to eq [BasicJob, { staged_job_id: job.job_id }, "This", 1, "is", "an" => "arglist"]
    end
  end

  describe "args" do
    it "returns the args for the job" do
      expect(load_job.args).to eq ["This", 1, "is", "an" => "arglist"]
    end

    it "returns the uncompressed_args for the job" do
      expect(load_job.uncompressed_args).to eq ["This", 1, "is", "an" => "arglist"]
    end

    it "defaults args to a blank array if nil" do
      job.args = nil
      job.save!

      expect(load_job.args).to eq []
    end
  end

  describe "staged_group_stage" do
    it "returns a staged_group_stage object" do
      expect(load_job.staged_group_stage).to be_a(Resque::Plugins::Stages::StagedGroupStage)
    end

    it "returns nil if the job does not exist" do
      job.delete

      expect(load_job.staged_group_stage).to be_nil
    end
  end

  describe "completed?" do
    %i[pending queued running pending_re_run].each do |status|
      it "is not completed if status #{status}" do
        job.status = status

        expect(job.completed?).to be_falsey
      end
    end

    %i[failed successful].each do |status|
      it "is not completed if status #{status}" do
        job.status = status

        expect(job.completed?).to be_truthy
      end
    end
  end

  describe "queued?" do
    %i[pending failed successful].each do |status|
      it "is not completed if status #{status}" do
        job.status = status

        expect(job.queued?).to be_falsey
      end
    end

    %i[queued running pending_re_run].each do |status|
      it "is not completed if status #{status}" do
        job.status = status

        expect(job.queued?).to be_truthy
      end
    end
  end

  describe "pending?" do
    %i[queued running failed successful].each do |status|
      it "is not completed if status #{status}" do
        job.status = status

        expect(job.pending?).to be_falsey
      end
    end

    %i[pending pending_re_run].each do |status|
      it "is not completed if status #{status}" do
        job.status = status

        expect(job.pending?).to be_truthy
      end
    end
  end

  describe "blank?" do
    it "is not blank if the job key exists" do
      job

      expect(load_job).to be_present
    end

    it "is blank if the job key is missing" do
      job.delete

      expect(load_job).to be_blank
    end
  end
end
