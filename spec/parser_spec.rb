
include ShellOpts

describe "Parser" do
# def prog(source)
#   oneline = source.index("\n").nil?
#   tokens = Lexer.lex("main", source, oneline)
#   ast = Parser.parse tokens

#   puts "Tokens"
#   indent { tokens.each(&:dump) }
#   puts 
#   puts "Ast"
#   indent { ast.dump_ast }
#   puts

#   grammar = Analyzer.analyze(ast)

#   puts "Grammar"
#   indent { grammar.dump_grammar }
#   puts
#   puts "Doc"
#   indent { grammar.dump_doc }
#   puts

#   grammar
# end
# def struct(source)
#   prog(source).render_structure
# end


  def parse(s) 
    lexer = Lexer.new("main", s)
    tokens = lexer.lex
    parser = Parser.new(tokens)
    dump parser.parse
  end

  def dump(node)
    io = StringIO.new
    node.dn(io)
    io.string
  end

  describe "#parse" do
    context "option grouping" do
      it "creates an option group around an option" do
        s = "-a"
        expect(parse s).to eq undent %(
          main
            group
              -a
        )
      end
      it "creates an option group around a multi-line list of options" do
        s = %(
          -a
          -b
        )
        expect(parse s).to eq undent %(
          main
            group
              -a
              -b
        )
      end
      it "creates an option group around each single-line option" do
        s = "-a -b"
        expect(parse s).to eq undent %(
          main
            group
              -a
            group
              -b
        )
      end
      it "creates an option group around each continous list of options" do
        s = %(
          -a
          -b

          -c
        )
        expect(parse s).to eq undent %(
          main
            group
              -a
              -b
            group
              -c
        )
      end
    end
    context "briefs" do
      it "applies to an option" do
        s = %(
          -a @ brief
        )
        expect(parse s).to eq undent %(
          main
            group
              -a
                @brief
        )
      end
      it "applies to an option group" do
        s = %(
          -a 
            @ brief
        )
        expect(parse s).to eq undent %(
          main
            group
              -a
              @brief
        )
      end
      it "handles both option briefs and option group briefs" do
        s = %(
          -a @brief
          -b
            @brief
        )
        expect(parse s).to eq undent %(
          main
            group
              -a
                @brief
              -b
              @brief
        )
      end
    end
  end
end

__END__

  describe "::parse" do
    it "parses -a" do
      s = "-a"
      expect(struct s).to eq undent %(
        !
          -a
      )
    end

    it "parses cmd!" do
      s = "cmd!"
      expect(struct s).to eq undent %(
        !
          cmd!
      )
    end
   
    it "parses -a cmd!" do
      s = "-a cmd!"
      expect(struct s).to eq undent %(
        !
          -a
          cmd!
      )
    end
    it "parses -a cmd! -b" do
      s = "-a cmd! -b"
      expect(struct s).to eq undent %(
        !
          -a
          cmd!
            -b
      )
    end
    it "parses -a cmd! -a" do
      s = "-a cmd! -a"
      expect(struct s).to eq undent %(
        !
          -a
          cmd!
            -a
      )
    end
    it "parses -a cmd1! -b cmd2! -c" do
      s = "-a cmd1! -b cmd2! -c"
      expect(struct s).to eq undent %(
        !
          -a
          cmd1!
            -b
          cmd2!
            -c
      )
    end
    it "parses -a cmd1! -b cmd1.cmd2! -c" do
      s = "-a cmd1! -b cmd1.cmd2! -c"
      expect(struct s).to eq undent %(
        !
          -a
          cmd1!
            -b
            cmd2!
              -c
      )
    end
    it "parses indented sub-commands" do
      s = undent %(
        cmd!
          sub!
      )
      expect(struct s).to eq undent %(
        !
          cmd!
            sub!
      )
    end

    it "parses -a cmd1! -b cmd1.cmd2! -c cmd1.cmd2.cmd3! -d" do
      s = "-a cmd1! -b cmd1.cmd2! -c cmd1.cmd2.cmd3! -d"
      expect(struct s).to eq undent %(
        !
          -a
          cmd1!
            -b
            cmd2!
              -c
              cmd3!
                -d

      )
    end
    it "parses -- ARG" do
      s = "-- ARG"
      expect(struct s).to eq undent %(
        !
          ARG
      )
    end
    it "parses ARG as text" do
      s = "ARG"
      para = prog(s).children.first
      expect(para).to be_a Grammar::Paragraph
      expect(para.to_s).to eq "ARG"
    end

    it "rejects cmd! ARG" do
      s = "cmd! ARG"
      expect { prog(s) }.to raise_error LexerError
    end

    it "rejects -a ARG" do
      s = "-a ARG"
      expect { prog(s) }.to raise_error LexerError
    end

    it "parses -a -- ARG" do
      s = "-a -- ARG"
      expect(struct s).to eq undent %(
        !
          -a
          ARG
      )
    end
    it "parses indented argument descriptions" do
      s = %(
        cmd!
          -- ARG1
          -- ARG2
      )
      expect(struct s).to eq undent %(
        !
          cmd!
            ARG1
            ARG2
      )
    end
    it "parses -a -- ARG0 cmd1! -b -- ARG1" do
      s = "-a -- ARG0 cmd1! -b -- ARG1"
      expect(struct s).to eq undent %(
        !
          -a
          cmd1!
            -b
            ARG1
          ARG0
      )
    end
    it "parses -a -- ARG0 cmd1! -b -- ARG1 cmd2! -c -- ARG2" do
      s = "-a -- ARG0 cmd1! -b -- ARG1 cmd2! -c -- ARG2"
      expect(struct s).to eq undent %(
        !
          -a
          cmd1!
            -b
            ARG1
          cmd2!
            -c
            ARG2
          ARG0
      )
    end

    context "handles multiline source" do
      it "with commands" do
        s = %(
          cmd1!
          cmd2!
          cmd3!
        )
        expect(struct s).to eq undent %(
          !
            cmd1!
            cmd2!
            cmd3!
        )
      end

      it "with option groups" do
        s = %(
          -a
          -b -c
        )
        expect(prog(s).children).to all(be_a Grammar::OptionGroup)
        expect(prog(s).options.map { |option| option.group.token.source }).to eq %w(-a -b -b)
      end
    end
  end

