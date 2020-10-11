# frozen_string_literal: true

require "resque"
require "resque/server"
require "resque-stages"
require "action_view/helpers/output_safety_helper"
require "action_view/helpers/capture_helper"
require "action_view/helpers/date_helper"

# rubocop:disable Metrics/ModuleLength

module Resque
  # Extends Resque Web Based UI.
  # Structure has been borrowed from ResqueHistory.
  module StagesServer
    include ActionView::Helpers::DateHelper

    class << self
      def erb_path(filename)
        File.join(File.dirname(__FILE__), "server", "views", filename)
      end

      def public_path(filename)
        File.join(File.dirname(__FILE__), "server", "public", filename)
      end

      def included(base)
        add_page_views(base)
        add_button_callbacks(base)
        add_static_files(base)
      end

      private

      def add_page_views(base)
        groups_list(base)
        group_stages_list(base)
        stage_jobs_list(base)
        job_details(base)
      end

      def groups_list(base)
        stages_key_params(base)

        base.class_eval do
          get "/stages" do
            set_stages_key_params

            erb File.read(Resque::StagesServer.erb_path("groups.erb"))
          end
        end
      end

      def stages_key_params(base)
        base.class_eval do
          def set_stages_key_params
            @sort_by    = params[:sort] || "description"
            @sort_order = params[:order] || "asc"
            @page_num   = (params[:page_num] || 1).to_i
            @page_size  = (params[:page_size] || 20).to_i
          end
        end
      end

      def group_stages_list(base)
        group_stages_list_params(base)

        base.class_eval do
          get "/stages/group_stages_list" do
            set_group_stages_list_params_params

            erb File.read(Resque::StagesServer.erb_path("group_stages_list.erb"))
          end
        end
      end

      def group_stages_list_params(base)
        base.class_eval do
          def set_group_stages_list_params_params
            @group_id  = params[:group_id]
            @page_num  = (params[:page_num] || 1).to_i
            @page_size = (params[:page_size] || 20).to_i
          end
        end
      end

      def stage_jobs_list(base)
        stage_jobs_key_params(base)

        base.class_eval do
          get "/stages/stage" do
            set_stage_jobs_key_params

            erb File.read(Resque::StagesServer.erb_path("stage.erb"))
          end
        end
      end

      def stage_jobs_key_params(base)
        base.class_eval do
          def set_stage_jobs_key_params
            @group_stage_id = params[:group_stage_id]
            @sort_by        = params[:sort] || "status"
            @sort_order     = params[:order] || "desc"
            @page_num       = (params[:page_num] || 1).to_i
            @page_size      = (params[:page_size] || 20).to_i
          end
        end
      end

      def job_details(base)
        base.class_eval do
          get "/stages/job_details" do
            @job_id = params[:job_id]

            erb File.read(Resque::StagesServer.erb_path("job_details.erb"))
          end
        end
      end

      def add_static_files(base)
        base.class_eval do
          get %r{/stages/public/([a-z_]+\.[a-z]+)} do
            send_file Resque::StagesServer.public_path(params[:captures]&.first)
          end
        end
      end

      def add_button_callbacks(base)
        purge_all(base)
        cleanup_jobs(base)
        delete_all_groups(base)
        initiate_group(base)
        delete_group(base)
        initiate_stage(base)
        delete_stage(base)
        queue_job(base)
        delete_job(base)
      end

      def purge_all(base)
        base.class_eval do
          post "/stages/purge_all" do
            Resque::Plugins::Stages::Cleaner.purge_all

            redirect u("stages")
          end
        end
      end

      def cleanup_jobs(base)
        base.class_eval do
          post "/stages/cleanup_jobs" do
            Resque::Plugins::Stages::Cleaner.cleanup_jobs

            redirect u("stages")
          end
        end
      end

      def delete_all_groups(base)
        base.class_eval do
          post "/stages/delete_all_groups" do
            Resque::Plugins::Stages::StagedGroupList.new.delete_all

            redirect u("stages")
          end
        end
      end

      def initiate_group(base)
        base.class_eval do
          post "/stages/initiate_group" do
            Resque::Plugins::Stages::StagedGroup.new(params[:group_id]).initiate

            redirect u("stages")
          end
        end
      end

      def delete_group(base)
        base.class_eval do
          post "/stages/delete_group" do
            Resque::Plugins::Stages::StagedGroup.new(params[:group_id]).delete

            redirect u("stages")
          end
        end
      end

      def initiate_stage(base)
        base.class_eval do
          post "/stages/initiate_stage" do
            Resque::Plugins::Stages::StagedGroupStage.new(params[:group_stage_id]).initiate

            redirect u("stages")
          end
        end
      end

      def delete_stage(base)
        base.class_eval do
          post "/stages/delete_stage" do
            Resque::Plugins::Stages::StagedGroupStage.new(params[:group_stage_id]).delete

            redirect u("stages")
          end
        end
      end

      def queue_job(base)
        base.class_eval do
          post "/stages/queue_job" do
            Resque::Plugins::Stages::StagedJob.new(params[:job_id]).enqueue_job

            redirect u("stages")
          end
        end
      end

      def delete_job(base)
        base.class_eval do
          post "/stages/delete_job" do
            Resque::Plugins::Stages::StagedJob.new(params[:job_id]).delete

            redirect u("stages")
          end
        end
      end
    end

    Resque::Server.tabs << "Stages"
  end
end

Resque::Server.class_eval do
  include Resque::StagesServer
end

# rubocop:enable Metrics/ModuleLength
