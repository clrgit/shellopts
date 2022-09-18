
require_relative "lib/shellopts/version"

Gem::Specification.new do |spec|
  spec.name          = "shellopts"
  spec.version       = ShellOpts::VERSION
  spec.authors       = ["Claus Rasmussen"]
  spec.email         = ["claus.l.rasmussen@gmail.com"]

  spec.summary       = %q{Parse command line options and arguments}
  spec.description   = %q{ShellOpts is a simple command line parsing libray
                          that supports short and long options and subcommands,
                          and has built-in help and error messages}
  spec.homepage      = "http://github.com/clrgit/shellopts"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "forward_to"
  spec.add_dependency "constrain", "~> 0.8"
  spec.add_dependency "ruby-terminfo-r3"
  spec.add_dependency "indented_io"

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "simplecov"
end
