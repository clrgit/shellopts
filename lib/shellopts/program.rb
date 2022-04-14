
# TODO: Create a BasicShellOptsObject with is_a? and operators defined
#
module ShellOpts
  # Command represents a program or a subcommand. It is derived from
  # BasicObject to have only a minimum of inherited member methods.
  #
  # The names of the inherited methods can't be used as options or
  # command namess. They are: instance_eval, instance_exec method_missing,
  # singleton_method_added, singleton_method_removed, and
  # singleton_method_undefined.
  #
  # Additional methods defined in Command use the  '__<identifier>__' naming
  # convention that doesn't collide with option or subcommand names but
  # they're rarely used in application code
  #
  # Command also defines #subcommand and #subcommand! but they can be
  # overshadowed by an option or command declaration. Their values can
  # still be accessed using the dashed name, though
  #
  # Option and Command objects can be accessed using #[]. #key? is also defined
  #
  # The following methods are created dynamically for each declared option
  # with an attribute name
  #
  #   <identifier>(default = nil)
  #   <identifier>=(value)
  #   <identifier>?()
  #
  # The default value is used if the option or its value is missing
  #
  # Options without an an attribute can still be accessed using #[] or trough
  # #__option_values__, #__option_hash, or #__options_list__
  #
  # Each subcommand has a single method:
  #
  #   # Return the subcommand object or nil if not present
  #   def <identifier>!() subcommand == :<identifier> ? @__subcommand__ : nil end
  #
  # The general #subcommand method can be used to find out which subcommand is
  # used
  #
  class Command < BasicObject
    define_method(:is_a?, ::Kernel.method(:is_a?))

    # These names can't be used as option or command names
    RESERVED_OPTION_NAMES = %w(
        is_a to_h instance_eval instance_exec method_missing singleton_method_added
        singleton_method_removed singleton_method_undefined
    )

    # These methods can be overridden by an option or a command (this constant
    # is not used - it is just for informational purposes)
    OVERRIDEABLE_METHOD_NAMES = %w(
        subcommand subcommand! subcommands subcommands! supercommand!
    )

    # Redefine ::new to call #__initialize__
    def self.new(grammar)
      object = super()
      object.__send__(:__initialize__, grammar)
      object
    end

    # Returns the command or option object identified by the UID if present and
    # otherwise nil. Returns a possibly empty array of option objects if the
    # option is repeatable. Raise an ArgumentError if the key doesn't exists
    #
    # The +key+ is the symbolic UID of the object. Eg. :command.option or
    # :command.subcommand!
    #
    def [](uid)
      __grammar__.key?(uid) or ::Kernel.raise ::ArgumentError, "'#{uid}' is not a valid UID"
      idents = uid.to_s.gsub(/\./, "!.").split(/\./).map(&:to_sym)
      idents.inject(self) { |cmd, ident|
        case ident.to_s
          when /!$/
            return nil if cmd.__subcommand__ != ident
            cmd = cmd.__subcommand__!
          else
            opt = cmd.__option_hash__[ident]
            opt.nil? && cmd.__grammar__[ident].repeatable? ? [] : opt
        end
      }
    end

    # Returns a hash of the given options if defined. Returns all options if no
    # options are given
    def to_h(*keys)
      keys = ::Kernel::Array(keys).flatten
      if keys.empty?
        self.to_h(@__grammar__.options.map(&:ident))
      else
        keys.map { |key|
          self.__send__("#{key}?".to_sym) ? [key, self.__send__(key)] : nil
        }.compact.to_h
      end
    end

    # Subcommand identifier or nil if not present. #subcommand is often used in
    # case statement to branch out to code that handles the given subcommand:
    #
    #   prog, args = ShellOpts.parse("do_this! do_that!", ARGV)
    #   case prog.subcommand
    #     when :do_this!; prog.do_this.operation # or prog[:subcommand!] or prog.subcommand!
    #     when :do_that!; prog.do_that.operation
    #   end
    #
    # Note: Can be overridden by option, in that case use #__subcommand__ or
    # ShellOpts.subcommand(object) instead
    #
    def subcommand() __subcommand__ end

    # The subcommand object or nil if not present. Per-subcommand methods
    # (#<identifier>!) are often used instead of #subcommand! to get the
    # subcommand
    #
    # Note: Can be overridden by a subcommand declaration (but not an
    # option), in that case use #__subcommand__! or
    # ShellOpts.subcommand!(object) instead
    #
    def subcommand!() __subcommand__! end

    # Returns the concatenated identifier of subcommands (eg. :cmd.subcmd!)
    def subcommands() __subcommands__ end

    # Returns the subcommands in an array. This doesn't include the top-level
    # program object
    def subcommands!() __subcommands__! end

    # The parent command or nil. Initialized by #add_command
    #
    # Note: Can be overridden by a subcommand declaration (but not an
    # option), in that case use #__supercommand__! or
    # ShellOpts.supercommand!(object) instead
    #
    def supercommand!() __supercommand__ end

    # UID of command/program (String)
    def __uid__() @__grammar__.uid end

    # Identfier including the exclamation mark (Symbol)
    def __ident__() @__grammar__.ident end

    # Name of command/program without the exclamation mark (String)
    def __name__() @__grammar__.name end

    # Grammar object
    attr_reader :__grammar__

    # Hash from identifier to value. Can be Integer, Float, or String depending
    # on the option's type. Repeated options options without arguments have the
    # number of occurences as value, repeated option with arguments have the
    # array of values as value
    attr_reader :__option_values__

    # List of Option objects for the subcommand in the same order as
    # given by the user but note that options are reordered to come after
    # their associated subcommand if float is true. Repeated options are not
    # collapsed
    attr_reader :__option_list__

    # Map from identifier to option object or to a list of option objects if
    # the option is repeatable
    attr_reader :__option_hash__

    # The parent command or nil. Initialized by #add_command
    attr_accessor :__supercommand__
    
    # The subcommand identifier (a Symbol incl. the exclamation mark) or nil
    # if not present. Use #subcommand!, or the dynamically generated
    # '#<identifier>!' method to get the actual subcommand object
    def __subcommand__() @__subcommand__&.__ident__ end

    # The actual subcommand object or nil if not present
    def __subcommand__!() @__subcommand__ end

    # Implementation of the #subcommands method
    def __subcommands__()
      __subcommands__!.last&.__uid__&.to_sym
    end

    # Implementation of the #subcommands! method
    def __subcommands__!()
      ::Algorithm.follow(self.__subcommand__!, :__subcommand__!).to_a
    end

  private
    def __initialize__(grammar)
      @__grammar__ = grammar
      @__option_values__ = {}
      @__option_list__ = [] 
      @__option_hash__ = {}
      @__option_values__ = {}
      @__subcommand__ = nil

      __define_option_methods__
    end

    def __define_option_methods__
      @__grammar__.options.each { |opt|
        if !opt.repeatable?
          self.instance_eval %(
            def #{opt.attr}?() 
              @__option_values__.key?(:#{opt.attr}) 
            end
          )
        end
        
        if opt.repeatable?
          if opt.argument?
            self.instance_eval %(
              def #{opt.attr}?() 
                (@__option_values__[:#{opt.attr}]&.size || 0) > 0 
              end
            )
            self.instance_eval %(
              def #{opt.attr}(default = [])
                if @__option_values__.key?(:#{opt.attr}) 
                  @__option_values__[:#{opt.attr}]
                else
                  default
                end
              end
            )
          else
            self.instance_eval %(
              def #{opt.attr}?() 
                (@__option_values__[:#{opt.attr}] || 0) > 0 
              end
            )
            self.instance_eval %(
              def #{opt.attr}(default = 0) 
                if default > 0 && (@__option_values__[:#{opt.attr}] || 0) == 0
                  default
                else
                  @__option_values__[:#{opt.attr}] || 0
                end
              end
            )
          end

        elsif opt.argument?
          self.instance_eval %(
            def #{opt.attr}(default = nil)
              if @__option_values__.key?(:#{opt.attr}) 
                @__option_values__[:#{opt.attr}]
              else
                default
              end
            end
          )

        else
          self.instance_eval %(
            def #{opt.attr}() 
              @__option_values__.key?(:#{opt.attr}) 
            end
          )
        end
      }

      @__grammar__.commands.each { |cmd|
        next if cmd.attr.nil?
        self.instance_eval %(
          def #{cmd.attr}() 
            :#{cmd.attr} == __subcommand__ ? __subcommand__! : nil
          end
        )
      }
    end

    def __add_option__(option)
      ident = option.grammar.ident
      @__option_list__ << option
      if option.repeatable?
        (@__option_hash__[ident] ||= []) << option
        if option.argument?
          (@__option_values__[ident] ||= []) << option.argument
        else
          @__option_values__[ident] = (@__option_values__[ident] || 0) + 1
        end
      else
        @__option_hash__[ident] = option
        @__option_values__[ident] = option.argument
      end
    end

    def __add_command__(subcommand)
      subcommand.__supercommand__ = self
      @__subcommand__ = subcommand
    end

    def self.add_option(subcommand, option) subcommand.__send__(:__add_option__, option) end
    def self.add_command(subcommand, cmd) subcommand.__send__(:__add_command__, cmd) end
  end

  # The top-level command
  class Program < Command
  end

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
        :file?, :enum?, :string?, :optional?,
        :argument_name, :argument_type, :argument_enum

    def initialize(grammar, name, argument)
      @grammar, @name, @argument = grammar, name, argument
    end
  end
end
