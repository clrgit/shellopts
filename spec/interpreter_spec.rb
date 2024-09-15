
include ShellOpts

describe "Interpreter" do
  def interprete(spec, argv)
    oneline = spec.index("\n").nil?
    tokens = Lexer.lex("main", spec, oneline)
    ast = Parser.parse(tokens)
    idr = Analyzer.analyze(ast) # @idr and @ast refer to the same object
    expr, args = Interpreter.interpret(idr, argv)
    expr
  end

  def render_value(value)
    case value
      when nil; "nil" # only used within arrays
      when String; "='#{value}'"
      when Integer; "=#{value}"
      when Float; "=#{value}"
#     when Array; "=#{value.map { |v| render_value(v) }.join(",")}"
      when Array; "=#{value.join(",")}"
    else
      raise "Oops"
    end
  end

  def render_option(command, ident, value)
    option = command.__grammar__[ident]
    if option.repeatable?
      arg = "*#{value}"
    elsif value
      arg = "#{render_value(value)}"
    else
      arg = ""
    end
    "#{option.name}#{arg}"
  end

  def render_command(command)
    [
      command.__name__,
      command.__option_values__.map { |ident, value| render_option(command, ident, value) },
      command.subcommand && render_command(command.subcommand!)
    ].flatten.compact.join(" ")
  end

  def render(spec, argv)
    render_command(interprete(spec, argv))
  end

  def opt(spec, argv, opt)
    interprete(spec, argv).__send__(opt)
  end

  it "splits coalesced short options" do
    expect(render "+a", %w(-aa)).to eq "main -a*2"
    expect(render "-a -b", %w(-ab)).to eq "main -a -b"
  end

  context "when float is true" do
    it "allows options everywhere" do
      expect(render "-a cmd! -b", %w(cmd -a -b)).to eq "main -a cmd -b"
    end
    it "sub-commands can override outer options" do
      expect(render "-a cmd! +a", %w(-a cmd -a -a)).to eq "main -a cmd -a*2"
    end
  end

  context "it interpretes option values" do
    describe "strings" do
      it "returns an String" do
        expect(opt "-a=ARG", %w(-a42), :a).to eq "42"
      end
    end
    describe "integers" do
      it "returns an Integer" do
        expect(opt "-a=#", %w(-a42), :a).to eq 42
      end
    end
    describe "float" do
      it "returns an Float" do
        expect(opt "-a=$", %w(-a42.1), :a).to eq 42.1
      end
    end
    describe "lists" do
      it "returns an array of list elements" do
        expect(opt "-a=ARG,", %w(-ab,c), :a).to eq %w(b c)
      end
      it "short options raises on absent list elements" do
        expect { opt "-a=ARG,", %w(-a), :a }.to raise_error ShellOpts::Error
      end
      it "long options allows empty list" do
        expect(opt "--all=ARG,", %w(--all=), :all).to eq []
      end
    end
  end
  context "it interpretes repeated option values" do
    describe "lists" do
      it "returns a flattened array of list elements" do
        expect(opt "+a=ARG,", %w(-ab,c -ad,e), :a).to eq %w(b c d e)
      end
    end
  end
end

