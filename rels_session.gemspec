# frozen_string_literal: true

require_relative "lib/rels_session/version"

Gem::Specification.new do |spec|
  spec.name          = "rels_session"
  spec.version       = RelsSession::VERSION
  spec.authors       = ["Tim Peat"]
  spec.email         = ["tim@timpeat.com"]

  spec.summary       = "Shared session store for RELS applications"
  spec.homepage      = "https://github.com/reallyenglish-global/rels-session"
  spec.required_ruby_version = ">= 3.0.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "actionpack", ">= 7.0.2.4", "<= 9"
  spec.add_runtime_dependency "connection_pool", ">= 2.2.5", "< 3"
  spec.add_runtime_dependency "device_detector", ">= 1.0.7"
  spec.add_runtime_dependency "dry-schema", ">= 1.4.0"
  spec.add_runtime_dependency "dry-struct", ">= 1.4.0"
  spec.add_runtime_dependency "redis", ">= 5", "< 6"

  spec.add_development_dependency "database_cleaner-redis"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "debug", "~> 1.11"
  spec.add_development_dependency "rubocop", "~> 1.27"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
  spec.add_development_dependency "rubocop-rspec", "~> 2.8"
end
