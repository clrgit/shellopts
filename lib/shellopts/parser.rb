
# IDEA:
#   Transform single-line to multiline:
#
#       -a -b cmd! -c cmd.sub! -d
#
#       -a
#
#       -b
#
#       cmd!
#         -c
#
#         cmd.sub!
#           -d
#           
#
#
#







module ShellOpts
  def program_name
    @program_name ||= File.basename($PROGRAM_NAME)
  end
end

module ShellOpts
  # The parser extends Grammar objects with a parse method that is called with
  # the parent object and the current token as argument

  class Parser
    using Ext::Array::ShiftWhile
    using Ext::Array::PopWhile

    # The resulting Spec::Program object
    attr_reader :program

    def initialize(tokens)
      constrain tokens, [Token]
      @tokens = tokens.dup
      @stack = []
    end

    # Parse tokens and return top-level Spec::Program object
    def parse
      push(@program = Spec::Program.new(tokens.shift))
      parse_description
      program
    end
  protected
    # Queue of token
    attr_reader :tokens

    # Token operations
    def shift = @tokens.shift
    def unshift(token) = @tokens.unshift
    def first = @tokens.first
    def kind = first&.kind 
    def charno = first&.charno 

    # Stack of Spec nodes. The stack is unwinded before each token is processed
    attr_reader :stack

    # Stack operations
    def top = @stack.last
    def push(spec) = @stack << spec
    def pop = @stack.pop

    def parse_error(token, message) = raise ParserError, token, message

    # Parse a one-line arg spec
    def parse_arg_spec
      constrain @tokens.first.kind, :arg_spec
      command = Spec::Command.new(top, shift)
      while first&.lineno == top.lineno
        case kind
          when :arg
            Spec::Arg.new(command, token)
          else
            parser_error token, "Illegal indent"
        end
      end
    end

    def parse_singleline_options(command, token)
      unshift token
      while kind == :option
        token = shift
        group = Spec::OptionGroup.new(command, token)
        Spec::Option.new(group, token)
      end
    end

    def parse_multiline_options(token)
      push Spec::OptionGroup.new(top, token)
      parse_multiline_options_header(token)
      parse_description if first&.kind
    end

    def parse_multiline_options_header(token)
      charno = token.charno
      unshift token
      while kind == :option && first&.charno == charno
        option = Spec::Option.new(top, shift)
        while kind == :brief && first.same?
          Spec::Brief.new(option, shift)
        end
      end
    end

    def parse_multiline_options_header(token)
      charno = token.charno
      consume(:option, token.charno) { 
        option = Spec::Option.new(top, shift)
        consume(:brief) { Spec::Brief.new(option, shift) } # Implicitly same line
      }
    end

    def parse_singleline_commands(command, token)
    end

    def parse_multiline_commands_header(token)
      charno = token.charno
      consume(:command, token.charno) {
        command = Spec::Command.new(top, shift)
        parse_singleline_options
        parse_singleline_arg_spec
        parse_singleline_arg_descr
        consume(:brief) { Spec::Brief.new(option, shift) } # Implicitly same line
      }


    def parse_option_group(token)
      push Spec::OptionGroup.new(top, token)
      parse_option_group_header(token)
      parse_description if first&.kind
    end

    def parse_option_group_header(token)
      parse_option(token)
      while kind == :option
        parse_option(@tokens.shift)
      end
    end

    def parse_option_groups(token)
      unshift token
      while kind == :option
        push Spec::OptionGroup.new(top, token)
        parse_option shift
        pop
      end
    end

    def parse_option(token, subject: nil)
      option = Spec::Option.new(top, token)
      while kind == :brief
        Brief.new(subject || option, shift)
      end
    end

    def parse_command(token)
      command = Spec::Command.new(token)
      while kind == :option

    end

    def parse_description
      while token = @tokens.shift
        puts
        puts "Processing token #{token.inspect}"
        dump_stack

        case token.kind
          when :blank
            pop if top.is_a? Spec::Option
            pop if top.is_a? Spec::OptionGroup
            pop if top.is_a? Spec::Command
            pop if top.is_a? Spec::CommandGroup
            ; # Do nothing

          when :brief
            # In single line processing mode the subject of the brief is the
            # first non-group node on the same line
