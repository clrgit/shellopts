
include ShellOpts

describe "Interpreter" do
  def render_value(value)
    case value
      when nil; "nil" # only used within arrays
      when String; "='#{value}'"
      when Integer; "=#{value}"
      when Float; "=#{value}"
      when Array; "=#{value.map { |v| render_value(v) }.join(",")}"
    else
      raise "Oops"
    end
  end

  def render_option(command, ident, value)
    option = command.__grammar__[ident]
    if option.repeatable?
      arg = "*#{value}"
    elsif value
      arg = "=#{render_value}"
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

  def interpret(spec, argv)
    multiline = !spec.index("\n").nil?
    tokens = Lexer.lex("main", spec, singleline)
    ast = Parser.parse(tokens, multiline: multiline)
    grammar = Analyzer.analyze(ast) # @grammar and @ast refer to the same object
    expr, args = Interpreter.interpret(grammar, argv)

    render_command(expr)
  end

  it "splits coalesced short options" do
    expect(interpret "+a", %w(-aa)).to eq "main -a*2"
    expect(interpret "-a -b", %w(-ab)).to eq "main -a -b"
  end

  context "when float is true" do
    it "allows options everywhere" do
      expect(interpret "-a cmd! -b", %w(cmd -a -b)).to eq "main -a cmd -b"
    end
    it "sub-commands can override outer options" do
      expect(interpret "-a cmd! +a", %w(-a cmd -a -a)).to eq "main -a cmd -a*2"
    end
  end
end

