module ShellOpts
  # Option models an option as given by the user on the subcommand line.
  # Compiled options (and possibly aggregated) options are stored in the
  # Command#__option_values__ array
  class Option
    # Associated Grammar::Option object
    attr_reader :grammar

    # The actual name used on the shell command-line (String)
    attr_reader :name

    # Argument value or nil if not present. The value is a String, Integer,
    # or Float depending the on the type of the option
    attr_accessor :argument

    forward_to :grammar,
        :uid, :ident,
        :repeatable?, :argument?, :integer?, :float?,
        :file?, :enum?, :string?, :optional?, :list?,
        :argument_name, :argument_type, :argument_enum,
        :short_idents, :long_idents

    def initialize(grammar, name, argument)
      @grammar, @name, @argument = grammar, name, argument
    end
  end
end
