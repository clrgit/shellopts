
module ShellOpts
  class Interpreter
    attr_reader :expr
    attr_reader :args

    def initialize(grammar, argv, float: true, exception: false)
      constrain grammar, Grammar::Program
      constrain argv, [String]
      @grammar, @argv = grammar, argv.dup
      @float, @exception = float, exception
    end

    def interpret
      @expr = command = Program.new(@grammar)
      @seen = {} # Set of seen options by UID (using UID is needed when float is true)
      @args = []

      while arg = @argv.shift
        if arg == "--"
          break
        elsif arg.start_with?("-")
          interpret_option(command, arg)
        elsif @args.empty? && subcommand_grammar = command.__grammar__[:"#{arg}!"]
          command = Command.add_command(command, Command.new(subcommand_grammar))
        else
          if @float
            @args << arg # This also signals that no more commands are accepted
          else
            @argv.unshift arg
            break
          end
        end
      end
      [@expr, Args.new(@args + @argv, exception: @exception)]
    end

    def self.interpret(grammar, argv, **opts)
      self.new(grammar, argv, **opts).interpret
    end

  protected
    # Lookup option in the command hierarchy and return pair of command and
    # option associated command. Raise if not found
    #
    def find_option(command, name)
      while command && (option = command.__grammar__[name]).nil?
        command = command.__supercommand__
      end
      option or error "Unknown option '#{name}'"
      [command, option]
    end

    def interpret_option(command, option)
      # Split into name and argument
      case option
        when /^(--.+?)(?:=(.*))?$/
          name, value, short = $1, $2, false
        when /^(-.)(.+)?$/
          name, value, short = $1, $2, true
      end

      option_command, option = find_option(command, name)
      !@seen.key?(option.uid) || option.repeatable? or error "Duplicate option '#{name}'"
      @seen[option.uid] = true

      # Process argument
      if option.argument?
        if value.nil? && !option.optional?
          if !@argv.empty?
            value = @argv.shift
          else
            error "Missing argument for option '#{name}'"
          end
        end
        value &&= interpret_option_value(option, name, value)
      elsif value && short
        @argv.unshift("-#{value}")
        value = nil
      elsif !value.nil?
        error "No argument allowed for option '#{opt_name}'"
      end

      Command.add_option(option_command, Option.new(option, name, value))
    end

    def interpret_option_value(option, name, value)
      type = option.argument_type
      if type.match?(name, value)
        type.convert(value)
      elsif value == ""
        nil
      else
        error type.message
      end
    end

    def error(msg)
      raise Error, msg
    end
  end
end

