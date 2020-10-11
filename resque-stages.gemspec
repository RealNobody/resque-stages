# frozen_string_literal: true

require_relative "lib/resque/plugins/stages/version"

Gem::Specification.new do |spec|
  spec.name    = "resque-stages"
  spec.version = Resque::Plugins::Stages::VERSION
  spec.authors = ["RealNobody"]
  spec.email   = ["RealNobody1@cox.net"]

  spec.summary               = "A Resque gem for executing batches of jobs in stages to ensure that some jobs complete execution before other jobs."
  spec.description           = "A Resque gem for executing batches of jobs in stages.  All jobs in a stage must complete before any job in the next" \
                               " stage is started allowing you to be sure that jobs are not executed out of sequence."
  spec.homepage              = "https://github.com/RealNobody/resque-stages"
  spec.license               = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/RealNobody/resque-stages"
  spec.metadata["changelog_uri"]   = "https://github.com/RealNobody/resque-stages"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.test_files = Dir["spec/**/*"]

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "resque"
  spec.add_dependency "redis"
  spec.add_dependency "redis-namespace"

  spec.add_development_dependency "activesupport"
  spec.add_development_dependency "cornucopia"
  spec.add_development_dependency "faker"
  spec.add_development_dependency "gem-release"
  spec.add_development_dependency "resque-compressible"
  spec.add_development_dependency "rspec-rails", "> 3.9.1"
  spec.add_development_dependency "resque-retry"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "simplecov"
end
