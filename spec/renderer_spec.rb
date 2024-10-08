
include ShellOpts

describe ShellOpts do
  def compile(source)
    shellopts = ShellOpts::ShellOpts.new(name: "rspec", help: false, version: false)
    shellopts.compile(source)
    shellopts.grammar
  end

  describe "Grammar::Option" do
    def opt(source)
      compile(source).options.first
    end

    def opts(source)
      compile(source).options
    end

    describe "#render" do
      def str(src) opts(src).map { |opt| opt.render(:enum) }.join(' ') end

      it "renders short mandatory values" do
        s = %(
          -a=ARG
          -b=#
          -c=$
          -d=red,blue
        )
        r = "-a ARG -b INT -c NUM -d red,blue"
        expect(str(s)).to eq r
      end

      it "renders long mandatory values" do
        s = %(
          --aa=ARG
          --bb=#
          --cc=$
          --dd=red,blue
        )
        r = "--aa=ARG --bb=INT --cc=NUM --dd=red,blue"
        expect(str(s)).to eq r
      end

      it "renders short optional values" do
        s = %(
          -a=ARG?
          -b=#?
          -c=$?
          -d=red,blue?
        )
        r = "-a [ARG] -b [INT] -c [NUM] -d [red,blue]"
        expect(str(s)).to eq r
      end

      it "renders long optional values" do
        s = %(
          -aa=ARG?
          -bb=#?
          -cc=$?
          -dd=red,blue?
        )
        r = "--aa[=ARG] --bb[=INT] --cc[=NUM] --dd[=red,blue]"
        expect(str(s)).to eq r
      end

      it "renders short mandatory array values" do
        s = %(
          -a=ARG,
          -b=#,
          -c=$,
          -d=red,blue,
        )
        r = "-a ARG... -b INT... -c NUM... -d red,blue..."
        expect(str(s)).to eq r
      end

      it "renders long mandatory array values" do
        s = %(
          --aa=ARG,
          --bb=#,
          --cc=$,
          --dd=red,blue,
        )
        r = "--aa=ARG... --bb=INT... --cc=NUM... --dd=red,blue..."
        expect(str(s)).to eq r
      end


      it "renders short optional array values" do
        s = %(
          -a=ARG,?
          -b=#?,
          -c=$,?
          -d=red,blue?,
        )
        r = "-a [ARG...] -b [INT...] -c [NUM...] -d [red,blue...]"
        expect(str(s)).to eq r
      end
      it "renders long optional array values" do
        s = %(
          -aa=ARG?,
          -bb=#,?
          -cc=$?,
          -dd=red,blue,?
        )
        r = "--aa[=ARG...] --bb[=INT...] --cc[=NUM...] --dd[=red,blue...]"
        expect(str(s)).to eq r
      end
    end
  end

  describe "Grammar::Command" do
    describe "render :abbr" do
      def str(source, width)
        compile(source).render(:abbr, width)
      end

      it "abbreviates options" do
        s = "-a,alpha -b,beta -- ARG1 ARG2"
        r = "rspec [OPTIONS] ARG1 ARG2"
        expect(str(s, r.size)).to eq r
      end
    end
    describe "render :single" do
      def str(source, width)
        compile(source).render(:single, width)
      end

      it "prefers long options over short options" do
        s = "-a,alpha -b,beta -- ARG1 ARG2"
        r = "rspec --alpha --beta ARG1 ARG2"
        expect(str(s, r.size)).to eq r
        r = "rspec -a -b ARG1 ARG2"
        expect(str(s, r.size)).to eq r
      end

      it "prefers short commands over compact commands" do
        s = "cmd1! cmd2! cmd3!"
        r = "rspec [cmd1|cmd2|cmd3]"
        expect(str(s, r.size)).to eq r
        r = "rspec [COMMANDS]"
        expect(str(s, r.size)).to eq r
      end

      it "prefers short options over compact commands" do
        s = "-a,alpha -b,beta cmd1! cmd2! cmd3!"
        r = "rspec --alpha --beta [cmd1|cmd2|cmd3]"
        expect(str(s, r.size)).to eq r
        r = "rspec -a -b [cmd1|cmd2|cmd3]"
        expect(str(s, r.size)).to eq r
      end

      it "prefers compact commands over compact options" do
        s = "--alpha --beta cmd1! cmd2! cmd3!"
        r = "rspec --alpha --beta [cmd1|cmd2|cmd3]"
        expect(str(s, r.size)).to eq r
        r = "rspec --alpha --beta [COMMANDS]"
        expect(str(s, r.size)).to eq r
      end

      it "does max. compaction if anything else fails" do
        s = "--alpha --beta -- ARG1 ARG2 cmd1! cmd2! cmd3!"
        r = "rspec [OPTIONS] [COMMANDS] ARGS..."
        expect(str(s, r.size)).to eq r
      end
    end

    describe "render :enum" do
      def str(source, width)
        compile(source).render(:enum, width).join("\n") + "\n"
      end

      it "renders each argument description on a line" do
        s = %(
          -- ARG1
          -- ARG2
        )
        r = undent %(
          rspec ARG1
          rspec ARG2
        )
        expect(str(s, 10)).to eq r
      end
    end

    describe "render :multi" do
      def str(source, width)
        compile(source).render(:multi, width)
      end

      it "tries to emit a single line" do
        s = "-a,alpha -b,beta -- ARG1 ARG2"
        r = ["rspec --alpha --beta ARG1 ARG2"]
        expect(str(s, r.first.size)).to eq r

        r = ["rspec -a -b ARG1 ARG2"]
        expect(str(s, r.first.size)).to eq r

        r = ["rspec -a -b ARG1 ARG2"]
        expect(str(s, r.first.size)).to eq r
      end

      it "splits on option and command/arguments boundary" do
        s = "-a,alpha -b,beta -- ARG1 ARG2"
        r = ["rspec --alpha --beta", "      ARG1 ARG2"]
        expect(str(s, r.first.size)).to eq r
      end

      it "aligns on the first option" do
        s = "--alpha --beta"
        r = ["rspec --alpha", "      --beta"]
        expect(str(s, r.first.size)).to eq r
      end
    end
  end
end

