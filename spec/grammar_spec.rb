
describe "Grammar" do
  describe "#dot" do
    let(:spec) { %(
      -a
      -b,c

      cmd1!
        -d

        cmd2!
          -e

          cmd3!
    ) }

    let(:grammar) { 
      tokens = ShellOpts::Lexer.lex("main", spec)
      ast = ShellOpts::Parser.parse(tokens)
      grammar, doc = ShellOpts::Analyzer.analyze(ast)
      grammar
    }

    it ":! returns the Program object" do
      expect(grammar.dot(:!)).to be_a ShellOpts::Grammar::Program
      expect(grammar.dot(:!).ident).to eq :!
    end
    it ":<option> returns an Option object" do
      expect(grammar.dot(:a)).to be_a ShellOpts::Grammar::Option
      expect(grammar.dot(:a).ident).to eq :a
    end
    it ":<command>! returns a Command object" do
      expect(grammar.dot(:cmd1!)).to be_a ShellOpts::Grammar::Command
      expect(grammar.dot(:cmd1!).ident).to eq :cmd1!
    end
    it "resolves nested options" do
      expr = :"cmd1.d"
      expect(grammar.dot(expr)).to be_a ShellOpts::Grammar::Option
      expect(grammar.dot(expr).ident).to eq :d
    end
    it "resolves nested commands" do
      expr = :"cmd1.cmd2!"
      expect(grammar.dot(expr)).to be_a ShellOpts::Grammar::Command
      expect(grammar.dot(expr).ident).to eq :cmd2!
    end
    it "resolves deeply nested options and commands" do
      expect(grammar.dot(:"cmd1.cmd2.e")).to be_a ShellOpts::Grammar::Option
      expect(grammar.dot(:"cmd1.cmd2.cmd3!")).to be_a ShellOpts::Grammar::Command      
    end
    it "accepts Symbol and String arguments" do
      expect { grammar.dot("a") }.not_to raise_error
      expect { grammar.dot("cmd1!") }.not_to raise_error
    end
  end
end

