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
  describe ".error" do
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

  describe ".failure" do
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

  describe ".find_spec_in_text" do
    def find(text, spec)
      singleline = spec.index("\n").nil?
      spec = spec.sub(/^\s*\n/, "")
      ShellOpts::ShellOpts.find_spec_in_text(text, spec, singleline)
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
end
