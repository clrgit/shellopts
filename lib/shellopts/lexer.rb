
module ShellOpts
  class Line
    attr_reader :source
    attr_reader :lineno
    attr_reader :charno
    attr_reader :text

    def initialize(lineno, charno, source)
      @lineno, @source = lineno, source
      @charno = charno + ((@source =~ /(\S.*?)\s*$/) || 0)
      @text = $1 || ""
    end

    def blank?() @text == "" end

    forward_to :@text, :=~, :!~

    # Split on whitespace while keeping track of character position. Returns
    # array of char, word tuples
    def words
      return @words if @words
      @words = []
      charno = self.charno
      text.scan(/(\s*)(\S*)/)[0..-2].each { |spaces, word|
        charno += spaces.size
        @words << [charno, word] if word != ""
        charno += word.size
      }
      @words
    end

    def to_s() text end
    def dump() puts "#{lineno}:#{charno} #{text.inspect}" end
  end

  class Lexer
    COMMAND_RE = /[a-z][a-z._-]*!/

    DECL_RE = /^(?:-|--|\+|\+\+|(?:@(?:\s|$))|(?:[^\\!]\S*!(?:\s|$)))/

    # Match ArgSpec argument words. TODO
    SPEC_RE = /^[^a-z]{2,}$/

    # Match ArgDescr words (should be at least two characters long)
    DESCR_RE = /^[^a-z]{2,}$/

    SECTIONS = %w(DESCRIPTION OPTION OPTIONS COMMAND COMMANDS)

    using Ext::Array::ShiftWhile

    attr_reader :name # Name of program
    attr_reader :source
    attr_reader :tokens

    def oneline?() @oneline end

    def initialize(name, source, oneline)
      @name = name
      @source = source
      @oneline = oneline
      @source += "\n" if @source[-1] != "\n" # Always terminate source with a newline
    end

    def lex(lineno = 1, charno = 1)
      # Split source into lines and tag them with lineno and charno. Only the
      # first line can have charno != 1
      lines = source[0..-2].split("\n").map.with_index { |line,i|
        l = Line.new(i + lineno, charno, line)
        charno = 1
        l
      }

      # Skip initial comments and blank lines and compute indent level
      lines.shift_while { |line| line.text == "" || line.text.start_with?("#") && line.charno == 1 }
      initial_indent = lines.first&.charno

      # Create program token. The source is the program name
      @tokens = [Token.new(:program, 0, 0, name)]

      # Used to detect code blocks
      last_nonblank = @tokens.first

      # Process lines
      while line = lines.shift
        # Pass-trough blank lines
        if line.to_s == ""
          @tokens << Token.new(:blank, line.lineno, line.charno, "")
          next
        end

        # Ignore meta comments
        if line.charno < initial_indent
          next if line =~ /^#/
          error_token = Token.new(:text, line.lineno, 0, "")
          lexer_error error_token, "Illegal indentation"
        end

        # Line without escape sequences
        source = line.text[(line.text =~ /^\\/ ? 1 : 0)..-1]

        # Code lines
        if last_nonblank.kind == :text && line.charno > last_nonblank.charno && line !~ DECL_RE
          @tokens << Token.new(:text, line.lineno, line.charno, source)
          lines.shift_while { |line| line.blank? || line.charno > last_nonblank.charno }.each { |line|
            kind = (line.blank? ? :blank : :text)
            @tokens << Token.new(kind, line.lineno, line.charno, line.text)
          }

        # Sections
        elsif SECTIONS.include?(line.text)
          @tokens << Token.new(:section, line.lineno, line.charno, line.text.sub(/S$/, ""))

        # Options, commands, usage, arguments, and briefs
        elsif line =~ DECL_RE
          words = line.words
          while (charno, word = words.shift)
            case word
              when "@"
                if words.empty?
                  error_token = Token.new(:text, line.lineno, charno, "@")
                  lexer_error error_token, "Empty '@' declaration"
                end
                source = words.shift_while { true }.map(&:last).join(" ")
                @tokens << Token.new(:brief, line.lineno, charno, source)
              when "--" # FIXME Rename argdescr
                @tokens << Token.new(:usage, line.lineno, charno, "--")
                source = words.shift_while { |_,w| w =~ DESCR_RE }.map(&:last).join(" ")
                @tokens << Token.new(:usage_string, line.lineno, charno, source)
              when "++" # FIXME Rename argspec
                @tokens << Token.new(:spec, line.lineno, charno, "++")
                words.shift_while { |c,w|
                  w =~ SPEC_RE and @tokens << Token.new(:argument, line.lineno, c, w)
                }
              when /^-|\+/
                @tokens << Token.new(:option, line.lineno, charno, word)
              when /!$/
                @tokens << Token.new(:command, line.lineno, charno, word)
            else
              source = [word, words.shift_while { |_,w| w !~ DECL_RE }.map(&:last)].flatten.join(" ")
              @tokens << Token.new(:brief, line.lineno, charno, source)
            end
          end

          # TODO: Move to parser and remove @oneline from Lexer
          (token = @tokens.last).kind != :brief || !oneline? or
              lexer_error token, "Briefs are only allowed in multi-line specifications"

        # Paragraph lines
        else
          @tokens << Token.new(:text, line.lineno, line.charno, source)
        end
        # FIXME Not sure about this
#       last_nonblank = @tokens.last
        last_nonblank = @tokens.last if ![:blank, :usage_string, :argument].include? @tokens.last.kind
      end

      # Move arguments and briefs before first command if one-line source
#     if oneline? && cmd_index = @tokens.index { |token| token.kind == :command }
#       @tokens =
#           @tokens[0...cmd_index] +
#           @tokens[cmd_index..-1].partition { |token| ![:command, :option].include?(token.kind) }.flatten
#     end

      @tokens
    end

    def self.lex(name, source, oneline, lineno = 1, charno = 1)
      Lexer.new(name, source, oneline).lex(lineno, charno)
    end

    def lexer_error(token, message) raise LexerError.new(token), message end
  end
end

