
include ShellOpts

describe "Lexer" do
  describe "#lex" do
    # Doesn't include the initial program token
    def make(src, fields: nil)
      fields = Array(fields).flatten
      oneline = src.index("\n").nil?
      tokens = ::ShellOpts::Lexer.new("main", src, oneline).lex
      tokens.shift if tokens.first&.kind == :program
      tokens.pop while tokens.last&.kind == :blank
      if fields
        if fields.size == 1
          tokens.map { |token| token.send(fields.first) }
        else
          tokens.map { |token|
            fields.map { |field| token.send(field) }
          }
        end
      else
        tokens
      end
    end

    it "accepts an empty source" do
      tokens = ::ShellOpts::Lexer.lex("main", "", true)[1..-1]
      expect(tokens).to be_empty
    end

    it "creates a program token as the first token" do
      src = %()
      tokens = ::ShellOpts::Lexer.lex("main", src, true)
      expect(tokens.map(&:kind)).to eq [:program]
    end

    it "creates a program brief token if present" do
      src = %(
        @ program brief
      )
      tokens = ::ShellOpts::Lexer.new("main", src, false).lex[1..-1]
      expect(tokens.first.kind).to eq :brief
    end

    it "creates options tokens" do
      src = %(
        -a,all
        --beta
        -c,config --data
      )
      expect(make src, fields: :kind).to eq [:option, :option, :option, :option]
      expect(make src, fields: :source).to eq %w(-a,all --beta -c,config --data)
    end

    it "creates command tokens" do
      src = %(
        cmd!
        cmd.cmd2!
      )
      expect(make src, fields: :kind).to eq [:command, :command]
      expect(make src, fields: :source).to eq %w(cmd! cmd.cmd2!)
    end
    it "allows ! to be escaped" do
      src = %(
        \\cmd1!
        \\cmd2!
        cmd3!
      )
      expect(make src, fields: :kind).to eq [:text, :text, :command]
      expect(make src, fields: :source).to eq %w(cmd1! cmd2! cmd3!)
    end

    it "creates spec and argument tokens" do
      src = %(
        -a ++ ARG1 ARG2
      )
      expect(make src, fields: :kind).to eq [:option, :spec, :argument, :argument]
      expect(make src, fields: :source).to eq %w(-a ++ ARG1 ARG2)
    end

    it "rejects text in command definitions" do
      src = "cmd! ARG"
      expect { ::ShellOpts::Lexer.lex("main", src, true) }.to raise_error LexerError
    end

    it "rejects text in option definitions" do
      src = "-a ARG"
      expect { ::ShellOpts::Lexer.lex("main", src, true) }.to raise_error LexerError
    end

    it "creates usage tokens" do
      src = "-- ARG1 ARG2"
      expect(make src, fields: :kind).to eq [:usage, :usage_string]
      expect(make src, fields: :source).to eq ["--", "ARG1 ARG2"]
    end

    it "creates brief tokens" do
      src = "\n-c @ Brief"
      expect(make src, fields: :kind).to eq [:option, :brief]
      expect(make src, fields: :source).to eq %w(-c Brief)
      src = "\n-c Brief"
      expect(make src, fields: :kind).to eq [:option, :brief]
      expect(make src, fields: :source).to eq %w(-c Brief)
    end

    it "creates doc tokens" do
      src = %(
        -a
          Explanation
      )
      expect(make src, fields: :kind).to eq [:option, :text]
      expect(make src, fields: :source).to eq %w(-a Explanation)
    end

    it "creates section tokens" do
      src = %(
        COMMANDS
        cmd!
      )
      expect(make src, fields: :kind).to eq [:section, :command]
      expect(make src, fields: :source).to eq %w(COMMAND cmd!)
    end

    it "singularize section names" do
      src = %(
        COMMANDS
      )
      expect(make src, fields: :kind).to eq [:section]
      expect(make src, fields: :source).to eq %w(COMMAND)
    end

    it "considers lines starting with \ as comments" do
      src = %(
        -o
        \\-p
      )
      expect(make src, fields: :kind).to eq [:option, :text]
      expect(make src, fields: :source).to eq %w(-o -p)
    end
    it "creates blank-line token" do
      src = %(
        Hello

        -a
      )
      expect(make src, fields: :kind).to eq [:text, :blank, :option]
    end

    it "ignores initial blank and commented lines" do
      src = %(
        
        -a
# Meta-comment
        Text
      )
      expect(make src, fields: :kind).to eq [:option, :text]
    end
  end
end

