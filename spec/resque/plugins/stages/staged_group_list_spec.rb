# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Stages::StagedGroupList do
  let(:groups) do
    [travel_to(3.hours.ago) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid, description: "s Description 1") },
     travel_to(0.hours.ago) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid, description: "a Description 2") },
     travel_to(2.hours.ago) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid, description: "not A Description 3") },
     travel_to(1.hours.ago) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid) }]
  end
  let(:group_list) { Resque::Plugins::Stages::StagedGroupList.new }

  describe "groups" do
    it "lists all groups" do
      groups
      expect(group_list.groups.map(&:group_id).sort).to eq groups.map(&:group_id).sort
    end
  end

  describe "num_groups" do
    it "counts the groups" do
      groups
      expect(group_list.num_groups).to eq 4
    end
  end

  describe "paginated_groups" do
    it "sorts groups by description" do
      groups
      expect(group_list.paginated_groups("description", "asc", 2, 2)).to eq [groups[2], groups[0]]
    end

    it "sorts groups by created_at" do
      groups
      expect(group_list.paginated_groups("created_at", "asc", 2, 2)).to eq [groups[3], groups[1]]
    end

    it "sorts groups by num_stages" do
      groups.each.with_index do |group, index|
        index.times { |count| group.stage(count) }
      end

      expect(group_list.paginated_groups("num_stages", "asc", 2, 2)).to eq [groups[2], groups[3]]
    end
  end

  describe "delete_all" do
    it "deletes all groups" do
      groups
      group_list.delete_all

      expect(group_list.groups).to be_empty
    end
  end

  describe "add_group" do
    it "adds a group to the list when the group is created" do
      expect(group_list.groups).to be_empty

      group = Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid, description: "Description 1")

      expect(group_list.groups).to eq [group]
    end
  end

  describe "remove_group" do
    it "removes a group from the list when the group is deleted" do
      expect(group_list.groups).to be_empty

      group = Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid, description: "Description 1")

      expect(group_list.groups).to eq [group]

      group.delete

      expect(group_list.groups).to be_empty
    end
  end

  describe "#order_param" do
    it "returns asc for any column other than the current one" do
      expect(group_list.order_param("sort_option",
                                    "current_sort",
                                    %w[asc desc].sample)).to eq "asc"
    end

    it "returns desc for the current column if it is asc" do
      expect(group_list.order_param("sort_option", "sort_option", "asc")).to eq "desc"
    end

    it "returns asc for the current column if it is desc" do
      expect(group_list.order_param("sort_option", "sort_option", "desc")).to eq "asc"
    end
  end
end
