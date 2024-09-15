
module ShellOpts
  # Extend Grammar classes with parse methods
  module Grammar
    class Node
      def parse() end

      def self.parse(parent, token)
        this = self.new(parent, token)
        this.parse
        this
      end

      def parser_error(token, message) raise ParserError, "#{token.pos} #{message}" end
    end

    class IdrNode
      # Assumes that @name and @path has been defined
      def parse
#       @ident = @path.last || :!
#       @attr = ::ShellOpts::Command::RESERVED_OPTION_NAMES.include?(ident.to_s) ? nil : ident
#       @uid = parent && @path.join(".").sub(/!\./, ".") # uid is nil for the Program object
      end
    end

    class Option
      SHORT_NAME_RE = /[a-zA-Z0-9?]/
      LONG_NAME_RE = /[a-zA-Z0-9][a-zA-Z0-9_-]*/
      NAME_RE = /(?:#{SHORT_NAME_RE}|#{LONG_NAME_RE})(?:,#{LONG_NAME_RE})*/

      def parse
        token.source =~ /^(-|--|\+|\+\+)(#{NAME_RE})(?:=(.+?)(,\??|\?,?)?)?$/ or
            parser_error token, "Illegal option: #{token.source.inspect}"
        initial = $1
        name_list = $2
        arg = $3
        @optional = $4&.include?(??) || false
        @list = $4&.include?(?,) || false
        @repeatable = %w(+ ++).include?(initial)

        @short_idents = []
        @short_names = []
        names = name_list.split(",")
        if %w(+ -).include?(initial)
          while names.first&.size == 1
            name = names.shift
            @short_names << "-#{name}"
            @short_idents << name.to_sym
          end
        end

        names.each { |name|
          name.size > 1 or
              parser_error token, "Long names should be at least two characters long: '#{name}'"
        }

        @long_names = names.map { |name| "--#{name}" }
        @long_idents = names.map { |name| name.tr("-", "_").to_sym }

        set_name(
          @long_names.first || @short_names.first,
          command.path + [@long_idents.first || @short_idents.first])

        @argument = !arg.nil?

        named = true
        if @argument
          if arg =~ /^([^:]+)(?::(.*))/
            @argument_name = $1
            named = true
            arg = $2
          elsif arg =~ /^:(.*)/
            arg = $1
            named = false
          end

          case arg
            when "", nil
              @argument_name ||= "VAL"
              @argument_type = StringType.new
            when "#"
              @argument_name ||= "INT"
              @argument_type = IntegerArgument.new
            when "$"
              @argument_name ||= "NUM"
              @argument_type = FloatArgument.new
            when "FILE", "DIR", "PATH", "EFILE", "EDIR", "EPATH", "NFILE", "NDIR", "NPATH", "IFILE", "OFILE"
              @argument_name ||= arg.sub(/^(?:E|N|I|O)/, "")
              @argument_type = FileArgument.new(arg.downcase.to_sym)
            when /,/
              @argument_name ||= arg
              @argument_type = EnumArgument.new(arg.split(","))
            else
              named && @argument_name.nil? or parser_error token, "Illegal type expression: #{arg.inspect}"
              @argument_name = arg
              @argument_type = StringType.new
          end
        else
          @argument_type = StringType.new
        end
        super
      end

    private
      def basename2ident(s) s.tr("-", "_").to_sym end
    end

    class Command
      def parse
        if parent
          path_names = token.source.sub("!", "").split(".")
          set_name(
              path_names.last,
              path_names.map { |cmd| "#{cmd}!".to_sym })
        else
          set_name(token.source, [])
        end
        super
      end
    end

    class Program
      def self.parse(token)
        super(nil, token)
      end

      def inject_option(decl, brief, paragraph = nil, &block)
        option_token = Token.new(:option, 1, 1, decl)
        brief_token = Token.new(:brief, 1, 1, brief)
        group = OptionGroup.new(self, option_token)
        option = Option.parse(group, option_token)
        brief = Brief.parse(group, brief_token)
        paragraph ||= yield(option) if block_given?
        if paragraph
          paragraph_token = Token.new(:text, 1, 1, paragraph)
          paragraph = Paragraph.parse(group, paragraph_token)
        end
        option
      end
    end

    class ArgSpec
      def parse # TODO
        super
      end
    end
  end

  class Parser
    using Stack
    using Ext::Array::ShiftWhile

    # AST root node
    attr_reader :program

    # Commands by UID
    attr_reader :commands

    def initialize(tokens)
      @tokens = tokens.dup # Array of token. Consumed by #parse
      @nodes = {}
    end

    def parse()
      @program = Grammar::Program.parse(@tokens.shift)
      oneline = @tokens.first.lineno == @tokens.last.lineno
      nodes = [@program] # Stack of Nodes. Follows the indentation of the source
      cmds = [@program] # Stack of cmds. Used to keep track of the current command

      while token = @tokens.shift
        # Unwind stack according to indentation
        while token.charno <= nodes.top.token.charno
          node = nodes.pop
          cmds.pop if cmds.top == node
          !nodes.empty? or parse_error(token, "Illegal indent")
        end

        case token.kind
          when :section
            Grammar::Section.parse(nodes.top, token)

          when :option
            # Collect options into option groups if on the same line and not in
            # oneline mode
            options = [token] + @tokens.shift_while { |follow|
              !oneline && follow.kind == :option && follow.lineno == token.lineno
            }
            group = Grammar::OptionGroup.new(cmds.top, token)
            options.each { |option| Grammar::Option.parse(group, option) }
            nodes.push group

          when :command
            parent = nil # Required by #indent
            token.source =~ /^(?:(.*)\.)?([^.]+)$/
            parent_id = $1
            ident = $2.to_sym
            parent_uid = parent_id && parent_id.sub(".", "!.") + "!"

            # Handle dotted command
            if parent_uid
              # Clear stack except for the top-level Program object and then
              # push command objects in the path
              #
              # FIXME: Move to analyzer
#             cmds = cmds[0..0]
#             for ident in parent_uid.split(".").map(&:to_sym)
#               cmds.push cmds.top.commands.find { |c| c.ident == ident } or
#                   parse_error token, "Unknown command: #{ident.sub(/!/, "")}"
#             end
#             parent = cmds.top
              parent = cmds.top
              if !cmds.top.is_a?(Grammar::Program) && token.lineno == cmds.top.token.lineno
                parent = cmds.pop.parent
              end

            # Regular command
            else
              # Don't nest cmds if they are declared on the same line (as it
              # often happens with one-line declarations). Program is special
              # cased as its virtual token is on line 0
              parent = cmds.top
              if !cmds.top.is_a?(Grammar::Program) && token.lineno == cmds.top.token.lineno
                parent = cmds.pop.parent
              end
            end

            command = Grammar::Command.parse(parent, token)
            nodes.push command
            cmds.push command

          when :spec
            spec = Grammar::ArgSpec.parse(cmds.top, token)
            @tokens.shift_while { |token| token.kind == :argument }.each { |token|
              Grammar::Arg.parse(spec, token)
            }

          when :argument
            ; raise # Should never happen

          when :usage
            ; # Do nothing

          when :usage_string
            Grammar::ArgDescr.parse(cmds.top, token)

          when :text
            # Text is only allowed on new lines
            token.lineno > nodes.top.token.lineno

            # Detect indented comment groups (code)
            if nodes.top.is_a?(Grammar::Paragraph)
              code = Grammar::Code.parse(nodes.top.parent, token) # Using parent of paragraph
              @tokens.shift_while { |t|
                if t.kind == :text && t.charno >= token.charno
                  code.tokens << t
                elsif t.kind == :blank && @tokens.first&.kind != :blank # Emit last blank line
                  if @tokens.first&.charno >= token.charno # But only if it is not the last blank line
                    code.tokens << t
                  end
                else
                  break
                end
              }

            # Detect comment groups (paragraphs)
            else
              if nodes.top.is_a?(Grammar::Command) || nodes.top.is_a?(Grammar::OptionGroup)
                Grammar::Brief.new(nodes.top, token, token.source.sub(/\..*/, "")) if !nodes.top.brief
                parent = nodes.top
              else
                parent = nodes.top.parent
              end

              paragraph = Grammar::Paragraph.parse(parent, token)
              while @tokens.first&.kind == :text && @tokens.first.charno == token.charno
                paragraph.tokens << @tokens.shift
              end
              nodes.push paragraph # Leave paragraph on stack so we can detect code blocks
            end

          when :brief
            parent = nodes.top.is_a?(Grammar::Paragraph) ? nodes.top.parent : nodes.top
            parent.brief.nil? or parse_error token, "Duplicate brief"
            Grammar::Brief.parse(parent, token)

          when :blank
            ; # do nothing

        else
          raise InternalError, "Unexpected token kind: #{token.kind.inspect}"
        end

        # Skip blank lines
        @tokens.shift_while { |token| token.kind == :blank }
      end

      @program
    end

    def self.parse(tokens)
      self.new(tokens).parse
    end

  protected
    def parse_error(token, message) raise ParserError, token, message end
  end
end

