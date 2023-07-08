
include ShellOpts

describe "Analyzer" do
  def spec
    @spec
  end

  def grammar
    @grammar
  end

  def doc
    @doc
  end

  # Compile 's' and return the grammar object
  def compile(s) 
    lexer = Lexer.new("main", s)
    tokens = lexer.lex
    parser = Parser.new(tokens)
    @spec = parser.parse
    analyzer = Analyzer.new(spec)
    @grammar, @doc = analyzer.analyze
    @grammar
  end

  # Compile 's' and check that the result matches 'r'. #check removes the first
  # line that contains the '!' declaration to save some typing
  def check(s, r)
    s = render(compile(s)).sub(/^.*?\n/, "")
    expect(undent s).to eq undent r
  end

  using Ext::StringIO::Redirect

  def render(node)
    StringIO.redirect(:stdout) { node.dump(format: :rspec) }
  end

  before(:each) { Grammar::Node.clear }

  describe "#analyze" do
    it "does a lot of stuff"
  end

  describe "#check_options" do
    it "rejects nested options" do
      s = %(
        -a
        -b
      )
      expect { compile s }.not_to raise_error
      s = %(
        -a
          -b
      )
      expect { compile s }.to raise_error AnalyzerError
    end
    it "rejects duplicate options" # do
#     s = %(
#       -a -a
#     )
#     expect { compile s }.to raise_error AnalyzerError
#     s = %(
#       -a
#       -a
#     )
#     expect { compile s }.to raise_error AnalyzerError
#   end
  end

  describe "#check_briefs" do
    it "rejects duplicate command briefs" do
      s = %(
        cmd1! @brief1
        cmd2!
          @brief
      )
      expect { compile s }.not_to raise_error

      # This is not an error because brief2 the default brief
      s = %(
        cmd1!
        cmd2! @brief1
          @brief2
      )
      expect { compile s }.not_to raise_error

      s = %(
        cmd!
          @brief1
          @brief2
      )
      expect { compile s }.to raise_error AnalyzerError

    end
    it "rejects duplicate option briefs" do
      s = %(
        -a @brief
        -b
          @brief
      )
      expect { compile s }.not_to raise_error

      # This is not an error because brief2 the default brief
      s = %(
        -a
        -b @brief1
          @brief2
      )
      expect { compile s }.not_to raise_error

      s = %(
        -a 
          @brief
          @brief
      )
      expect { compile s }.to raise_error AnalyzerError
    end
  end

  describe "#check_arg_descrs" do
    it "rejects duplicate arg_descrs" do
      s = %(
        cmd!
          -- ARG
      )
      expect { compile s }.not_to raise_error

      s = %(
        cmd!
          -- ARG1
          -- ARG2
      )
      expect { compile s }.to raise_error AnalyzerError
    end
  end

  describe "#check_commands" do
    it "rejects commands nested within options" do
      s = %(
        cmd!
          --option
      )
      expect { compile s }.not_to raise_error

      s = %(
        cmd!
          --option
            cmd2!
      )
      expect { compile s }.to raise_error AnalyzerError

    end

    it "rejects commands nested within multiple commands" do
      s = %(
        cmd1!
          cmd2!
      )
      expect { compile s }.not_to raise_error

      s = %(
        cmd1!
        cmd2!
          cmd3!
      )
      expect { compile s }.to raise_error AnalyzerError
    end
  end

  describe "#analyze_commands" do
    it "checks for duplicate commands" do
      s = %(
        cmd1!
          cmd1!
        cmd2!
      )
      expect { compile s }.not_to raise_error

      s = %(
        cmd1!
        cmd1!
      )
      expect { compile s }.to raise_error AnalyzerError

      s = %(
        cmd1!
          cmd1!
          cmd1!
      )
      expect { compile s }.to raise_error AnalyzerError

      s = %(
        cmd1!
          cmd2!
        cmd1.cmd2!
      )
      expect { compile s }.to raise_error AnalyzerError
    end
    it "creates command objects" do
      s = %(
        cmd1!

        cmd2!
      )
      expect(compile(s).commands.map(&:uid)).to eq [:cmd1!, :cmd2!]
    end
    it "creates command groups" do
      s = %(
        cmd1!
        cmd2!

        cmd3!
      )
      check s, %(
        cmd1!, cmd2!
        cmd3!
      )
    end
    it "creates intermediate command objects" do
      s = %(
        cmd1.cmd2!
      )
      check s, %(
        cmd1!
          cmd2!
      )
    end
  end

  describe "#analyze_options" do
    it "creates option objects" do
      s = %(
        --opt
      )
    end

    it "creates option groups" do
      s = %(
        cmd!
          --opt1

          --opt2
      )
    end
    it "creates option subgroups" do
      s = %(
        cmd!
          --opt1
          --opt2
      )
    end
    it "creates command options" do
      s = %(
        cmd! --opt1 --opt2
      )
    end
  end
