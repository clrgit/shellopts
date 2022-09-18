
module ShellOpts
  class Lexer
    OPTION_RE = /--?\S/
    COMMAND_RE = /[a-z][a-z._-]*!/
    DESCR_RE = /--\s/
    SPEC_RE = /\+\+\s/
    BRIEF_RE = /@/

    SINGLE_LINE_WORDS = %w(-- ++ @)

#   DECL_RE = /^(?:-|--|\+|\+\+|(?:@(?:\s|$))|(?:[^\\!]\S*!(?:\s|$)))/
    DECL_RE = /^(?:#{OPTION_RE}|#{COMMAND_RE}|#{DESCR_RE}|#{SPEC_RE}|#{BRIEF_RE})/

    # Match argument spec words. The words should begin with at least two
    # uppercase letters. This makes it possible to say +opts.FILE_ARGUMENT+
    # because it can't conflict with a single letter uppercase option and long
    # options are always downcased internally (TODO). Rather primitive for now
    ARG_RE = /^[A-Z]{2,}$/

    SECTIONS = %w(NAME SYNOPSIS DESCRIPTION OPTIONS COMMANDS)
    SECTION_ALIASES = {
      "USAGE" => "SYNOPSIS",
      "OPTION" => "OPTIONS",
      "COMMAND" => "COMMANDS",
    }.merge { SECTION_NAMES.map { |n| [n, n] }.to_h }

    using Ext::Array::ShiftWhile

    attr_reader :name # Name of program
    attr_reader :source # A (possibly multiline) string
    attr_reader :tokens # List of tokens. Initialized by #lex
    
    def initialize(name, source)
      @name = name
      @source = source.end_with?("\n") ? source : source + "\n" # Always terminate source with a newline
    end

    def lex(lineno = 1, charno = 1)
      # Split source into lines and tag them with lineno and charno. Only the
      # first line can have charno != 1 (this happens in one-line declarations)
      lines = source[0..-2].split("\n").map.with_index { |line,i|
        l = Line.new(i + lineno, charno, line)
        charno = 1
        l
      }

      # Skip initial comments and blank lines and compute indent level. All
      # lines starting with '#' is considered a comment here so a spec can't
      # start with an '#' list
      lines.shift_while { |line| line.text == "" || line.text.start_with?("#") }
      initial_indent = lines.first&.charno

      # Create artificial program token. The token has the program name as value
      @tokens = [Token.new(:program, 0, 0, name)]

      # Reference to last non-blank token. Used to detect code blocks
      last_nonblank = @tokens.first

      # Process lines
      while line = lines.shift
        # Pass-trough blank lines. This makes sure last_nonblank is never set
        # to a blank token
        if line.to_s == ""
          @tokens << Token.new(:blank, line.lineno, line.charno, "")
          next
        end
          
        # Ignore comments. A comment is an line starting with '#' and being
        # less indented than the initial indent of the spec
        if line.charno < initial_indent
          next if line =~ /^#/
          error_token = Token.new(:text, line.lineno, 0, "")
          lexer_error line.lineno, 0, "Illegal indentation"
        end

        # Code lines. Code is preceeded by a blank line and indented beyond the
        # last non-blank token's indentation (just the parent?). It should also
        # not look like declaration of an option or a command - the first line
        # in the block can be escaped with a \ to solve that
        if @tokens.last == :blank && line.charno > last_nonblank.charno && line !~ DECL_RE
          text = line.text[(line.text =~ /^\\/ ? 1 : 0)..-1] # Unescape
          @tokens << Token.new(:text, line.lineno, line.charno, text)
          lines.shift_while { |line| line.blank? || line.charno > last_nonblank.charno }.each { |line|
            kind = (line.blank? ? :blank : :text)
            @tokens << Token.new(kind, line.lineno, line.charno, line.text)
          }

        # Sections
        elsif SECTION_ALIASES.key?(line.text)
          value = SECTION_ALIASES[line.text]
          @tokens << Token.new(:section, line.lineno, line.charno, value, line.text)

        # Options, commands, usage, arguments, and briefs. The line is broken
        # into words to be able to handle one-line declarations - options with
        # briefs and especially of one-line subcommands
        elsif line =~ DECL_RE
          words = line.words
          while (charno, word = words.shift)
            # Ensure mandatory arguments. This doesn't include the '@text' brief type
            if SINGLE_LINE_WORDS.include?(word) && words.empty?
              lexer_error line.lineno, charno, "Empty '#{word}' declaration"
            end

            case word
              when /@(.+)?/ # $1 can be nil. If so, we know that there are some arguments
                value = ([$1] + words.shift_while { true }.map(&:last)).compact.join(" ")
                @tokens << Token.new(:brief, line.lineno, charno, value, "@")
              when "--"
                # Almost eat rest of line
                value = words.shift_while { |_,word| word !~ BRIEF_RE }.map(&:last).join(" ") 
                @tokens << Token.new(:arg_descr, line.lineno, charno, value, "--")
              when "++"
                @tokens << Token.new(:arg_spec, line.lineno, charno, "++")
                words.shift_while { |charno,word| 
                  word =~ ARG_RE and @tokens << Token.new(:arg, line.lineno, charno, word) 
                }
              when /^-|\+/
                @tokens << Token.new(:option, line.lineno, charno, word)
              when /!$/
                @tokens << Token.new(:command, line.lineno, charno, word)
            else
              raise StandardError, "Internal error"
            end
          end

        # Paragraph lines
        else
          @tokens << Token.new(:text, line.lineno, line.charno, line.text)
        end

        # This works because blank tokens never reach this line
        last_nonblank = @tokens.last
      end

      @tokens
    end

    def self.lex(name, source, oneline, lineno = 1, charno = 1)
      Lexer.new(name, source, oneline).lex(lineno, charno)
    end

    def lexer_error(lineno, charno, message) 
      token = Token.new(:text, lineno, charno, "")
      raise LexerError.new(token), message
    end
  end
end

