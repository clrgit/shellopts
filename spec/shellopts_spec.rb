include ShellOpts

describe "ShellOpts" do
  it 'has a version number' do
    expect(ShellOpts::VERSION).not_to be_nil
  end

# describe "::process" do
#   it "Returns a tuple of ShellOpts::Program and ShellOpts::Args objects" do
#     spec = "-a"
#     argv = %w(-a arg)
#     opts, args = ShellOpts::ShellOpts.process(spec, argv)
#     expect(opts.is_a?(ShellOpts::Program)).to eq true
#     expect(args).to be_a(ShellOpts::Args)
#   end
#   it "adds a --version option if :version is true"
#   it "adds a -h and a --help option if :help is true"
# end
end

describe "ShellOpts::ShellOpts" do
  describe "::error" do
    before(:each) { ShellOpts.instance = nil }
    context "when no ShellOpts object has been initialized" do
      it "prints '<program>: <message>' on stderr and exits the program with status 1" do
        expect {
          expect { ShellOpts.error("msg") }.to raise_error(SystemExit) { |error|
            expect(error.status).to eq 1
          }
        }.to output("rspec: msg\n").to_stderr
      end
    end
    context "when a ShellOpts object has been initialized" do
      it "calls #error in the instance" do
        spec = "-a -- FILE"
        ShellOpts.process(spec, [])
        hold = $stderr
        begin
          $stderr = File.open("/dev/null", "w")
          expect(ShellOpts.instance).to receive(:error)
          ShellOpts.error("msg")
        rescue SystemExit
          ;
        ensure
          $stderr = hold
        end
      end
    end
  end

  describe "::failure" do
    context "when no ShellOpts object has been initialized" do
      it "prints '<program>: <message>' on stderr and exits the program with status 1" do
        expect {
          expect { ShellOpts.failure("msg") }.to raise_error(SystemExit) { |failure|
            expect(failure.status).to eq 1
          }
        }.to output("rspec: msg\n").to_stderr
      end
    end
    context "when a ShellOpts object has been initialized" do
      it "calls #failure in the instance" do
        spec = "-a -- FILE"
        ShellOpts.process(spec, [])
        hold = $stderr
        begin
          $stderr = File.open("/dev/null", "w")
          expect(ShellOpts.instance).to receive(:failure)
          ShellOpts.failure("msg")
        rescue SystemExit
          ;
        ensure
          $stderr = hold
        end
      end
    end
  end

  describe "::exception" do
    context "when true" do
      it "raise exceptions instead of printing ShellOpts error messages" do
        save_exception = ShellOpts.exception
        begin
          ShellOpts.exception = true
          expect { ShellOpts.error("msg") }.to raise_error ShellOpts::Error
        ensure
          ShellOpts.exception = save_exception
        end
      end
    end
    context "when false" do
      it "prints ShellOpts error messages" do
        save_exception = ShellOpts.exception
        begin
          ShellOpts.exception = false
          expect {
            expect { ShellOpts.error("msg") }.to raise_error SystemExit
          }.to output(/rspec: msg/).to_stderr
        ensure
          ShellOpts.exception = save_exception
        end
      end
    end
  end

  describe "::find_spec_in_text" do
    def find(text, spec)
      oneline = spec.index("\n").nil?
      spec = spec.sub(/^\s*\n/, "")
      ShellOpts::ShellOpts.find_spec_in_text(text, spec, oneline)
    end

    it "returns [nil, nil] if not found" do
      spec = %(
        asdf
      )
      text = %(
        qwerty
      )
      expect(find(text, spec)).to eq [nil, nil]

      text = %(
        asdf
      )
      expect(find(text, spec)).not_to eq [nil, nil]
    end

    it "returns [line-index, char-index] of the spec with within text" do
      spec = %(
          -a,all      Option
          -b,beta     Opt
      )
      text = %(
        Some text
        SPEC = %(
          -a,all      Option
          -b,beta     Opt
        )
        Some more text
      )
      expect(find(text, spec)).to eq [3, 10]
    end

    it "ignores lines that could be interpreted by ruby" do
      interpolated = "interpolated text"
      spec = %(
          -a,all      #{interpolated}
          -b,beta
      )
      text = %(
          -a,all      \#{interpolated}
          -b,beta
      )
      expect(find(text, spec)).to eq [1,10]
    end
  end

  describe "::silent?" do
    it "returns the status of the silent option in the current instance" do
      ShellOpts.process("-a", [], silent: true)
      expect(ShellOpts.silent?).to eq false
      ShellOpts.process("-a", %w(--silent), silent: true)
      expect(ShellOpts.silent?).to eq true
    end
  end

  describe "::quiet?" do
    it "returns the status of the quiet option in the current instance" do
      ShellOpts.process("-a", [], quiet: true)
      expect(ShellOpts.quiet?).to eq false
      ShellOpts.process("-a", %w(--quiet), quiet: true)
      expect(ShellOpts.quiet?).to eq true
    end
  end

  describe "::verbose?" do
    it "returns the status of the verbose option in the current instance" do
      ShellOpts.process("-a", [], verbose: true)
      expect(ShellOpts.verbose?).to eq false

      ShellOpts.process("-a", %w(--verbose), verbose: true)
      expect(ShellOpts.verbose?).to eq true
      expect(ShellOpts.verbose?(2)).to eq false

      ShellOpts.process("-a", %w(--verbose --verbose), verbose: true)
      expect(ShellOpts.verbose?).to eq true
      expect(ShellOpts.verbose?(2)).to eq true
      expect(ShellOpts.verbose?(3)).to eq false
    end
  end

  describe "::debug?" do
    it "returns the status of the debug option in the current instance" do
      ShellOpts.process("-a", [], debug: true)
      expect(ShellOpts.debug?).to eq false
      ShellOpts.process("-a", %w(--debug), debug: true)
      expect(ShellOpts.debug?).to eq true
    end
  end

  # TODO: Generally usable method. Move to a common library
  def failure?(&block)
    begin
      hold = $stderr
      $stderr = File.open("/dev/null", "w")
      yield
    rescue SystemExit
      return true;
    ensure
      $stderr = hold
    end
    return false
  end

  describe "::program_path" do
    # Hard to test
    it "returns the absolute path to the executable"
    it "is not affected by changes to current directory"
    # Better-than-nothing-test
    it "doesn't fail" do
      expect(ShellOpts.program_path).to be_a String
    end
  end

  describe "::environment_path" do
    # Hard to test
    it "returns the absolute path to the user's current directory when the program was called"
    it "is not affected by changes to current directory"
    # Better-than-nothing-test
    it "doesn't fail" do
      expect(ShellOpts.environment_path).to be_a String
    end
  end

  describe "::process" do
    it "can disable --version option" do
      spec = %(--version)
      opts, args = ShellOpts.process(spec, [], version: false)
      expect(opts.version).to eq false
      opts, args = ShellOpts.process(spec, %w(--version), version: false)
      expect(opts.version).to eq true
    end
    it "can enable --silent option" do
      spec = %(-a)
      expect(failure? { ShellOpts.process(spec, %w(--silent), silent: false) }).to eq true
      opts, args = ShellOpts.process(spec, %w(), silent: true)
      expect(opts.silent).to eq false
      opts, args = ShellOpts.process(spec, %w(--silent), silent: true)
      expect(opts.silent).to eq true
    end
    it "can enable --quiet option" do
      spec = %(-a)
      expect(failure? { ShellOpts.process(spec, %w(--quiet), quiet: false) }).to eq true
      opts, args = ShellOpts.process(spec, %w(), quiet: true)
      expect(opts.quiet).to eq false
      opts, args = ShellOpts.process(spec, %w(--quiet), quiet: true)
      expect(opts.quiet).to eq true
    end
  end
end

