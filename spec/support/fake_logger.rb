# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    allow(FakeLogger).to receive(:error).and_return nil
  end
end
