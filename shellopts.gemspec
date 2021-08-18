
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "shellopts/version"

Gem::Specification.new do |spec|
  spec.name          = "shellopts"
  spec.version       = Shellopts::VERSION
  spec.authors       = ["Claus Rasmussen"]
  spec.email         = ["claus.l.rasmussen@gmail.com"]

  spec.summary       = %q{Parse command line options and arguments}
  spec.description   = %q{ShellOpts is a simple command line parsing libray
                          that covers most modern use cases incl. sub-commands.
                          Options and commands are specified using a
                          getopt(1)-like string that is interpreted by the
                          library to process the command line}
  spec.homepage      = "http://github.com/clrgit/shellopts"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0+ is required to protect against public gem pushes"
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.2.10"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "indented_io"
  spec.add_development_dependency "simplecov"
end