#           if top.send(:mode) == :single
#             popped = @stack.pop_while { |n| n.send(:mode) == :single }
#             @stack.push popped[0..1]

            if token.same?
              first_node = @stack.reverse.find { |node| !node.token.same? }
              Spec::Brief.new(first_node, token)
            else
              pop if top.is_a? Spec::Option
              pop if top.is_a? Spec::Command
              Spec::Brief.new(top, token)
            end

          when :text
            unwind(token)

            # Create Description object if needed
            push Spec::Description.new(top, token) if !top.is_a?(Spec::Description)

            # Collect subsequent lines with the same indentation into a single
            # Paragraph
            push Spec::Paragraph.new(top, token, [token.value] + consume(token.charno, :text, &:value))

          # Keep track of option parent (command)
          # Keep track of command parent (command)

          when :option
            
            pop if top.is_a? Spec::Option
            pop if token.same? && top.is_a?(Spec::OptionGroup)
            push Spec::OptionGroup.new(top, token) if !top.is_a? Spec::OptionGroup
            push Spec::Option.new(top, token)

#           pop if top.is_a? Spec::Option
#           dump_stack
#           push Spec::OptionGroup.new(top, token) if !top.is_a? Spec::OptionGroup
#           dump_stack
#           dump_stack
#           case top
#             when Option
#               pop
#             when OptionGroup
#               push Spec::Option.new(top, token)
#           else
#             push OptionGroup.new(top, token)
#             @tokens.unshift token
#           end

#           ensure_group(Spec::OptionGroup)
#           unwind_group(Spec::OptionGroup)
#           push Spec::OptionGroup.new(top, token) if !top.is_a? Spec::OptionGroup
#           push Spec::Option.new(top, token)

          when :command
            pop if top.is_a? Spec::Command
            pop if token.same? && top.is_a?(Spec::CommandGroup)
            push Spec::CommandGroup.new(top, token) if !top.is_a? Spec::CommandGroup
            push Spec::Command.new(top, token)
        else
          ;
#         puts "   Default"
        end

      end

      dump_stack
    end

    def dump_stack
        puts "                 #{@stack.map { |node| node.class.name }.inspect}"
    end

    # TODO Add subject

    # Unwind stack based on lineno or charno based on processing mode. The
    # processing mode is read from the top token. If it is :multi then the
    # stack is unwinded until the the token is more indented than the top node,
    # if it is :single, all nodes in :single mode are popped first before
    # processing the rest in multiline mode
    #
    # Option and Command object are processed in :single mode so the net effect
    # is that when there is an option or a command somewhere in the stack and
    # the token is on a new line, then the stack is unwinded down to and
    # including the option or command. This behaviour is needed for processing
    # groups
    def unwind(token)
#     if top.send(:mode) == :single
#       if token.lineno != top.token.lineno
#         stack.pop_while { |node| node.send(:mode) == :single }
#       else
#         stack.pop_while { |node| !node.is_a?(Spec::Group) } # Why
#       end
#       stack.pop_while { |curr| token.charno < curr.token.charno } # '<' to not pop the group
#     else
        stack.pop_while { |curr| token.charno < curr.token.charno }
        stack.pop if token.charno == top.token.charno
#     end
    end

    def unwind_parts(klass) = stack.pop_while { |node| node.part? && node.class == klass }

    def unwind_group(klass) 
      puts "           stack #{@stack.map { |node| node.class.name }.inspect}"
      stack.pop_while { |node| !node.is_a? klass }
      puts "           stack #{@stack.map { |node| node.class.name }.inspect}"
    end
    def consume(charno, kind, &block)
      if block_given?
        @tokens.shift_while { |t| t.charno == charno && t.kind == kind }.map { |t| yield t }
      else
        @tokens.shift_while { |t| t.charno == charno && t.kind == kind }
      end
    end
  end