#     spec = "-a -b=something -- ARG1 cmd! -- ARG2" # TODO: Make it possible to say "-a -b ARG1 cmd! ARG2"
#     spec = "-a -b -- ARG1 ARG2 ARG3 ARG4 cmd1! cmd2! cmd3! cmd4!" # FIXME
end

describe "Option#parse" do
  def opt(source, method = nil)
    oneline = source.index("\n").nil?
    tokens = Lexer.lex("main", source, oneline)
    program = Parser.parse(tokens)
    options = program.option_groups.map(&:options).flatten
    option = options.first
    method ? option.send(method) : option
  end

  it "accepts -s and +s" do
    expect { opt "-s" }.not_to raise_error
    expect { opt "+s" }.not_to raise_error
  end
  it "accepts --long and ++long" do
    expect { opt "--long" }.not_to raise_error
    expect { opt "++long" }.not_to raise_error
  end
  it "accepts -s,long and +s,long" do
    expect { opt "-s,long" }.not_to raise_error
    expect { opt "+s,long" }.not_to raise_error
  end
  it "accepts --long,more and ++long,more" do
    expect { opt "--long,more" }.not_to raise_error
    expect { opt "++long,more" }.not_to raise_error
  end
  it "rejects --l" do
    expect { opt "--l" }.to raise_error ParserError
  end

  context "sets ident" do
    context "to the name of the option" do
      it "without initial '-' and '--'" do
        expect(opt "-l", :ident).to eq :l
        expect(opt "--long", :ident).to eq :long
      end
      it "with internal '-' replaced with '_'" do
        expect(opt "--with-separator", :ident).to eq :with_separator
        expect(opt "--with_separator", :ident).to eq :with_separator
      end
    end
  end

  context "sets name" do
    it "to the name of the first long option if present" do
      expect(opt "-s,long,more", :name).to eq "--long"
    end
    it "and otherwise to the name of the first short option" do
      expect(opt "-s,t", :name).to eq "-s"
    end
  end

  it "sets short_names" do
    expect(opt "--long", :short_names).to eq []
    expect(opt "-a,b", :short_names).to eq %w(-a -b)
    expect(opt "-a,b,long", :short_names).to eq %w(-a -b)
  end

  it "sets long_names" do
    expect(opt "-a", :long_names).to eq []
    expect(opt "--long,more", :long_names).to eq %w(--long --more)
    expect(opt "-a,long,more", :long_names).to eq %w(--long --more)
  end

  it "sets repeatable?" do
    expect(opt "-v", :repeatable?).to eq false
    expect(opt "+v", :repeatable?).to eq true
  end

  it "sets argument?" do
    expect(opt "-s", :argument?).to eq false
    expect(opt "-s=SOME", :argument?).to eq true
  end

  context "without an argument" do
    it "sets argument_type to the default" do
      expect(opt "-s=SOME", :argument_type).to be_a Grammar::Type
    end
  end

  context "with an argument" do
    it "fails on missing argument" do
      expect { opt "-s=" }.to raise_error ParserError
    end
    it "accepts non-interpreted arguments" do
      src = "-s=<some-value>"
      expect { opt src }.not_to raise_error
      option = opt src
      expect(option.argument?).to eq true
      expect(option.argument_name).to eq "<some-value>"
      expect(option.argument_type).to be_a Grammar::Type
    end
    it "sets optional?" do
      expect(opt "-s=SOME", :optional?).to eq false
      expect(opt "-s=SOME?", :optional?).to eq true
    end
    context "without a type specification" do
      it "sets argument_name" do
        expect(opt "-s=SOME", :argument_name).to eq "SOME"
      end
    end
    context "with a '#' type specifier" do
      it "sets argument_type to IntegerType" do
        expect(opt "-s=VAL:#", :argument_type).to be_a Grammar::IntegerType
        expect(opt "-s=:#", :argument_type).to be_a Grammar::IntegerType
        expect(opt "-s=#", :argument_type).to be_a Grammar::IntegerType
      end

      it "defaults argument_name to 'INT'" do
        expect(opt "-s=VAL:#", :argument_name).to eq "VAL"
        expect(opt "-s=:#", :argument_name).to eq "INT"
        expect(opt "-s=#", :argument_name).to eq "INT"
      end
    end
    context "with a '$' argument_type specifier" do
      it "sets argument_type to FloatType" do
        expect(opt "-s=VAL:$", :argument_type).to be_a Grammar::FloatType
        expect(opt "-s=:$", :argument_type).to be_a Grammar::FloatType
        expect(opt "-s=$", :argument_type).to be_a Grammar::FloatType
      end

      it "defaults argument_name to 'NUM'" do
        expect(opt "-s=VAL:$", :argument_name).to eq "VAL"
        expect(opt "-s=:$", :argument_name).to eq "NUM"
        expect(opt "-s=$", :argument_name).to eq "NUM"
      end
    end
    context "with a keyword specifier" do
      it "sets argument_type to FileType" do
        expect(opt "-s=VAL:FILE", :argument_type).to be_a Grammar::FileType
        expect(opt "-s=:FILE", :argument_type).to be_a Grammar::FileType
        expect(opt "-s=FILE", :argument_type).to be_a Grammar::FileType
      end
      it "initialize FileType with a kind" do
        expect(opt("-s=OFILE").argument_type.kind).to eq :ofile
      end
      it "defaults file or file path argument_name to 'FILE'" do
        expect(opt "-s=VAL:FILE", :argument_name).to eq "VAL"
        expect(opt "-s=:FILE", :argument_name).to eq "FILE"
        expect(opt "-s=FILE", :argument_name).to eq "FILE"
        expect(opt "-s=:EFILE", :argument_name).to eq "FILE"
        expect(opt "-s=EFILE", :argument_name).to eq "FILE"
        expect(opt "-s=:NFILE", :argument_name).to eq "FILE"
        expect(opt "-s=NFILE", :argument_name).to eq "FILE"
        expect(opt "-s=:IFILE", :argument_name).to eq "FILE"
        expect(opt "-s=IFILE", :argument_name).to eq "FILE"
        expect(opt "-s=:OFILE", :argument_name).to eq "FILE"
        expect(opt "-s=OFILE", :argument_name).to eq "FILE"
      end
      it "defaults directory or directory path argument_name to 'DIR'" do
        expect(opt "-s=VAL:DIR", :argument_name).to eq "VAL"
        expect(opt "-s=:DIR", :argument_name).to eq "DIR"
        expect(opt "-s=DIR", :argument_name).to eq "DIR"
        expect(opt "-s=:EDIR", :argument_name).to eq "DIR"
        expect(opt "-s=EDIR", :argument_name).to eq "DIR"
        expect(opt "-s=:NDIR", :argument_name).to eq "DIR"
        expect(opt "-s=NDIR", :argument_name).to eq "DIR"
      end
      it "defaults path argument_name to 'PATH'" do
        expect(opt "-s=VAL:PATH", :argument_name).to eq "VAL"
        expect(opt "-s=:PATH", :argument_name).to eq "PATH"
        expect(opt "-s=PATH", :argument_name).to eq "PATH"
        expect(opt "-s=:EPATH", :argument_name).to eq "PATH"
        expect(opt "-s=EPATH", :argument_name).to eq "PATH"
        expect(opt "-s=:NPATH", :argument_name).to eq "PATH"
        expect(opt "-s=NPATH", :argument_name).to eq "PATH"
      end
    end
    context "with a list of values" do
      it "sets argument_type to EnumType" do
        expect(opt "-s=a,b,c", :argument_type).to be_a Grammar::EnumType
      end
      it "defaults argument_name to the list of values" do
        expect(opt "-s=VAL:a,b,c", :argument_name).to eq "VAL"
        expect(opt "-s=:a,b,c", :argument_name).to eq "a,b,c"
        expect(opt "-s=a,b,c", :argument_name).to eq "a,b,c"
      end
    end
  end
end

