
describe "ShellOpts::ShellOpts" do
  def default_source = "-a"
  def make(*args, exception: true, **opts) = ShellOpts::ShellOpts.new(*args, exception: exception, **opts)
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
      expect { compile(src, *args, **opts) }.to raise_error ShellOpts::ShellOptsError
    else
      expect { make(*args, **opts) }.to raise_error ShellOpts::ShellOptsError
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
          check_error(true, help: "gryf")
        end
        it "defaults to true" do
          check_val(:help, true)
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
          it "sets #version_number to the given value" do
            s = ShellOpts::ShellOpts.new(version: "1.2.3")
            expect(s.version_number).to eq "1.2.3"
          end
        end
      end

      describe ":quiet" do
        it "accepts a true/false value" do # TODO TODO TODO
          check_success(true, quiet: true)
          check_success(true, quiet: false)
          check_success(true, quiet: "-Q,QUIET")
          check_error(true, quiet: "gryf")
        end
        it "defaults to false" do
          check_val(true, :quiet, false)
        end
      end
      describe ":verbose" do
        it "accepts a true/false value" do
          check_success(true, verbose: true)
          check_success(true, verbose: false)
          check_error(true, verbose: "gryf")
        end
        it "defaults to false" do
          check_val(true, :verbose, false)
        end
      end
      describe ":debug" do
        it "accepts a true/false value" do
          check_success(true, debug: true)
          check_success(true, debug: false)
          check_error(true, debug: "gryf")
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
          s = ShellOpts::ShellOpts.new.compile(default_source)
          expect(s.exception).to eq false
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
    it "sets #builtin_idents to the (optional renamed) ident" do
      s = compile
      expect(s.builtin_idents.all? { |k,v| k == v }).to eq true
      s = compile(help: "-H,HELP")
      expect(s.builtin_idents[:help]).to eq :HELP
      
    end
    it "creates a --help grammar option by default" do
      expect(has_builtin_option?(:help, help: false)).to eq false
      expect(has_builtin_option? :help).to eq true
    end
    it "creates a --version grammar option by default" do
      expect(has_builtin_option?(:version, version: false)).to eq false
      expect(has_builtin_option? :version).to eq true
    end
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


    describe "builtin options" do
      it "substitutes %short with the short option name" do
      end

      context "when ShellOpts#<option> is a string" do
        # Using :quiet as test case
        def compile_with_patched_quiet(patch, quiet: true, **opts)
          patch = Array(patch).flatten
          so = ShellOpts::ShellOpts.new(quiet: quiet, **opts)
          so.builtin_options[:quiet][2] = patch.first
          so.builtin_options[:quiet][3] = patch.last if patch.size > 1
          so.compile(default_source)
        end

        it "sets the option to true" do
          s = compile(help: "-H,HELP")
          expect(s.help).to eq true
        end
        it "renames the option" do
          s = compile(help: "-H,HELP")
          expect(s.grammar[:HELP]).not_to eq nil
        end
        it "substitutes %short in the doc" do
          s = compile_with_patched_quiet("short: %short")
          expect(s.grammar[:quiet].description.text).to eq "short: -q"
        end
        it "substitutes %long in the doc" do
          s = compile_with_patched_quiet("long: %long")
          expect(s.grammar[:quiet].description.text).to eq "long: --quiet"
        end
        it "substitutes %short with renamed value if present" do
          s = compile_with_patched_quiet("short: %short", quiet: "-Q")
          expect(s.grammar[:Q].description.text).to eq "short: -Q"
        end
        it "substitutes %long with renamed value if present" do
          s = compile_with_patched_quiet("long: %long", quiet: "--QUIET")
          expect(s.grammar[:QUIET].description.text).to eq "long: --QUIET"
        end
        context "with two descriptions" do
          it "only includes the first description if there is a short option" do
            s = compile_with_patched_quiet(["short: %short", "long"], quiet: "--QUIET")
            expect(s.grammar[:QUIET].description.text).to eq "long"
          end
          it "only prints the long variant if there is a long option" do
            s = compile_with_patched_quiet(["short", "long %long"], quiet: "-Q")
            expect(s.grammar[:Q].description.text).to eq "short"
          end
          it "concatenates the descriptions if both short and long options are present" do
            s = compile_with_patched_quiet(["short %short", "long %long"], quiet: "-Q,QUIET")
            expect(s.grammar[:QUIET].description.text).to eq "short -Q, long --QUIET"
            
          end
        end
      end
    end

    describe "#version option" do
      context "when then string matches /<option>/" do
        it "sets #version to true" do
          s = ShellOpts::ShellOpts.new(version: "-V,VERSION")
          expect(s.version).to eq true
        end
        it "renames the option" do
          s = compile(help: "-V,VERSION")
          expect(s.grammar[:VERSION]).not_to eq nil
        end
      end

      context "when the string matches /<option>:<version>/" do
        it "renames the option" do
          s = compile(version: "-V,VERSION:1.2.3")
          expect(s.grammar.dot(:VERSION).ident).to eq :VERSION
        end
        it "sets #version_number to the given value" do
          s = compile(version: "-V,VERSION:1.2.3")
          expect(s.version_number).to eq "1.2.3"
        end
      end
        
      context "when the string matches /<version>/" do
        it "sets #version_number to the given value" do
          s = compile(version: "1.2.3")
          expect(s.version_number).to eq "1.2.3"
        end
      end
    end
  end

  describe "#interpret" do
    describe "#program" do
      it "is initially nil" #do
#       check_nil(:program)
#     end
      it "is set by #interpret"
    end

    describe "#argv" do
      it "is initially nil" #do
#       check_nil(:argv)
#     end
      it "is set by #interpret"
    end

    describe "#args" do
      it "is initially nil" #do
#       check_nil(:args)
#     end
      it "is set by #interpret"
    end
  end
end

__END__
    it "sets #<builtin>_option to the associated Grammar object" do
#     args = ::ShellOpts::ShellOpts::BUILTIN_OPTIONS.keys.map { |opt,_| [opt, true] }.to_h
      s = compile(**args)
      ::ShellOpts::ShellOpts::BUILTIN_OPTIONS.keys.each { |opt|
#       expect(opt).not_to eq nil
        attr = s.send(:"#{opt}_option")
        obj = find_builtin_option(s, opt)
        expect(attr).to eq obj
      }
    end


