# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Stages do
  it "has a version number" do
    expect(Resque::Plugins::Stages::VERSION).not_to be nil
  end
end
