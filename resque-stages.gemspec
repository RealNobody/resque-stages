require_relative 'lib/resque/stages/version'

Gem::Specification.new do |spec|
  spec.name          = "resque-stages"
  spec.version       = Resque::Stages::VERSION
  spec.authors       = ["RealNobody"]
  spec.email         = ["RealNobody1@cox.net"]

  spec.summary       = %q{A Resque gem for executing batches of jobs in stages to ensure that some jobs complete execution before other jobs.}
  spec.description   = %q{A Resque gem for executing batches of jobs in stages.  All jobs in a stage must complete before any job in the next stage
                          is started allowing you to be sure that jobs are not executed out of sequence.}
  spec.homepage      = "https://github.com/RealNobody/resque-stages"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/RealNobody/resque-stages"
  spec.metadata["changelog_uri"] = "https://github.com/RealNobody/resque-stages"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
