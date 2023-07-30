
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
    option = command.__grammar__.dot(ident)
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

  def analyze(spec)
    multiline = !spec.index("\n").nil?
    tokens = Lexer.lex("main", spec)
    ast = Parser.parse(tokens, multiline: multiline)
    grammar, doc = Analyzer.analyze(ast) # @grammar and @ast refer to the same object
    [grammar, doc]
  end

  def interpret(spec, argv, **opts)
    grammar, doc = analyze(spec)
    Interpreter.interpret(grammar, argv, **opts)
  end

  def compile(spec, argv, **opts)
    command, args = interpret(spec, argv, **opts)
    render_command(command)
  end

  def program(spec, argv)
    command, args = interpret(spec, argv)
    command
  end

  def check_success(spec, argv, **opts)
    expect { compile(spec, argv, **opts) }.not_to raise_error
  end

  def check_failure(spec, argv, **opts)
    expect { compile(spec, argv, **opts) }.to raise_error ShellOpts::Error
  end

  it "splits coalesced short options" do
    expect(compile "+a", %w(-aa)).to eq "main -a*2"
    expect(compile "-a -b", %w(-ab)).to eq "main -a -b"
  end

  context "when #float is true" do
    it "allows options everywhere after their command" do
      expect(compile "-a cmd! -b", %w(cmd -a -b)).to eq "main -a cmd -b"
#     puts "-----------------------------------"
#     opts, args = interpret("-a cmd! -b", %w(cmd -a -b))
#     p opts.__option_hash__
#     p opts.a?
#     exit
    end
    it "does not allow options before their command" do
      check_failure("-a cmd! -b", %w(-a -b cmd1))
    end
    it "sub-commands can override outer options" do
      expect(compile "-a cmd! +a", %w(-a cmd -a -a)).to eq "main -a cmd -a*2"
    end
  end
  context "when #float is false" do
    it "only allows options immediately after their command" do
      check_success("-a cmd! -b", %w(-a cmd -b), float: false)
      check_failure("-a cmd! -b", %w(cmd -a -b), float: false)

    end
  end
  context "when #liquid is true" do
    it "allows options anywhere"
  end
end