end

__END__

#     it "rejects duplicate options" do
#       expect { compile("-a -a") }.to raise_error AnalyzerError
#     end
#     it "rejects --with-separator together with --with_separator" do
#       expect { compile("--with-separator --with_separator") }.to raise_error AnalyzerError
#     end
#   end
#
#   describe "#reorder_options" do
#     it "moves options before the first command" do
#       src = %(
#         -a
#         cmd!
#         -b
#       )
#       expect(names(src)).to eq %w(-a -b cmd)
#     end
#     it "moves options before the COMMAND section if present" do
#       src = %(
#         -a
#         COMMAND
#         cmd!
#         -b
#       )
#       expect(names(src)).to eq %w(-a -b COMMAND cmd)
#     end
#   end

  end
end


__END__


    describe "#link_commands" do
      it "links subcommands to supercommands" do
        src = %(
          cmd1!
          cmd1.cmd11!
        )
        grammar = compile(src)
        expect(names(grammar)).to eq %w(cmd1 cmd11)
        expect(grammar.commands.size == 1)
        cmd1, cmd11 = grammar.children
        expect(cmd1.name).to eq "cmd1"
        expect(cmd1.commands).to eq [cmd11]
        expect(cmd11.name).to eq "cmd11"
        expect(cmd11.command).to eq cmd1
      end

      it "creates implicit commands" do
        src = %(
          cmd.cmd1!
        )
        grammar = compile(src)
        expect(grammar.commands.size).to eq 1
        cmd = grammar.commands.first
        expect(cmd.path).to eq [:cmd!]
        expect(cmd.commands.size).to eq 1
        cmd1 = cmd.commands.first
        expect(cmd1.name).to eq "cmd1"
      end

      it "keeps documentation order" do
        src = %(
          cmd1!
          cmd1.cmd11!
        )
        expect(names(src)).to eq %w(cmd1 cmd11)
      end
    end
  end
end

__END__
  # :call-seq:
  #   names(grammar)
  #   names(source)
  #
  def names(arg) 
    grammar = arg.is_a?(Grammar::Node) ? arg : compile(arg)
    grammar.children.map { |child|
      case child
        when Grammar::OptionGroup; child.options.first.name
        when Grammar::GrammarNode; child.name
        else child.token.source
      end
    }
  end

  describe "Grammar" do
    describe "Command" do
#     describe "#compute_command_hashes" do
#       it "Handles duplicate subcommands" do
#         src = %(
#           cmd1!
#             cmd!
#           cmd2!
#             cmd!
#         )
#         expect { compile(src) }.not_to raise_error
#       end
#       it "Handles duplicate subcommands with undeclared parents" do
#         src = %(
#           cmd1.cmd!
#           cmd2.cmd!
#         )
#         expect { compile(src) }.not_to raise_error
#       end
#     end
    end
  end


