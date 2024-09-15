
require 'fileutils'

include ShellOpts::Grammar

describe "ShellOpts" do
  describe "Grammar" do
    describe "FileArgument" do
      def match(kind, node)
        matcher = FileArgument.new(kind)
        matcher.match?("opt", node) || false
      end

      def convert(kind, value)
        matcher = FileArgument.new(kind)
        matcher.convert(value)
      end

      def root() "spec/tmpdir" end

      def file() root + "/file" end
      def dir() root + "/dir" end
      def path() root + "/path" end # A symlink

      def nfile() root + "/nfile" end
      def ndir() root + "/ndir" end
      def npath() root + "/npath" end

      def stdin() "/dev/stdin" end
      def stdout() "/dev/stdout" end

      def tty() root + "/cdev" end
      def socket() "/dev/log" end
      def null() root + "/not_here/node" end

      def readonly() root + "/readonly" end
      def writeonly() root + "/writeonly" end

      def readonlydir() root + "/readonlydir" end
      def readonlydirnfile() readonlydir + "/nfile" end
      def readonlydirndir() readonlydir + "/ndir" end

      def message(type, file)
        arg = FileArgument.new(type)
        arg.match?("--alias", file)
        arg.message
      end

      before(:all) {
        FileUtils.rm_rf root

        FileUtils.mkdir_p root
        FileUtils.touch file

        FileUtils.mkdir_p readonlydir
        FileUtils.chmod "ugo=r-x", readonlydir

        FileUtils.mkdir dir
        FileUtils.ln_s "/dev/tty", tty
        FileUtils.touch readonly
        FileUtils.chmod "ugo=r", readonly
        FileUtils.touch writeonly
        FileUtils.chmod "ugo=w", writeonly
      }

      # Only remove temporary directory if all tests succeeded
      after(:all) { |example_group|
        all_groups = example_group.class.descendants
        failed_examples = all_groups.map(&:examples).flatten.select(&:exception)
        FileUtils.rm_rf root if failed_examples.empty?
      }

      context "when kind is :file" do
        it "accepts an existing file" do
          expect(match(:file, file)).to eq true
        end
        it "accepts a missing file" do
          expect(match(:file, nfile)).to eq true
        end
        it "accepts /dev/stdout, /dev/stderr, and /dev/null" do
          arg = FileArgument.new(:file)
          expect(arg.match?("opt", "/dev/stdout")).to eq true
          expect(arg.match?("opt", "/dev/stderr")).to eq true
          expect(arg.match?("opt", "/dev/null")).to eq true
        end
        it "fails if not a regular file" do
          expect(match(:file, dir)).to eq false
          expect(message :file, dir).to eq "#{dir} is not a regular file"
        end
        it "fails if enclosing directory doesn't exists" do
          expect(match(:file, dir)).to eq false
          expect(message :file, null).to eq "Illegal path - #{null}"
        end
      end

      context "when kind is :dir" do
        it "accepts an existing dir" do
          expect(match(:dir, dir)).to eq true
        end
        it "accepts a missing dir" do
          expect(match(:dir, ndir)).to eq true
        end
        it "fails if not a regular dir" do
          expect(match(:dir, file)).to eq false
        end
        it "fails if enclosing directory doesn't exists" do
          expect(match(:dir, null)).to eq false
        end
      end

      context "when kind is :path" do
        it "accepts an existing file" do
          expect(match(:path, file)).to eq true
        end
        it "accepts an existing dir" do
          expect(match(:path, dir)).to eq true
        end
        it "accepts a missing node" do
          expect(match(:path, ndir)).to eq true
        end
        it "accepts /dev/stdout, /dev/stderr, and /dev/null" do
          arg = FileArgument.new(:path)
          expect(arg.match?("opt", "/dev/stdout")).to eq true
          expect(arg.match?("opt", "/dev/stderr")).to eq true
          expect(arg.match?("opt", "/dev/null")).to eq true
        end
        it "fails if not a regular file or directory" do
          expect(match(:path, tty)).to eq false
        end
        it "fails if enclosing directory doesn't exists" do
          expect(match(:path, null)).to eq false
        end
      end

      context "when kind is :efile" do
        it "accepts an existing file" do
          expect(match(:efile, file)).to eq true
        end
        it "accepts /dev/stdout, /dev/stderr, and /dev/null" do
          arg = FileArgument.new(:efile)
          expect(arg.match?("opt", "/dev/stdout")).to eq true
          expect(arg.match?("opt", "/dev/stderr")).to eq true
          expect(arg.match?("opt", "/dev/null")).to eq true
        end
        it "fails if file is not a regular  file" do
          expect(match(:efile, nfile)).to eq false
        end
        it "fails if not a regular file" do
          expect(match(:efile, dir)).to eq false
        end
      end

      context "when kind is :edir" do
        it "accepts an existing dir" do
          expect(match(:edir, dir)).to eq true
        end
        it "fails if dir is not a directory" do
          expect(match(:edir, ndir)).to eq false
        end
        it "fails if not a regular dir" do
          expect(match(:edir, file)).to eq false
        end
      end

      context "when kind is :epath" do
        it "accepts an existing file" do
          expect(match(:epath, file)).to eq true
        end
        it "accepts an existing dir" do
          expect(match(:epath, dir)).to eq true
        end
        it "accepts /dev/stdout, /dev/stderr, and /dev/null" do
          arg = FileArgument.new(:epath)
          expect(arg.match?("opt", "/dev/stdout")).to eq true
          expect(arg.match?("opt", "/dev/stderr")).to eq true
          expect(arg.match?("opt", "/dev/null")).to eq true
        end
        it "fails if node is missing" do
          expect(match(:epath, ndir)).to eq false
        end
        it "fails if not a regular file or directory" do
          expect(match(:epath, tty)).to eq false
        end
      end

      context "when kind is :nfile" do
        it "fails if file exists" do
          expect(match(:nfile, file)).to eq false
        end
        it "accepts a missing file" do
          expect(match(:nfile, nfile)).to eq true
        end
        it "accepts /dev/stdout, /dev/stderr, and /dev/null" do
          arg = FileArgument.new(:nfile)
          expect(arg.match?("opt", "/dev/stdout")).to eq true
          expect(arg.match?("opt", "/dev/stderr")).to eq true
          expect(arg.match?("opt", "/dev/null")).to eq true
        end
        it "fails if enclosing directory doesn't exists" do
          expect(match(:nfile, null)).to eq false
        end
      end

      context "when kind is :ndir" do
        it "fails if file exists" do
          expect(match(:ndir, dir)).to eq false
        end
        it "accepts a missing dir" do
          expect(match(:ndir, ndir)).to eq true
        end
        it "fails if enclosing directory doesn't exists" do
          expect(match(:ndir, null)).to eq false
        end
      end

      context "when kind is :npath" do
        it "fails if path exists" do
          expect(match(:npath, file)).to eq false
          expect(match(:npath, dir)).to eq false
        end
        it "accepts a missing file or directory" do
          expect(match(:npath, ndir)).to eq true
        end
        it "fails if enclosing directory doesn't exists" do
          expect(match(:npath, null)).to eq false
        end
        it "accepts /dev/stdout, /dev/stderr, and /dev/null" do
          arg = FileArgument.new(:npath)
          expect(arg.match?("opt", "/dev/stdout")).to eq true
          expect(arg.match?("opt", "/dev/stderr")).to eq true
          expect(arg.match?("opt", "/dev/null")).to eq true
        end
      end

      context "when kind is :ifile" do
        it "accepts a readable existing file" do
          expect(match(:ifile, readonly)).to eq true
        end
        it "apply special meaning to a '-' argument" do
          expect(match(:ifile, "-")).to eq true
        end
        it "rejects an unreadable existing file" do
          expect(match(:ifile, writeonly)).to eq false
        end
        it "rejects directories" do
          expect(match(:ifile, dir)).to eq false
        end
        it "fails if the file doesn't exists" do
          expect(match(:ifile, null)).to eq false
        end
        it "fails if the file isn't readable" do
          expect(match(:ifile, writeonly)).to eq false
        end
        it "accepts /dev/stdin and /dev/null" do
          expect(match(:ifile, "/dev/stdin")).to eq true
          expect(match(:ifile, "/dev/null")).to eq true
        end
        it "rejects /dev/stdout and /dev/stderr" do
          expect(match(:ifile, "/dev/stdout")).to eq false
          expect(match(:ifile, "/dev/stderr")).to eq false
        end
        it "converts '-' to /dev/stdin" do
          expect(convert(:ifile, "-")).to eq "/dev/stdin"
        end
      end

      context "when kind is :ofile" do
        it "accepts a writable existing file" do
          expect(match(:ofile, writeonly)).to eq true
        end
        it "accepts a new file" do
          expect(match(:ofile, file)).to eq true
        end
        it "apply special meaning to a '-' argument" do
          expect(match(:ofile, "-")).to eq true
        end
        it "rejects an unwritable existing file" do
          expect(match(:ofile, readonly)).to eq false
        end
        it "rejects directories" do
          expect(match(:ofile, dir)).to eq false
        end
        it "rejects /dev/stdin" do
          expect(match(:ofile, "/dev/stdin")).to eq false
        end
        it "accepts /dev/stdout, /dev/stderr, and /dev/null" do
          expect(match(:ofile, "/dev/stdout")).to eq true
          expect(match(:ofile, "/dev/stderr")).to eq true
          expect(match(:ofile, "/dev/null")).to eq true
        end
        it "converts '-' to /dev/stdout" do
          expect(convert(:ofile, "-")).to eq "/dev/stdout"
        end
      end

      describe "#message" do
        it "creates an error message if #match? failed" do
          # From #match?
          expect(message :ifile, stdout).to eq "Can't read #{stdout}"
          expect(message :ofile, stdin).to eq "Can't write to #{stdin}"
          expect(message :dir, stdout).to eq "#{stdout} is not a directory"

          # From #match_path
          expect(message :nfile, readonly).to eq "Won't overwrite spec/tmpdir/readonly"
          expect(message :path, socket).to eq "#{socket} is not a file or a directory"
          expect(message :ifile, dir).to eq "#{dir} is not a device file"

          expect(message :ifile, writeonly).to eq "Can't read #{writeonly}"
          expect(message :ofile, readonly).to eq "Can't write to #{readonly}"
          expect(message :nfile, file).to eq "Won't overwrite #{file}"
          expect(message :file, dir).to eq "#{dir} is not a regular file"
          expect(message :dir, file).to eq "#{file} is not a directory"

          expect(message :file, null).to eq "Illegal path - #{null}"
          expect(message :nfile, readonlydirnfile).to eq "Can't create file #{readonlydirnfile}"
          expect(message :ndir, readonlydirndir).to eq "Can't create directory #{readonlydirndir}"
          expect(message :efile, nfile).to eq "Can't find #{nfile}"
          expect(message :edir, ndir).to eq "Can't find #{ndir}"
        end
      end
    end

    describe "EnumArgument" do
      let(:e) { EnumArgument.new %w(alpha beta) }

      describe "#values" do
        it "returns a list of allowed values" do
          expect(e.values).to eq %w(alpha beta)
        end
      end
      describe "#match?" do
        it "returns true if the given value is an enum" do
          expect(e.match?("name", "alpha")).to eq true
        end
        context "when the given value is not an enum" do
          it "returns false" do
            expect(e.match?("name", "fehu")).to eq false
          end
        end
      end
      describe "#value?" do
        it "returns true if the given value is an enum and false otherwise" do
          expect(e.value?("alpha")).to eq true
          expect(e.value?("futhark")).to eq false
        end
      end
      describe "#message" do
        it "creates an error message if #match? failed" do
          e.match?("name", "futhark")
          expect(e.message).to eq "Illegal value - futhark"
        end
      end
    end
  end
end















