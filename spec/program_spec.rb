
include ShellOpts

describe "Command" do
  describe "#[]" do
    let(:opts) { ShellOpts::ShellOpts.process(spec, args).first }

    context "when the key is an option" do
      let(:spec) { "-a -A cmd1! -b -B cmd1.cmd2! -c -C" }
      let(:args) { %w(-a cmd1 -b cmd2 -c) }

      it "returns the associated option object" do
        expect(opts[:a]).to be_a ShellOpts::Option
        expect(opts[:"cmd1.b"]).to be_a ShellOpts::Option
        expect(opts[:"cmd1.cmd2.c"]).to be_a ShellOpts::Option
      end
      it "returns nil if the option wasn't present" do
        expect(opts[:A]).to eq nil
        expect(opts[:"cmd1.B"]).to eq nil
        expect(opts[:"cmd1.cmd2.C"]).to eq nil
      end
      context "when the option is repeatable" do
        let(:spec) { "+r=ARG +R=ARG" }
        let(:args) { %w(-r 1 -r 2) }
        it "returns a list of options" do
          expect(opts[:r].map(&:class)).to eq [ShellOpts::Option, ShellOpts::Option]
          expect(opts[:r].map(&:argument)).to eq ["1", "2"]
        end
        it "returns an empty array if the option wasn't present" do
          expect(opts[:R]).to eq []
        end
      end
    end

    context "when the key is a command" do
      let(:spec) { "cmd1! cmd1.cmd2! cmd1.cmd2.cmd3! cmd4!" }
      let(:args) { %w(cmd1 cmd2) }
      
      it "returns the associated command" do
        expect(opts[:cmd1!].is_a?(ShellOpts::Command)).to eq true
        expect(opts[:"cmd1.cmd2!"].is_a?(ShellOpts::Command)).to eq true
      end
      it "returns nil if the option wasn't present" do
        expect(opts[:"cmd4!"]).to eq nil
        expect(opts[:"cmd1.cmd2.cmd3!"]).to eq nil
      end
    end

    context "when the key doesn't exists" do
      let(:spec) { "-a cmd1!" }
      let(:args) { %w(-a cmd1) }

      it "raises if the key doesn't exist" do
        expect { opts[:b] }.to raise_error ArgumentError
        expect { opts[:cmd2!] }.to raise_error ArgumentError
      end
    end
  end

  describe "Generic #<option> and #<option>? methods" do
    let(:spec) { "" }
    let(:argv) { [] }
    let(:opts) { 
      opts, args = ShellOpts::ShellOpts.process(spec, argv)
      opts
    }

    context "when the option is not repeatable" do
      context "when the option doesn't take an argument" do
        let(:spec) { "-a -b" }
        let(:argv) { %w(-a) }
        it "#<option>? returns true iff present" do
          expect(opts.a?).to eq true
          expect(opts.b?).to eq false
        end
        it "#<option> returns true iff present" do
          expect(opts.a).to eq true
          expect(opts.b).to eq false
        end
      end
      context "when the option has an optional argument" do
        let(:spec) { "-a=VAR? -b=VAR? -c=VAR?" }
        let(:argv) { %w(-aAVAR -b) }
        it "#<option>? returns true iff present" do
          expect(opts.a?).to eq true
          expect(opts.b?).to eq true
          expect(opts.c?).to eq false
        end
        it "#<option> returns the value if given" do
          expect(opts.a).to eq "AVAR"
        end
        it "#<option> returns nil if value is missing" do
          expect(opts.b).to eq nil
        end
        it "#<option> returns nil if option not present" do
          expect(opts.c).to eq nil
        end
      end
      context "when the option has a mandatory argument" do
        let(:spec) { "-a=VAR -b=VAR" }
        let(:argv) { %w(-aAVAR) }
        it "#<option>? returns true iff present" do
          expect(opts.a?).to eq true
          expect(opts.b?).to eq false
        end
        it "#<option> returns the value if option is present" do
          expect(opts.a).to eq "AVAR"
        end
        it "#<option> returns nil if option is not present" do
          expect(opts.b).to eq nil
        end
      end
    end

    context "when the option is repeatable" do
      context "when the option doesn't take an argument" do
        let(:spec) { "+a +b +c" }
        let(:argv) { %w(-a -b -b) }
        it "#<option>? returns true iff present" do
          expect(opts.a?).to eq true
          expect(opts.b?).to eq true
          expect(opts.c?).to eq false
        end
        it "#<option> returns count of occurrences" do
          expect(opts.a).to eq 1
          expect(opts.b).to eq 2
          expect(opts.c).to eq 0
        end
      end
      context "when the option has an optional argument" do
        let(:spec) { "+a=VAR? +b=VAR? +c=VAR? +d=VAR? +e=VAR?" }
        let(:argv) { %w(-aAVAR -bBVAR1 -bBVAR2 -c -d -d) }
        it "#<option>? returns true iff present" do
          expect(opts.a?).to eq true
          expect(opts.b?).to eq true
          expect(opts.c?).to eq true
          expect(opts.d?).to eq true
          expect(opts.e?).to eq false
        end
        context "when the option is present" do
          it "#<option> returns an array of values or nil if missing" do
            expect(opts.a).to eq %w(AVAR)
            expect(opts.b).to eq %w(BVAR1 BVAR2)
            expect(opts.c).to eq [nil]
            expect(opts.d).to eq [nil, nil]
          end
        end
        context "when the option is not present" do
          it "#<option> returns the empty array" do
            expect(opts.e).to eq []
          end
        end
      end
      context "when the option has a mandatory argument" do
        let(:spec) { "+a=VAR +b=VAR +c=VAR" }
        let(:argv) { %w(-aAVAR -bBVAR1 -bBVAR2) }
        it "#<option>? returns true iff present" do
          expect(opts.a?).to eq true
          expect(opts.b?).to eq true
          expect(opts.c?).to eq false
        end
        context "when the option is present" do
          it "#<option> returns an array of values" do
            expect(opts.a).to eq %w(AVAR)
            expect(opts.b).to eq %w(BVAR1 BVAR2)
          end
        end
        context "when the option is not present" do
          it "#<option> returns the empty array" do
            expect(opts.c).to eq []
          end
        end
      end
    end
  end

  describe "#subcommand!" do
    let(:opts) { 
      spec = "cmd1! cmd2!"
      argv = %w(cmd1)
      opts, args = ShellOpts::ShellOpts.process(spec, argv)
      opts
    }

    it "returns the subcommand object" do
      expect(opts.subcommand!.is_a? ShellOpts::Command).to eq true
    end
  end

  describe "#subcommand" do
    let(:opts) { 
      spec = "cmd1! cmd2!"
      argv = %w(cmd1)
      opts, args = ShellOpts::ShellOpts.process(spec, argv)
      opts
    }

    it "returns the subcommand identifier" do
      expect(opts.subcommand).to eq :cmd1!
    end
  end

  describe "#subcommands!" do
    let(:argv) { %w(cmd1 cmd2) }
    let(:opts) { 
      spec = "cmd1! cmd2!"
      opts, args = ShellOpts::ShellOpts.process(spec, argv)
      opts
    }

    it "returns the subcommand objects" do
      expect(opts.subcommands!.all? { |cmd| cmd.is_a?(ShellOpts::Command) }).to eq true
    end

    context "when no subcommand was present" do
      let(:argv) { [] }

      it "returns the empty array" do
        expect(opts.subcommands!).to eq []
      end
    end
  end

  describe "#subcommands" do
    let(:argv) { %w(cmd1 cmd2) }
    let(:opts) { 
      spec = "cmd1! cmd1.cmd2!"
      opts, args = ShellOpts::ShellOpts.process(spec, argv)
      opts
    }

    it "returns the subcommand uid" do
      expect(opts.subcommands).to eq :"cmd1.cmd2!"
    end

    context "when no subcommand is present" do
      let(:argv) { [] }

      it "returns nil" do
        expect(opts.subcommands).to eq nil
      end
      
    end
  end

  describe "#to_h" do
    let(:spec) { "-a -b -c=VAR -d=VAR -e=VAR? -f=VAR? -g=VAR?" }
    let(:argv) { %w(-a -cCVAR -eEVAR -f) }
    let(:opts) { 
      opts, args = ShellOpts::ShellOpts.process(spec, argv)
      opts
    }
    let(:hash) { opts.to_h }

    context "returns a Hash of options" do
      it "with a key for each option on the command line"

      context "when the option is not repeatable" do
        let(:spec) { "-a -b -c=VAR -d=VAR -e=VAR? -f=VAR? -g=VAR?" }

        context "when the option has no argument" do
          it "the value is nil" do
            expect(hash[:a]).to eq nil
          end
        end
        context "when the option has a mandatory argument" do
          it "the value is the argument" do
            expect(hash[:c]).to eq "CVAR"
          end
        end
        context "when the option has a optional argument" do
          it "the value is the argument if present" do
            expect(hash[:e]).to eq "EVAR"
          end
          it "the value is nil if the argument is missing" do
            expect(hash[:f]).to eq nil
          end
        end
      end

      context "when the option is repeatable" do
        context "when the option has no argument" do
          let(:spec) { "+a +b" }
          let(:argv) { %w(-a -a -b) }
          
          it "the value is the number of occurrences" do
            expect(hash).to eq a: 2, b: 1
          end
        end
        context "when the option has a mandatory argument" do
          let(:spec) { "+a=VAR +b=VAR" }
          let(:argv) { %w(-aAVAR -bBVAR1 -bBVAR2) }
          it "the value is an array of arguments" do
            expect(hash).to eq a: %w(AVAR), b: %w(BVAR1 BVAR2)
          end
        end
        context "when the option has an optional argument" do
          def hash(a = argv)
            opts, args = ShellOpts.process(spec, a)
            opts.to_h
          end

          context "the value is an array of arguments" do
            let(:spec) { "+a=VAR? +b=VAR?" }
            context "the array element" do
              it "is the option argument if present" do
                expect(hash %w(-aAVAR -bBVAR1 -bBVAR2)).to eq a: %w(AVAR), b: %w(BVAR1 BVAR2)
              end
              it "is nil if the argument is missing" do
                expect(hash %w(-a -b -b)).to eq a: [nil], b: [nil, nil]
              end
            end
          end
        end
      end
    end
  end

  describe "#to_h?" do
    let(:spec) { "-a -b -c=VAR -d=VAR -e=VAR? -f=VAR? -g=VAR?" }
    let(:argv) { %w(-a -cCVAR -eEVAR -f) }
    let(:opts) { 
      opts, args = ShellOpts::ShellOpts.process(spec, argv)
      opts
    }
    let(:hash) { opts.to_h? }

    context "returns a Hash of options" do
      it "with a key for each option on the command line"

      context "when the option is not repeatable" do
        let(:spec) { "-a -b -c=VAR -d=VAR -e=VAR? -f=VAR? -g=VAR?" }

        context "when the option has no argument" do
          it "the value is true" do
            expect(hash[:a]).to eq true
          end
        end
        context "when the option has a mandatory argument" do
          it "the value is the argument" do
            expect(hash[:c]).to eq "CVAR"
          end
        end
        context "when the option has a optional argument" do
          it "the value is the argument if present" do
            expect(hash[:e]).to eq "EVAR"
          end
          it "the value is nil if the argument is missing" do
            expect(hash[:f]).to eq nil
          end
        end
      end

      context "when the option is repeatable" do
        context "when the option has no argument" do
          let(:spec) { "+a +b" }
          let(:argv) { %w(-a -a -b) }
          
          it "the value is the number of occurrences" do
            expect(hash).to eq a: 2, b: 1
          end
        end
        context "when the option has a mandatory argument" do
          let(:spec) { "+a=VAR +b=VAR" }
          let(:argv) { %w(-aAVAR -bBVAR1 -bBVAR2) }
          it "the value is an array of arguments" do
            expect(hash).to eq a: %w(AVAR), b: %w(BVAR1 BVAR2)
          end
        end
        context "when the option has an optional argument" do
          def hash(a = argv)
            opts, args = ShellOpts.process(spec, a)
            opts.to_h
          end

          context "the value is an array of arguments" do
            let(:spec) { "+a=VAR? +b=VAR?" }
            context "the array element" do
              it "is the option argument if present" do
                expect(hash %w(-aAVAR -bBVAR1 -bBVAR2)).to eq a: %w(AVAR), b: %w(BVAR1 BVAR2)
              end
              it "is nil if the argument is missing" do
                expect(hash %w(-a -b -b)).to eq a: [nil], b: [nil, nil]
              end
            end
          end
        end
      end
    end
  end

# describe "#to_h" do
#   let(:opts) { 
#     spec = "-a -b=VAL -c"
#     argv = %w(-a -bvalue)
#     opts, args = ShellOpts::ShellOpts.process(spec, argv)
#     opts
#   }
#
#   it "returns the used options and their values as a hash" do
#     expect(opts.to_h).to eq a: true, b: "value"
#   end
#   context "when given a list of options" do
#     it "returns the given options as a hash" do
#       expect(opts.to_h :a).to eq a: true
#     end
#     it "ignores missing options" do
#       expect(opts.to_h :a, :b, :c).to eq a: true, b: "value"
#     end
#   end
# end
end
