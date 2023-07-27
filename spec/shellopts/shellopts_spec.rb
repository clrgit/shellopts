
describe "ShellOpts::ShellOpts" do
  def default_source = "-a"
  def make(*args, **opts) = ShellOpts::ShellOpts.new(*args, **opts)
  def compile(src = nil, *args, **opts) = make(*args, **opts).compile(src || default_source)

  def attr(src, member, *args, **opts)
    if src
      src = nil if src == true
      compile(src, *args, **opts).send(member)
    else
      make(*args, **opts).send(member)
    end
  end

  def check_val(src = nil, member, klass_or_value)
    val = attr(src, member)
    case klass = value = klass_or_value
      when Class
        expect(val).to be_a klass
      else
        expect(val).to eq value
    end
  end

  def check_success(src = nil, *args, **opts)
    if src
      src = nil if src == true
      expect { compile(src, *args, **opts) }.not_to raise_error
    else
      expect { make(*args, **opts) }.not_to raise_error
    end
  end

  def check_error(src = nil, *args, **opts)
    if src
      src = nil if src == true
      expect { compile(src, *args, **opts) }.to raise_error ShellOpts::CompilerError
    else
      expect { make(*args, **opts) }.to raise_error ShellOpts::Error
    end
  end

  def check_constrain_error(src = nil, *args, **opts)
    if src
      src = nil if src == true
      expect { compile(src, *args, **opts) }.to raise_error Constrain::MatchError
    else
      expect { make(*args, **opts) }.to raise_error Constrain::MatchError
    end
  end

  def check_argument_error(src = nil, *args, **opts)
    if src
      src = nil if src == true
      expect { compile(src, *args, **opts) }.to raise_error ArgumentError
    else
      expect { make(*args, **opts) }.to raise_error ArgumentError
    end
  end

  describe "#name" do
    it "can be set using an option to #initialize" do
      s = make(name: "prg")
      expect(s.name).to eq "prg"
    end
    it "defaults to the name of the executable" do
      s = make
      expect(s.name).to eq "rspec"
    end
  end

  describe "#initialize" do
    describe "options" do
      describe ":name" do
        it "accepts a string" do
          expect(make(name: "prg").name).to eq "prg"
        end
        it "defaults to the name of the program" do
          expect(make.name).to eq "rspec"
        end
      end
      describe ":help" do
        it "accepts a true/false value" do
          check_success(true, help: true)
          check_success(true, help: false)
          check_constrain_error(true, help: "gryf")
        end
        it "defaults to true" do
          check_val(true, :help, true)
        end
      end
      describe ":version" do
        it "accepts true, false, or a String" do
          check_success(true, version: true)
          check_success(true, version: false)
          check_success(true, version: "1.2.3")
          check_constrain_error(true, version: 42)
        end

        it "defaults to true" do
          s = ShellOpts::ShellOpts.new
          expect(s.version).to eq true
        end

        context "when false" do
          it "sets #version_number to nil" do
            s = ShellOpts::ShellOpts.new(version: false)
            expect(s.version_number).to eq nil
          end
        end

        context "when true" do
          it "sets #version_number to a auto-detected value" do
            s = ShellOpts::ShellOpts.new
            expect(s.version_number).to eq ShellOpts::VERSION
          end
          it "raises if no version could be found"
        end

        context "when a version number" do
          it "sets #version to true" do
            s = ShellOpts::ShellOpts.new(version: "1.2.3")
            expect(s.version).to eq true
          end
          it "sets #version_number to the given value" do
            s = ShellOpts::ShellOpts.new(version: "1.2.3")
            expect(s.version_number).to eq "1.2.3"
          end
        end
      end
      describe ":quiet" do
        it "accepts a true/false value" do
          check_success(true, quiet: true)
          check_success(true, quiet: false)
          check_constrain_error(true, quiet: "gryf")
        end
        it "defaults to false" do
          check_val(true, :quiet, false)
        end
      end
      describe ":verbose" do
        it "accepts a true/false value" do
          check_success(true, verbose: true)
          check_success(true, verbose: false)
          check_constrain_error(true, verbose: "gryf")
        end
        it "defaults to false" do
          check_val(true, :verbose, false)
        end
      end
      describe ":debug" do
        it "accepts a true/false value" do
          check_success(true, debug: true)
          check_success(true, debug: false)
          check_constrain_error(true, debug: "gryf")
        end
        it "defaults to false" do
          check_val(true, :debug, false)
        end
      end
      describe ":float" do
        it "accepts a true/false value" do
          check_success(true, float: true)
          check_success(true, float: false)
          check_constrain_error(true, float: "gryf")
        end
        it "defaults to true" do
          check_val(true, :float, true)
        end
      end
      describe ":exception" do
        it "accepts a true/false value" do
          check_success(true, exception: true)
          check_success(true, exception: false)
          check_constrain_error(true, exception: "gryf")
        end
        it "defaults to false" do
          check_val(true, :exception, false)
        end
      end
    end
  end

  describe "#compile" do
    def find_builtin_option(shellopts = nil, ident, **opts)
      shellopts ||= compile(**opts)
      shellopts.grammar[ident]
    end

    def has_builtin_option?(ident, **opts) = !find_builtin_option(ident, **opts).nil?

    it "returns self" do
      s = make
      c = s.compile("-a")
      expect(c).to eq s
    end

    it "sets #multiline to true/false" do
      check_val(:multiline, nil)
      check_val("-a\n", :multiline, true)
    end
    it "sets #spec to the source string" do
      check_val(:spec, nil)
      check_val(true, :spec, String)
    end
    it "sets #tokens to an array of Token objects" do
      check_val(:tokens, nil)
      s = compile
      expect(s.tokens).to be_a Array
      expect(s.tokens.all? { _1.is_a?(ShellOpts::Token) }).to eq true
    end
    it "sets #ast to the top-level Ast::Spec object" do
      check_val(:ast, nil)
      check_val(true, :ast, ShellOpts::Ast::Spec)
    end
    it "sets #grammar to the top-level Grammar::Grammar object" do
      check_val(:grammar, nil)
      check_val(true, :grammar, ShellOpts::Grammar::Grammar)
    end
    it "sets #<builtin>_option to the associated Grammar object" do
      s = compile(**::ShellOpts::ShellOpts::BUILTIN_OPTIONS.map { |opt| [opt, true] }.to_h)
      ::ShellOpts::ShellOpts::BUILTIN_OPTIONS.each { |opt|
        expect(opt).not_to eq nil
        attr = s.send(:"#{opt}_option")
        obj = find_builtin_option(s, opt)
        expect(attr).to eq obj
      }
    end

    it "creates a --help grammar option by default" do
      expect(has_builtin_option?(:help, help: false)).to eq false
      expect(has_builtin_option? :help).to eq true
    end
    it "creates a --version grammar option"
    it "creates a --quiet grammar option when #quiet is true" do
      expect(has_builtin_option?(:quiet)).to eq false
      expect(has_builtin_option?(:quiet, quiet: true)).to eq true
    end
    it "creates a repeatable --verbose grammar option when #verbose is true" do
      expect(has_builtin_option?(:verbose)).to eq false
      option = find_builtin_option(:verbose, verbose: true)
      expect(option).not_to eq nil
      expect(option.repeatable?).to eq true
    end
    it "creates a --debug grammar option when #debug is true" do
      expect(has_builtin_option?(:debug)).to eq false
      expect(has_builtin_option?(:debug, debug: true)).to eq true
    end

    it "sets #doc"
  end
end

# describe "#program" do
#   it "is initially nil" do
#     check_nil(:program)
#   end
#   it "is set by #interpret"
# end
#
# describe "#argv" do
#   it "is initially nil" do
#     check_nil(:argv)
#   end
#   it "is set by #interpret"
# end
#
# describe "#args" do
#   it "is initially nil" do
#     check_nil(:args)
#   end
#   it "is set by #interpret"
# end

