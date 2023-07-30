
# Hack
class NilClass 
  def __class__ = self.class
end

module ShellOpts
  class Interpreter
    attr_reader :expr
    attr_reader :args

    attr_reader :float
    attr_reader :exception

    def initialize(grammar, argv, float: true, exception: false)
      constrain grammar, Grammar::Grammar
      constrain argv, [String]
      @grammar, @argv = grammar, argv.dup
      @float, @exception = float, exception
    end

    def interpret
      @expr = command = Program.new(@grammar.program)
      @seen = {} # Set of seen options by UID (using UID is needed when float is true)
      @args = []
      while arg = @argv.shift
        if arg == "--"
          break
        elsif arg =~ /^-|\+/
          interpret_option(command, arg)
          # TODO: if option.__grammar__.suspend_error? ...
        elsif @args.empty? && command.__grammar__.subcommand?(:"#{arg}!")
          command = interpret_command(command, arg)
        elsif @float
          @args << arg # This also signals that no more commands are accepted
        else
          @argv.unshift arg
          break
        end
      end

      [@expr, Args.new(@args + @argv, exception: @exception)]
    end

    def self.interpret(grammar, argv, **opts)
      self.new(grammar, argv, **opts).interpret
    end

  protected
    # Remaining arguments. Is consumed by #interpret
    attr_reader :argv

    # FIXME: Command access is ugly (but may be efficient because there's ever
    # only a few subcommands)
    def find_command(command, ident)
      command.__grammar__.group.subcommands.find { |subcommand| subcommand.ident == ident }
    end

    # Lookup option in the command hierarchy and return pair of command and
    # the option. Raise if not found
    #
    def find_option(command, ident)
      while command && (option = command.__grammar__.dot(ident)).nil? && float
        command = command.__supercommand__
      end
      option or interpreter_error "Unknown option '#{ident}'" # FIXME: Bad interpreter_error message
      [command, option]
    end

    def interpret_command(command, cmd)
      constrain command, Command
      constrain cmd, String
      subcommand_grammar = find_command(command, :"#{cmd}!")
      Command.add_command(command, Command.new(subcommand_grammar))
    end

    def interpret_option(command, option)
      constrain command, Command
      constrain option, String

      # Split into name and argument
      case option
        when /^(--(.+?))(?:=(.*))?$/
          name, ident, value, short = $1, $2.to_sym, $3, false
        when /^(-(.))(.+)?$/
          name, ident, value, short = $1, $2.to_sym, $3, true
      end
      option_command, option = find_option(command, ident)

      # Check for duplicates before registering option
      !@seen.key?(option.path) || option.repeatable? or interpreter_error "Duplicate option '#{name}'"
      @seen[option.path] = true

      # Process argument
      if option.argument?
        if value.nil? && !option.optional?
          if !@argv.empty?
            value = @argv.shift
          else  
            interpreter_error "Missing argument for option '#{name}'"
          end
        end
        value &&= interpret_option_value(option, ident, value)
      elsif value && short
        @argv.unshift("-#{value}")
        value = nil
      elsif !value.nil?
        interpreter_error "No argument allowed for option '#{opt_name}'"
      end
      
      # Create option and add it to the command
      Command.add_option(option_command, Option.new(option, ident, value))
    end

    def interpret_option_value(option, ident, value)
      type = option.argument_type
      if type.match?(ident, value)
        type.convert(value)
      elsif value == ""
        nil
      else
        interpreter_error type.message
      end
    end

    def interpreter_error(msg)
      raise Error, msg
    end
  end
end

