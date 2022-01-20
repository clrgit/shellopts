
include ShellOpts

describe "Parser" do
end

def opt(source, method = nil)
  token = Token.new(:option, 1, 1, source)
  option = Grammar::Option.parse(nil, token)
  method ? option.send(method) : option
end

describe "Option#parse" do
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
  it "accepts --l,long and ++l,long" do
    expect { opt "--l,long" }.not_to raise_error
    expect { opt "++l,long" }.not_to raise_error
  end

  it "sets ident" # TODO

  context "sets name" do
    it "to the name of the first long option if present" do
      expect(opt "-s,long,more", :name).to eq "long"
    end
    it "and otherwise to the name of the first short option" do
      expect(opt "-s,t", :name).to eq "s"
    end
  end

  it "sets short_names" do
    expect(opt "--long", :short_names).to eq []
    expect(opt "-a,b", :short_names).to eq %w(a b)
    expect(opt "-a,b,long", :short_names).to eq %w(a b)
  end

  it "sets long_names" do
    expect(opt "-a", :long_names).to eq []
    expect(opt "--long,more", :long_names).to eq %w(long more)
    expect(opt "-a,long,more", :long_names).to eq %w(long more)
  end

  it "sets repeatable?" do
    expect(opt "-v", :repeatable?).to eq false
    expect(opt "+v", :repeatable?).to eq true
    expect(opt "--verbose", :repeatable?).to eq false
    expect(opt "++verbose", :repeatable?).to eq true
  end

  it "sets argument?" do
    expect(opt "-s", :argument?).to eq false
    expect(opt "-s=SOME", :argument?).to eq true
  end

  context "without an argument" do
    it "sets argument_type to the default" do
      expect(opt "-s=SOME", :argument_type).to be_a Grammar::ArgumentType
    end
  end

  context "with an argument" do
    it "accepts non-interpreted arguments" do
      src = "-s=<some-value>"
      expect { opt src }.not_to raise_error
      option = opt src
      expect(option.argument?).to eq true
      expect(option.argument_name).to eq "<some-value>"
      expect(option.argument_type).to be_a Grammar::ArgumentType
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
      it "sets argument_type to IntegerArgument" do
        expect(opt "-s=VAL:#", :argument_type).to be_a Grammar::IntegerArgument
        expect(opt "-s=:#", :argument_type).to be_a Grammar::IntegerArgument
        expect(opt "-s=#", :argument_type).to be_a Grammar::IntegerArgument
      end

      it "defaults argument_name to 'INT'" do
        expect(opt "-s=VAL:#", :argument_name).to eq "VAL"
        expect(opt "-s=:#", :argument_name).to eq "INT"
        expect(opt "-s=#", :argument_name).to eq "INT"
      end
    end
    context "with a '$' argument_type specifier" do
      it "sets argument_type to FloatArgument" do
        expect(opt "-s=VAL:$", :argument_type).to be_a Grammar::FloatArgument
        expect(opt "-s=:$", :argument_type).to be_a Grammar::FloatArgument
        expect(opt "-s=$", :argument_type).to be_a Grammar::FloatArgument
      end

      it "defaults argument_name to 'NUM'" do
        expect(opt "-s=VAL:$", :argument_name).to eq "VAL"
        expect(opt "-s=:$", :argument_name).to eq "NUM"
        expect(opt "-s=$", :argument_name).to eq "NUM"
      end
    end
    context "with a keyword specifier" do
      it "sets argument_type to FileArgument" do
        expect(opt "-s=VAL:FILE", :argument_type).to be_a Grammar::FileArgument
        expect(opt "-s=:FILE", :argument_type).to be_a Grammar::FileArgument
        expect(opt "-s=FILE", :argument_type).to be_a Grammar::FileArgument
      end
      it "defaults file or file path argument_name to 'FILE'" do
        expect(opt "-s=VAL:FILE", :argument_name).to eq "VAL"
        expect(opt "-s=:FILE", :argument_name).to eq "FILE"
        expect(opt "-s=FILE", :argument_name).to eq "FILE"
      end
      it "defaults directory or directory path argument_name to 'DIR'" do
        expect(opt "-s=VAL:DIR", :argument_name).to eq "VAL"
        expect(opt "-s=:DIR", :argument_name).to eq "DIR"
        expect(opt "-s=DIR", :argument_name).to eq "DIR"
      end
      it "defaults node argument_name to 'PATH'" do
        expect(opt "-s=VAL:NODE", :argument_name).to eq "VAL"
        expect(opt "-s=:NODE", :argument_name).to eq "PATH"
        expect(opt "-s=NODE", :argument_name).to eq "PATH"
      end
      it "defaults path, file path, or directory path argument_name to 'PATH'" do
        expect(opt "-s=VAL:PATH", :argument_name).to eq "VAL"
        expect(opt "-s=:PATH", :argument_name).to eq "PATH"
        expect(opt "-s=:FILEPATH", :argument_name).to eq "PATH"
        expect(opt "-s=FILEPATH", :argument_name).to eq "PATH"
        expect(opt "-s=:DIRPATH", :argument_name).to eq "PATH"
        expect(opt "-s=DIRPATH", :argument_name).to eq "PATH"
      end
    end
    context "with a list of values" do
      it "sets argument_type to EnumArgument" do
        expect(opt "-s=a,b,c", :argument_type).to be_a Grammar::EnumArgument
      end
      it "defaults argument_name to the list of values" do
        expect(opt "-s=VAL:a,b,c", :argument_name).to eq "VAL"
        expect(opt "-s=:a,b,c", :argument_name).to eq "a,b,c"
        expect(opt "-s=a,b,c", :argument_name).to eq "a,b,c"
      end
    end
  end
end