end

__END__

  

    def make_program(token)
      spec = Spec::Description.new(nil, token)
      grammar = Grammar::Program.new
      doc = Doc::Program.new(grammar, spec)
      [grammar, spec]
    end

    def parse_arg(spec, token)
      Grammar::Arg.new(spec, nil, token)
    end

    def parse_option(token, option_group)
      long, short = [], []
      ident = nil
      case token.value
        when /--(.*)/; ident = $1.to_sym; long << ident
        when /-(.*)/; ident = $1.to_sym; short << ident
      else
        raise ArgumentError, "'#{token}' is not an option"
      end
      opt = Grammar::Option.new(node, ident, short, long)
      doc = Doc::Option.new(opt, option_group.description)
      opt
    end

    def parse
      program, description = make_program(tokens.shift)
      @nodes = [program]
      @specs = [description]

      while token = @tokens.shift
        unwind(token)
        puts
        puts "Processing #{token.kind}: #{token.value.inspect}"
        puts "   node stack: #{@nodes.map(&:class).join(", ")}"
        puts "   spec stack: #{@nodes.map(&:class).join(", ")}"

        case token.kind
          when :blank
            ; # Do nothing

          when :brief
            node.is_a?(Grammar::Command) || node.is_a?(Grammar::Option) or 
                raise parse_error, token, "Unexpected brief definition"
            node.doc.brief.nil? or raise ParserError, "Duplicate brief in definition of #{node.name}"
            node.doc.brief = Spec::Brief.new(token)

          when :arg_spec
            node.is_a?(Grammar::Command) or raise parse_error, token, "Unexpected argument specification"
            spec = Grammar::ArgSpec.new(node, token)
            @tokens.shift_while { |t| t.kind == :arg and parse_arg(spec, t) }

          when :arg
            raise InternalError, ":arg tokens should be processed by :spec"

          when :arg_descr
            node.is_a?(Grammar::Command) or raise parse_error, token, "Unexected argument description"
            node.doc.arg_descr = Spec::Lines.new curr_spec, token, consume(:arg_descr, &:value)

          when :text
            lines = [token.value] + consume(:text).map(&:value)
            Spec::Lines.new(curr_spec, token, lines)

          when :option
            node.is_a?(Grammar::Command) or raise parse_error, token, "Unexpected option definition"
            if !(option_group = curr_spec.is_a?(Spec::OptionGroup))
              @specs.push Spec::OptionGroup.new(curr_spec, token)
              option_group = curr_spec
              Spec::Description.new(curr_spec, token) # FIXME WRONG TOKEN
            end
            @nodes << parse_option(token, option_group)

          when :command
            @nodes << Grammar::Command.new(node, token.value, [token.value])

        else
          puts "Unhandled token: #{token.kind}"
        end
      end

      pp @nodes
      pp @specs
      exit
    end

  protected
    # Not public because it is always empty after parsing
    attr_reader :tokens
    def token = @tokens.first
    def shift = @tokens.shift

    def consume(kind, recursive: false, &block)
      if block_given?
        @tokens.shift_while { |t| t.kind == kind }.map { |t| yield t }
      else
        @tokens.shift_while { |t| t.kind == kind }
      end
    end

