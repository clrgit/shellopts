
include ShellOpts # FIXME: Dont

#module ShellOpts
# class Formatter
# end
#end

describe "Formatter" do
  def method_str(method, source, subject = nil)
    shellopts = ShellOpts::ShellOpts.new(help: false, version: false).compile(source)
    grammar = shellopts.compile(source)
    subject = subject ? shellopts.grammar[subject] : shellopts.grammar
    capture { ShellOpts::Formatter.send method, subject }
  end

  def capture(&block)
    save = $stdout
    begin
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = save
    end
  end

# l = w.size * count + count - 1
# l = count * (w.size + 1) - 1
# (l + 1) / (w.size + 1) = count

  describe "::compute_columns" do
    def words(width)
      word = "w"
      words = [word] * ((width - 1) / (word.size + 1) + 1)
      if word.size * words.size + words.size - 1 < width
        words[-1] += word
      end
      words
    end

    def doit(col1_width, col2_width, width: 80)
      col1 = "c" * col1_width
      col2 = words(col2_width)
      Formatter.compute_columns(width, [[col1, col2]])
    end

    it "sets first column to the length of the longest tuple element" do
      col1_size = Formatter::BRIEF_COL1_MIN_WIDTH + 1
      col1, col2 = doit col1_size, 1
      expect(col1).to eq col1_size
    end
    it "sets first column to at least BRIEF_COL1_MIN_WIDTH" do
      col1, col2 = doit 1, 1
      expect(col1).to eq Formatter::BRIEF_COL1_MIN_WIDTH
    end
    it "sets first column to at most BRIEF_COL1_MAX_WIDTH before compacting" do
      col1_size = Formatter::BRIEF_COL1_MAX_WIDTH
      col1, col2 = doit col1_size, 1
      expect(col1).to eq Formatter::BRIEF_COL1_MAX_WIDTH

      col1, col2 = doit col1_size + 1, 1
      expect(col1).to eq Formatter::BRIEF_COL1_MIN_WIDTH
    end

    it "sets second column to the remaining width" do
      width = 70
      col2_size= Formatter::BRIEF_COL2_MIN_WIDTH + 5
      col1, col2 = doit 1, col2_size, width: 70
      expect(col2).to eq (width - Formatter::BRIEF_COL1_MIN_WIDTH - Formatter::BRIEF_COL_SEP)
    end

    it "sets second column to at least BRIEF_COL2_MIN_WIDTH" do
      width = 10
      col1, col2 = doit 1, 1, width: width
      expect(col2).to eq Formatter::BRIEF_COL2_MIN_WIDTH
    end

    it "sets second column to at most BRIEF_COL2_MAX_WIDTH" do
      width = 100
      col2_size = Formatter::BRIEF_COL2_MAX_WIDTH + 1
      col1, col2 = doit 1, col2_size, width: width
      expect(col2).to eq Formatter::BRIEF_COL2_MAX_WIDTH
    end

    context "when width it too small" do
      it "shrinks option/command column"
    end
  end

  describe "::usage" do
    def str(source, subject = nil)
      method_str(:usage, source, subject)
    end

    it "puts usage description" do
      s = %(
        -a
        cmd!
          subcmd!
            A description
      )
      r = undent %(
        Usage: rspec -a [cmd]
      )
      expect(str(s)).to eq r

      s = %(
        -a
        cmd!
          -b
          subcmd!
            A description
      )
      r = undent %(
        Usage: rspec cmd -b [subcmd]
      )
      expect(str(s, :cmd!)).to eq r
    end

    it "puts a line for each argument description" do
      s = %(
        -- ARG1
        -- ARG2
      )
      r = undent %(
        Usage: rspec ARG1
               rspec ARG2
      )
      expect(str(s)).to eq r

      s = %(
        cmd!
          -- ARG1
          -- ARG2
      )
      r = undent %(
        Usage: rspec cmd ARG1
               rspec cmd ARG2
      )
      expect(str(s, :cmd!)).to eq r
    end
  end

  describe "::brief" do
    def str(source, subject = nil)
      method_str(:brief, source, subject)
    end

    it "prints a brief description" do
      s = %(
        -a Brief A
          Option description

        -b Brief B
          Option description

        cmd1! Command 1
          Command description

          -c                    Brief C
          -d                    Brief D

          cmd11!                Command 11
          cmd12!                Command 12

        cmd2! Command 2
      )
      r = undent %(
        Usage
          rspec -a -b [cmd1|cmd2]

        Options
          -a                        Brief A
          -b                        Brief B

        Commands
          cmd1 -c -d [cmd11|cmd12]  Command 1
          cmd2                      Command 2
      )
      expect(str(s)).to eq r

      r = undent %(
        Command 1

        Usage
          rspec cmd1 -c -d [cmd11|cmd12]

        Options
          -c                    Brief C
          -d                    Brief D

        Commands
          cmd11                 Command 11
          cmd12                 Command 12
      )
      expect(str(s, :cmd1!)).to eq r
    end

    context "when given a very long command brief MARK" do
      def brief(source, subject = nil)
        method_str(:brief, source, subject)
      end
      it "breaks line the right way" do
        src = %(
          cmd!
              this is a very long brief this is a very long brief  this is a very long brief this is a very long brief this is a very long brief this is a very long brief
        )
        r = undent %(
          Usage
            rspec [cmd]

          Commands
            cmd                   this is a very long brief this is a
                                  very long brief this is a very long
                                  brief this is a very long brief this
                                  is a very long brief this is a very
                                  long brief

        )
        Formatter.width = 60
        expect(brief(src)).to eq r
        Formatter.width = nil
      end
    end

  end

  describe "::help" do
    def str(source, subject = nil)
      method_str(:help, source, subject)
    end

    context "when subject is ..." do
      source = %(
        cmd!
          A command

          cmd.nested!
            A nested command

        cmd.subcmd!
          A subcommand
      )

      context "nil" do
        it "keeps the indentation levels of subcommands" do
          r = undent %(
            NAME
                rspec

            USAGE
                rspec [cmd]

            COMMANDS
                cmd [nested|subcmd]
                    A command

                    nested
                        A nested command

                cmd subcmd
                    A subcommand

          )
          expect(str(source)).to eq r
        end
      end

      context "a subcommand" do
        it "keeps subcommands on the same level" do
          r = undent %(
            NAME
                rspec cmd - A command

            USAGE
                rspec cmd [nested|subcmd]

            DESCRIPTION
                A command

            COMMANDS
                nested
                    A nested command

                subcmd
                    A subcommand
          )
          expect(str(source, "cmd")).to eq r
        end
      end
    end

    context "when source contains sections" do
      it "pluralizes the option section title if needed" do
        source = %(
          -a
        )
        r = undent %(
          NAME
              rspec

          USAGE
              rspec -a

          OPTION
              -a
        )
        expect(str(source)).to eq r

        source = %(
          -a
          -b
        )
        r = undent %(
          NAME
              rspec

          USAGE
              rspec -a -b

          OPTIONS
              -a

              -b
        )
        expect(str(source)).to eq r
      end

      it "pluralizes the command section title if needed" do
        source = %(
          cmd1!
        )
        r = undent %(
          NAME
              rspec

          USAGE
              rspec [cmd1]

          COMMAND
              cmd1
        )
        expect(str(source)).to eq r

        source = %(
          cmd1!
          cmd2!
        )
        r = undent %(
          NAME
              rspec

          USAGE
              rspec [cmd1|cmd2]

          COMMANDS
              cmd1

              cmd2
        )
        expect(str(source)).to eq r
      end
    end

    context "when source contains an explicit section" do
      it "only outputs the section once" do
        source = %(
          -a
          COMMANDS
          text
          cmd!
        )
        r = undent %(
          NAME
              rspec - text

          USAGE
              rspec -a [cmd]

          OPTION
              -a

          COMMAND
              text

              cmd
        )
        expect(str(source)).to eq r
      end

      it "ignores plurality of the explicit section(s)" do
        source = %(
          OPTIONS
          -a
          COMMANDS
          cmd!
        )
        r = undent %(
          NAME
              rspec

          USAGE
              rspec -a [cmd]

          OPTION
              -a

          COMMAND
              cmd
        )
        expect(str(source)).to eq r
      end
    end

    context "when given a long definition" do
      def str(width)
        src = "-a,a_long_a_option -b,a_long_b_option a_long_command_name! another_long_command_name!"
        stub_const("ShellOpts::Formatter::HELP_MAX_WIDTH", width)
        method_str(:help, src).sub(/.*USAGE\s*\n\s*(.*?)\s*\n\s*OPTIONS.*/m, '\1')
      end

      it "tries to keep on one line by compacting" do
        expect(str(80)).to eq "rspec -a -b [a_long_command_name|another_long_command_name]"
      end

      it "only compact commands if they doesn't fit on a line" do
        r = "rspec -a -b [COMMANDS]"
        expect(str(40)).to eq r
      end

      it "uses muliple lines otherwise" do
        r = "rspec --a_long_a_option --a_long_b_option\n          [a_long_command_name|another_long_command_name]"
        expect(str(50)).to eq r
      end
    end

    context "when subcommands contains options" do
      context "when the options are declared on the same line as the subcommand" do
        it "list them one the same line as the command" do
          source = %(
            cmd! -a,alpha -b,beta -- ARG
          )
          r = undent %(
          NAME
              rspec

          USAGE
              rspec [cmd]

          COMMAND
              cmd --alpha --beta ARG
          )
          expect(str(source)).to eq r
        end
      end
      context "when the options are declared separately" do
        it "lists them separately" do
          source = %(
            cmd!
              -a,alpha
                A description of --alpha
              -b,beta
                A description of --beta
              -- ARG
          )
          r = undent %(
            NAME
                rspec

            USAGE
                rspec [cmd]

            COMMAND
                cmd [OPTIONS] ARG
                    -a, --alpha
                        A description of --alpha
                    -b, --beta
                        A description of --beta
          )
          expect(str(source)).to eq r
        end
      end
      it "should be more clever about inline vs. outlined options" # do
#       source = %(
#         cmd! -a,alpha
#           Description
#
#           -b,beta
#             Option description
#       )
#       r = undent %(
#         NAME
#             rspec
#
#         USAGE
#             rspec [cmd]
#
#         COMMAND
#             cmd -a [OPTIONS] ARG
#               Description
#
#               -b, --beta
#                   Option description
#       )
#       expect(str(source)).to eq r
#     end
    end


    it "Handles commands with virtual supercommand" do
      s = %(
        cmd.cmd1!
      )
      r = undent %(
        NAME
            rspec

        USAGE
            rspec [cmd]

        COMMAND
            cmd cmd1
      )
      expect(str(s)).to eq r
    end
  end
end


