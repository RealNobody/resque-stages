# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Stages::StagedGroupStage do
  let(:group) do
    instance_double(Resque::Plugins::Stages::StagedGroup,
                    add_stage:       nil,
                    remove_stage:    nil,
                    stage_completed: nil,
                    group_id:        SecureRandom.uuid)
  end
  let(:stage) { Resque::Plugins::Stages::StagedGroupStage.new SecureRandom.uuid }
  let(:load_stage) { Resque::Plugins::Stages::StagedGroupStage.new stage.group_stage_id }

  RSpec.shared_examples("enqueues new jobs") do |enqueue_method, enqueue_method_parameters|
    describe enqueue_method do
      let(:enqueue_parameters) { [*enqueue_method_parameters, BasicJob, "This", 1, "is", "an" => "arglist"] }
      let(:job) { load_stage.jobs.first }
      let(:enqueued_parameters) { [*enqueue_method_parameters, BasicJob, { staged_job_id: job.job_id }, "This", 1, "is", "an" => "arglist"] }

      before(:each) do
        allow(Resque).to receive(enqueue_method).and_return nil
      end

      it "creates the job" do
        stage.public_send(enqueue_method, *enqueue_parameters)

        expect(load_stage.num_jobs).to eq 1

        expect(job.args).to eq ["This", 1, "is", "an" => "arglist"]
        expect(job.class_name).to eq "BasicJob"
      end

      it "does not enqueue the job is the status is pending" do
        stage.public_send(enqueue_method, *enqueue_parameters)

        expect(Resque).not_to have_received(enqueue_method)
      end

      it "enqueues the job if the status is running" do
        stage.status = :running

        stage.public_send(enqueue_method, *enqueue_parameters)

        expect(Resque).to have_received(enqueue_method).with(*enqueued_parameters)
      end

      it "marks the job as queued if the status is running" do
        stage.status = :running

        stage.public_send(enqueue_method, *enqueue_parameters)

        expect(load_stage.jobs.first.status).to eq :queued
      end

      it "enqueues the job and changes status to running if status is completed" do
        stage.status = :complete

        stage.public_send(enqueue_method, *enqueue_parameters)

        expect(Resque).to have_received(enqueue_method).with(*enqueued_parameters)
        expect(stage.status).to eq :running
      end

      it "marks the job as queued and changes status to running if status is completed" do
        stage.status = :complete

        stage.public_send(enqueue_method, *enqueue_parameters)

        expect(load_stage.jobs.first.status).to eq :queued
        expect(stage.status).to eq :running
      end
    end
  end

  describe "enqueuing jobs" do
    it_behaves_like "enqueues new jobs", :enqueue, []
    it_behaves_like "enqueues new jobs", :enqueue_to, ["queue"]
    it_behaves_like "enqueues new jobs", :enqueue_at, [Time.now]
    it_behaves_like "enqueues new jobs", :enqueue_at_with_queue, ["queue", Time.now]
    it_behaves_like "enqueues new jobs", :enqueue_in, [12.seconds]
    it_behaves_like "enqueues new jobs", :enqueue_in_with_queue, ["queue", 12.seconds]
  end

  describe "status" do
    it "defaults to pending" do
      expect(stage.status).to eq :pending
    end

    it "saves when set" do
      stage.status = :running
      expect(load_stage.status).to eq :running
    end
  end

  describe "number" do
    it "defaults to 1" do
      expect(stage.number).to eq 1
    end

    it "saves when set" do
      stage.number = 8
      expect(load_stage.number).to eq 8
    end
  end

  describe "staged_group" do
    it "returns nil if staged_group_id is nil" do
      expect(stage.staged_group).to be_nil
    end

    it "saves the staged_group_id" do
      stage.staged_group = group

      expect(load_stage.staged_group.group_id).to eq group.group_id
    end

    it "adds the stage to the group" do
      stage.staged_group = group

      expect(group).to have_received(:add_stage).with(stage)
    end
  end

  context "with jobs" do
    let(:jobs) do
      build_jobs = [travel_to(5.hours.ago) { stage.enqueue(BasicJob, "a pending") },
                    travel_to(2.hours.ago) { stage.enqueue(BasicJob, "z queued") },
                    travel_to(4.hours.ago) { stage.enqueue(BasicJob, "h running") },
                    travel_to(1.hours.ago) { stage.enqueue(BasicJob, "c pending_re_run") },
                    travel_to(3.hours.ago) { stage.enqueue(BasicJob, "m failed") },
                    travel_to(0.hours.ago) { stage.enqueue(BasicJob, "i successful") }]

      build_jobs[0].status = :pending
      build_jobs[1].status = :queued
      build_jobs[2].status = :running
      build_jobs[3].status = :pending_re_run
      build_jobs[4].status = :failed
      build_jobs[5].status = :successful

      build_jobs[0].status_message = "y"
      build_jobs[1].status_message = "g"
      build_jobs[2].status_message = "l"
      build_jobs[3].status_message = "q"
      build_jobs[4].status_message = "r"
      build_jobs[5].status_message = "b"

      build_jobs
    end

    before(:each) do
      allow(Resque).to receive(:enqueue).and_return nil
    end

    describe "paginated_jobs" do
      it "paginates by class_name" do
        jobs

        expect(load_stage.paginated_jobs("class_name", "asc", 2, 2)).to eq [jobs[2], jobs[3]]
      end

      it "paginates by status" do
        jobs

        expect(load_stage.paginated_jobs("status", "asc", 2, 2)).to eq [jobs[3], jobs[1]]
      end

      it "paginates by status_message" do
        jobs

        expect(load_stage.paginated_jobs("status_message", "asc", 2, 2)).to eq [jobs[2], jobs[3]]
      end

      it "paginates by queue_time" do
        jobs

        expect(load_stage.paginated_jobs("queue_time", "asc", 2, 2)).to eq [jobs[4], jobs[1]]
      end
    end

    describe "jobs" do
      it "returns all jobs" do
        jobs

        expect(load_stage.jobs.length).to eq jobs.length
        expect(load_stage.num_jobs).to eq jobs.length
      end

      %i[pending queued running pending_re_run failed successful].each.with_index do |status, index|
        it "returns jobs based on status #{status}" do
          jobs
          expect(load_stage.jobs_by_status(status)).to eq [jobs[index]]
        end

        it "removes a job when it is deleted" do
          jobs.sample.delete

          expect(load_stage.jobs.length).to eq jobs.length - 1
          expect(load_stage.num_jobs).to eq jobs.length - 1
        end

        it "deletes all jobs when deleted" do
          jobs

          stage.delete

          expect(load_stage.jobs.length).to eq 0
          expect(load_stage.num_jobs).to eq 0
        end

        it "removes the stage from the group when deleted" do
          jobs

          stage.staged_group = group
          stage.delete

          expect(group).to have_received(:remove_stage).with(stage)
        end
      end
    end

    describe "initiate" do
      it "queues all pending jobs" do
        allow(Resque).to receive(:enqueue).and_return nil

        jobs

        stage.initiate

        expect(Resque).to have_received(:enqueue).with(BasicJob, { staged_job_id: jobs[0].job_id }, anything)
        expect(Resque).not_to have_received(:enqueue).with(BasicJob, { staged_job_id: jobs[1].job_id }, anything)
        expect(Resque).not_to have_received(:enqueue).with(BasicJob, { staged_job_id: jobs[2].job_id }, anything)
        expect(Resque).not_to have_received(:enqueue).with(BasicJob, { staged_job_id: jobs[3].job_id }, anything)
        expect(Resque).not_to have_received(:enqueue).with(BasicJob, { staged_job_id: jobs[4].job_id }, anything)
        expect(Resque).not_to have_received(:enqueue).with(BasicJob, { staged_job_id: jobs[5].job_id }, anything)
      end

      it "changes the status to running" do
        allow(Resque).to receive(:enqueue).and_return nil

        jobs
        stage.initiate

        expect(stage.status).to eq :running
      end
    end

    describe "job_completed" do
      it "does nothing if not all jobs are completed" do
        jobs

        stage.job_completed

        expect(group).not_to have_received(:stage_completed)
        expect(stage.status).to eq :running
      end

      it "changes the status to complete if all jobs are completed" do
        jobs.each { |job| job.status = :failed unless job.completed? }

        expect(stage.status).to eq :complete
      end

      it "notifies the group if all jobs are completed" do
        stage.staged_group = group

        jobs.each do |job|
          allow(job).to receive(:staged_group_stage).and_return(stage)
        end
        jobs.each { |job| job.status = :successful unless job.completed? }

        expect(group).to have_received(:stage_completed)
      end
    end
  end

  describe "#order_param" do
    it "returns asc for any column other than the current one" do
      expect(load_stage.order_param("sort_option",
                                    "current_sort",
                                    %w[asc desc].sample)).to eq "asc"
    end

    it "returns desc for the current column if it is asc" do
      expect(load_stage.order_param("sort_option", "sort_option", "asc")).to eq "desc"
    end

    it "returns asc for the current column if it is desc" do
      expect(load_stage.order_param("sort_option", "sort_option", "desc")).to eq "asc"
    end
  end
end