#   # Remove one token and return it. If a block is given, the block is
#   # executed on the token and its result is returned instead. It is an
#   # error if the token doesn't has the given kind
#   def consume_one(kind, &block)
#     token.kind == kind or raise ParserError, "Expected #{kind}"
#     block_given? ? yield(@tokens.shift) : @tokens.shift
#   end
#
#   # Like #consume_one but removes all tokens (if any) that have the given
#   # kind. Returns a list of tokens or result of the block if a block was given
#   def consume_all(kind, &block)
#     consume(:kind, kind, &block)
#   end
#
#   def consume_some(kind, &block)
#     token.kind == kind or raise ParserError, "Expected #{kind}"
#     consume_one(kind, &block)
#     consume_all(kind, &block)
#   end

      # Unwind stacks according to indentation
    def unwind(token)
      puts "#unwind(#{token.inspect})"
      puts "  nodes: #{nodes.size}"
      puts "  specs: #{specs.size}"

      nodes.pop_while { |c| token.charno <= c.token.charno }
      specs.pop_while { |d| token.charno <= d.token.charno }
    end

  end
end

__END__

      while token = @tokens.shift
        unwind_nodes

        case token.kind

          when :option
            parse_option

          when :command
            if token.source =~ /^(?:(.*)\.)([^.]+)$/
              parent_idents = $1.split(".")
              ident = $2.to_sym

              # Create intermediate commands
              cmd = cmds.top
              for intermediate_ident in parent_idents
                if !cmd.key?(intermediate_ident)
                  cmd = Grammar::Command.new( # FIXME: Require a token

                else
                  cmd = cmd[intermediate_ident]
                end

              end



              command = Grammar::Command.new(cmds.top, 
              parent_uid = $1
              ident = $2.to_sym




            

            # Collect following commands with the same indent


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

          when :section
            section = ArgSpec::Section.new(docs.top, token)
            docs.push section
            nodes.push section

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
  end
end

__END__



    def parse()
      # Check one-line mode
      if @tokens.first.lineno == @tokens.last.lineno
        @tokens.each { |t| 
          Token::ONE_LINE_KINDS.include? t.kind or 
              raise ParserError, "Can't use #{t.kind.to_s.upcase} token in one-line specifications"
        }

        parse_program
      end

    protected
      # List of Token objects. Consumed by #parse
      attr_reader :tokens

      # Current token
      def token = tokens.last

        # Unwind stacks according to indentation
      def unwind_nodes
        nodes.pop_while { |n| token.charno <= n.token.charno }
        cmds.pop_while { |c| token.charno <= c.token.charno }
        docs.pop_while { |d| node.doc != d }
        descrs.pop_while { |d| token.charno <= d.token.charno }
      end

      def push_node(node)
        @nodes << node if node.is_a?(Grammar::Node)
        @cmds << node if node.is_a?(Grammar::Command)
        @docs << node if node.is_a?(Grammar::Node) && node.doc
        @descrs << node if node.is_a?(ArgSpec::Node)
        @descrs << node.description if node.is_a?(Doc::Node)
      end

      def pop_node(node)
        @nodes.pop if self.node == node
        @cmds.pop if cmd == node
        @docs.pop if doc == node.doc
        @descrs.pop if descr == node
        @descrs.pop if descr == node.description
      end

      def parse_program
        @program = Grammar::Program.parse(@tokens.shift) # Eat the first artificial token
        @nodes = [@program]
        @cmds = [@program]
        @docs = [@program.doc]
        @descrs = [@program.doc.description]

        parse_command
      end

      def parse_option
              # TODO TODO TODO Move to #parse_option
              option = parse_option
              option_doc = option.doc
              push_node option

              # Collect following options with the same indent
              next_token = @tokens.first
              while next_token.charno == token.charno && next_token.kind == :option
                token = @tokens.shift
                next_token = @token.first
                option = Option.parse(cmds.top, token)
                group << option
              end

              nodes.push option


        token = @tokens.first

        token.source =~ /^(-|--|\+|\+\+)(#{NAME_RE})(?:=(.+?)(\?)?)?$/ or 
            parser_error token, "Illegal option: #{token.source.inspect}"
        initial = $1
        name_list = $2
        arg = $3
        optional = $4

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
              @argument_type = IntegerType.new
            when "$"
              @argument_name ||= "NUM"
              @argument_type = FloatType.new
            when "FILE", "DIR", "PATH", "EFILE", "EDIR", "EPATH", "NFILE", "NDIR", "NPATH", "IFILE", "OFILE"
              @argument_name ||= arg.sub(/^(?:E|N|I|O)/, "")
              @argument_type = FileType.new(arg.downcase.to_sym)
            when /,/
              @argument_name ||= arg
              @argument_type = EnumType.new(arg.split(","))
            else
              named && @argument_name.nil? or parser_error token, "Illegal type expression: #{arg.inspect}"
              @argument_name = arg
              @argument_type = StringType.new
          end
          @optional = !optional.nil?
        else
          @argument_type = StringType.new
        end
      end

      def parse_command
        while token = @tokens.shift
          unwind_nodes

          case token.kind

            when :option
              parse_option

            when :command
              if token.source =~ /^(?:(.*)\.)([^.]+)$/
                parent_idents = $1.split(".")
                ident = $2.to_sym

                # Create intermediate commands
                cmd = cmds.top
                for intermediate_ident in parent_idents
                  if !cmd.key?(intermediate_ident)
                    cmd = Grammar::Command.new( # FIXME: Require a token

                  else
                    cmd = cmd[intermediate_ident]
                  end

                end



                command = Grammar::Command.new(cmds.top, 
                parent_uid = $1
                ident = $2.to_sym




              

              # Collect following commands with the same indent


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

            when :section
              section = ArgSpec::Section.new(docs.top, token)
              docs.push section
              nodes.push section

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

__END__


  module Grammar
    class Node
      def parse() end

      # Create an instance of class and forward to #parse
      def self.parse(parent, token)
        this = self.new(parent, token)
        this.parse
        this
      end

      def parser_error(token, message) raise ParserError, "#{token.pos} #{message}" end
    end

#   class GrammarNode
      # Assumes that @name and @path has been defined
#     def parse
#       @ident = @path.last || :!
#       @attr = ::ShellOpts::Command::RESERVED_OPTION_NAMES.include?(ident.to_s) ? nil : ident
#       @uid = parent && @path.join(".").sub(/!\./, ".") # uid is nil for the Program object
#     end
#   end

    class Option
      SHORT_NAME_RE = /[a-zA-Z0-9?]/
      LONG_NAME_RE = /[a-zA-Z0-9][a-zA-Z0-9_-]*/
      NAME_RE = /(?:#{SHORT_NAME_RE}|#{LONG_NAME_RE})(?:,#{LONG_NAME_RE})*/

      def parse
        token.source =~ /^(-|--|\+|\+\+)(#{NAME_RE})(?:=(.+?)(\?)?)?$/ or 
            parser_error token, "Illegal option: #{token.source.inspect}"
        initial = $1
        name_list = $2
        arg = $3
        optional = $4

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
              @argument_type = IntegerType.new
            when "$"
              @argument_name ||= "NUM"
              @argument_type = FloatType.new
            when "FILE", "DIR", "PATH", "EFILE", "EDIR", "EPATH", "NFILE", "NDIR", "NPATH", "IFILE", "OFILE"
              @argument_name ||= arg.sub(/^(?:E|N|I|O)/, "")
              @argument_type = FileType.new(arg.downcase.to_sym)
            when /,/
              @argument_name ||= arg
              @argument_type = EnumType.new(arg.split(","))
            else
              named && @argument_name.nil? or parser_error token, "Illegal type expression: #{arg.inspect}"
              @argument_name = arg
              @argument_type = StringType.new
          end
          @optional = !optional.nil?
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
        if parent # Not Program
          path_names = token.source.sub("!", "").split(".")
          set_name(
              path_names.last,
              path_names.map { |cmd| "#{cmd}!".to_sym })
        else # Program
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

  module ArgSpec
  end


