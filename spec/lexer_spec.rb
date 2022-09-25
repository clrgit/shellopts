
include ShellOpts

describe "Lexer" do
  describe "#lex" do
    # Doesn't include the initial program token
    def make(src, fields: nil)
      fields = Array(fields).flatten
      tokens = ::ShellOpts::Lexer.new("main", src).lex
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
      tokens = ShellOpts::Lexer.lex("main", "")[1..-1]
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
      tokens = ::ShellOpts::Lexer.new("main", src).lex[1..-1]
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

    it "creates descr tokens" do
      src = "-- ARG1 ARG2"
      expect(make src, fields: :kind).to eq [:arg_descr]
      expect(make src, fields: :source).to eq ["--"]
      expect(make src, fields: :value).to eq ["ARG1 ARG2"]
    end

    it "creates repeated descr tokens" do
      src = "-- ARG1 -- ARG2"
      expect(make src, fields: :kind).to eq [:arg_descr, :arg_descr]
      expect(make src, fields: :value).to eq %w(ARG1 ARG2)
    end

    it "creates spec and argument tokens" do
      src = "-a ++ ARG1 ARG2"
      expect(make src, fields: :kind).to eq [:option, :arg_spec, :arg, :arg]
      expect(make src, fields: :source).to eq %w(-a ++ ARG1 ARG2)
    end

    it "creates repeated specs" do
      src = "++ ARG1 ++ ARG2"
      expect(make src, fields: :kind).to eq [:arg_spec, :arg, :arg_spec, :arg]
      expect(make src, fields: :source).to eq %w(++ ARG1 ++ ARG2)
    end

    it "creates brief tokens" do
      src = "\n-c @ Brief"
      expect(make src, fields: :kind).to eq [:option, :brief]
      expect(make src, fields: :source).to eq %w(-c @)
      expect(make src, fields: :value).to eq %w(-c Brief)
    end

    it "parses a mix of descrs, specs, and briefs" do
      src = "-- ARG @brief"
      expect(make src, fields: :kind).to eq [:arg_descr, :brief]
      src = "++ ARG @brief"
      expect(make src, fields: :kind).to eq [:arg_spec, :arg, :brief]
      src = "-- ARG ++ ARG @brief"
      expect(make src, fields: :kind).to eq [:arg_descr, :arg_spec, :arg, :brief]
    end


    it "rejects text in command definitions" do
      src = "cmd! TEXT"
      expect { ::ShellOpts::Lexer.lex("main", src) }.to raise_error LexerError
    end

    it "rejects text in option definitions" do
      src = "-a ARG"
      expect { ::ShellOpts::Lexer.lex("main", src) }.to raise_error LexerError
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
      expect(make src, fields: :source).to eq %w(COMMANDS cmd!)
    end

    it "pluralize section names" do
      src = %(
        COMMAND
          indented line
      )
      expect(make src, fields: :kind).to eq [:section, :text]
      expect(make(src, fields: :source).first).to eq "COMMAND"
      expect(make(src, fields: :value).first).to eq "COMMANDS"
    end

    it "creates subsection tokens" do
      src = %(
        *subsection*
      )
      expect(make src, fields: :kind).to eq [:subsection]
      expect(make(src, fields: :source).first).to eq "*subsection*"
      expect(make(src, fields: :value).first).to eq "subsection"
    end

    it "creates code tokens" do
      src = %(
        Text

          this_is_code()
      )
      expect(make src, fields: :kind).to eq [:text, :code]
      expect(make src, fields: :value).to eq ["Text", "this_is_code()"]
    end

    it "preserves indentation in code blocks" do
      src = %(
        Text

          this_is_code()
            and_more_code()
      )

      expect(make src, fields: :kind).to eq [:text, :code]
      expect(make src, fields: :value).to eq ["Text", "this_is_code()\n  and_more_code()"]
    end

    it "ignores suffixed blanks line in code blocks" do
      src = %(
        Text

          this_is_code()
      
      )

      expect(make src, fields: :kind).to eq [:text, :code]
      expect(make src, fields: :value).to eq ["Text", "this_is_code()"]
    end

    it "accepts blank lines in code blocks" do
      src = %(
        Text

          this_is_code()

          some_more()
      )
      expect(make src, fields: :kind).to eq [:text, :code]
      expect(make src, fields: :value).to eq ["Text", "this_is_code()\n\nsome_more()"]
    end
    

    it "considers lines starting with \ as text" do
      src = %(
        -o
        \\-p
      )
      expect(make src, fields: :kind).to eq [:option, :text]
      expect(make src, fields: :source).to eq %w(-o \\-p)
      expect(make src, fields: :value).to eq %w(-o -p)
    end
    it "creates blank-line token" do
      src = %(
        Hello

        -a
      )
      expect(make src, fields: :kind).to eq [:text, :blank, :option]
    end

    it "ignores initial blank lines" do
      src = %(
        
        -a
      )
      expect(make src, fields: :kind).to eq [:option]
    end

    it "ignores terminating blank lines" do
      src = %(
        -a
        
      )
      expect(make src, fields: :kind).to eq [:option]
    end

    it "ignores full-line comments" do
      src = %(
        -a
      # A comment
        # A bullet
        Text
      )
      expect(make src, fields: :kind).to eq [:option, :bullet, :text, :text]
      
    end

    it "removes in-line comments from declarations" do
      src = %(
        -a # a comment
        cmd! # another comment
      )
      expect(make src, fields: :kind).to eq [:option, :command]
    end
  end
end















