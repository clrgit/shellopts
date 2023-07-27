
# TODO: Create a BasicShellOptsObject with is_a? and operators defined
#
module ShellOpts
  # The Command class implements a program or a command. Options and
  # subcommands can be accessed by their identifiers using #[] or through
  # individual member methods
  #
  # The following methods are created dynamically for each declared option
  # with an attribute name
  #
  #   <identifier>(default = nil)
  #   <identifier>=(value)
  #   <identifier>?()
  #
  # Corresponding #[] methods
  #   
  #   opts[:<identifier>] || default
  #   opts[:<identifier>] = value
  #   opts.key?(:<identifier>)
  #
  # The default value is used if the option or its value is missing
  #
  # Commands are accessible using a '!' method, this also allows a command and an
  # option to have the same name
  #
  #   <identifier>!()
  #
  # or alternatively
  #
  #   opts[:<identifier>!]
  #
  # the default identifier is nil and maps to the actual subcommand:
  #
  #   opts[]
  #
  # The command method returns nil if the command is not present. Use
  # #subcommand to get the actual subcommand
  #
  # Command is derived from BasicObject and have only a minimum of built-in
  # member methods that are reserved names. If an option name conflicts with a
  # reserved name, the option can only be accessed using #[]. Command defines
  # #subcommand but it can be overridden, in that case the subcommand is only
  # available using #[], eg. 'opts[]'
  #
  # Other Command member methods are named using a '__<identifier>__'
  # convention that are illegal option and comman names so they'll never
  # conflict
  #
  #
  #
  # The following names are reseved option names
  #
  #   ...
  #
  # There is only one reserved command name: 'subcommand'
  # 
  #
  #
  #
  #
  # The names of the inherited methods can't be used as options or
  # command names. They are: instance_eval, instance_exec method_missing,
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
    # TODO: uid = nil (the default) is the subcommand if present and otherwise nil
    #
    def [](uid = nil)
      !uid.nil? or return __subcommand__

      names = uid.to_s.gsub(/\./, "!.").split(/\./)
      idents = names.map(&:to_sym)

      names.inject(self) { |cmd, name|
#       if name.end_with?("!")
          
        case name
          when /!$/
            return nil if cmd.__subcommand__ != ident
            cmd = cmd.__subcommand__!
          else
            opt = cmd.__option_hash__[ident]
            opt.nil? && cmd.__grammar__[ident].repeatable? ? [] : opt
        end
            
        
      }
      

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

    def key?(ident)
    end

    # Returns a hash from option ident to value
    #
    # The value depends on the option type: If it is not repeatable, the value
    # is the argument or nil if not present (or allowed). If the option is
    # repeatable and has an argument, the value is an array of the arguments,
    # if it doesn't have an argument, the value is the number of occurrences
    #
    def to_h(*keys)
      keys = ::Kernel::Array(keys).flatten
      __option_values__.select { |key,_| keys.empty? || keys.include?(key) }
    end

    # Like #to_h but present options without arguments have a true value
    #
    def to_h?(*keys)
      keys = ::Kernel::Array(keys).flatten
      keys = keys.empty? ? __option_values__.keys : keys
      keys.filter_map { |key| __option_values__.key?(key) && [key, self.__send__(key)] }.to_h
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
    # The #subcommand/#subcommand! methods can be overridden by an option or a
    # command, in that case use #__subcommand__ or #[]:
    #
    #   prog, args = ShellOpts.parse("--subcommand subcommand!", ARGV)
    #   case prog[]
    #     when :subcommand!; ...
    #       prog[:subcommand] # option
    #       prog[:subcommand!] # command
    #       prog.__subcommand__ # command
    #   end
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

    # UID of command/program (String)
    def __uid__() @__grammar__.uid end

    # Identfier including the exclamation mark (Symbol)
    def __ident__() @__grammar__.ident end

    # Name of command/program without the exclamation mark (String)
    def __name__() @__grammar__.name end

    # Grammar object
    attr_reader :__grammar__

    # Map from option identifier to value. Repeated options options without
    # arguments have the number of occurences as value, repeated option with
    # arguments have the array of values as value
    attr_reader :__option_values__

    # List of Option objects for the subcommand in the same order as given by
    # the user but with options moved after their associated subcommand when
    # float is true. Repeated options are not collapsed
    attr_reader :__option_list__

    # Map from identifier to option object or to a list of option objects if
    # the option is repeatable
    attr_reader :__option_hash__

    # True if ident is a present option
    def __option__?(ident) = __option_hash__.key?(ident)

    # The parent command or nil. Initialized by #add_command
    attr_accessor :__supercommand__
    
    # The subcommand identifier (a Symbol incl. the exclamation mark) or nil
    # if not present. Use #subcommand!, or the dynamically generated
    # '#<identifier>!' method to get the actual subcommand object
    def __subcommand__() @__subcommand__&.__ident__ end

    # The actual subcommand object or nil if not present
    def __subcommand__!() @__subcommand__ end

    # True if ident is the actual subcommand
    def __subcommand__?(ident) = __subcommand__&.__ident__ == ident

  private
    def __initialize__(grammar)
      @__grammar__ = grammar
      @__option_values__ = {}
      @__option_list__ = [] 
      @__option_hash__ = {}
      @__subcommand__ = nil

      __define_option_methods__
    end

    def __define_option_methods__
      @__grammar__.options.each { |opt|
        ::Kernel.p opt
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
        next if cmd.ident.nil?
        self.instance_eval %(
          def #{cmd.ident}() 
            :#{cmd.ident} == __subcommand__ ? __subcommand__! : nil
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
    # Accessors for standard options values that are not affected if the option
    # is renamed
    attr_accessor :__quiet__
    attr_accessor :__verbose__
    attr_accessor :__debug__

    def initialize
      super
      @__quiet__ = false
      @__verbose__ = 0
      @__debug__ = false
    end
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

__END__

#   # Returns the concatenated identifier of subcommands (eg. :cmd.subcmd!)
#   def subcommands() __subcommands__ end
#
#   # Returns the subcommands in an array. This doesn't include the top-level
#   # program object
#   def subcommands!() __subcommands__! end

#   # The parent command or nil. Initialized by #add_command
#   #
#   # Note: Can be overridden by a subcommand declaration (but not an
#   # option), in that case use #__supercommand__! or
#   # ShellOpts.supercommand!(object) instead
#   #
#   def supercommand!() __supercommand__ end

#   # Implementation of the #subcommands method
#   def __subcommands__()
#     __subcommands__!.last&.__uid__&.to_sym
#   end
#
#   # Implementation of the #subcommands! method
#   def __subcommands__!()
#     ::Algorithm.follow(self.__subcommand__!, :__subcommand__!).to_a
#   end

#     # 
#     def split_uid(uid)
#       exprs = uid.to_s.gsub(/\./, "!.").split(/\./)
#       exprs.map { |expr| expr =~ /^(.*)\[(.*)\]$/ ? ["#$1!".to_sym, $2.to_i] : expr.to_sym }.flatten
#     end
#
#     # Syntax
#     #   command[integer] <- argument
#     #   command.command!
#     #   command.option
#     #
#     #   cmd1!
#     #   cmd2!
#     #     --gryf
#     #     gryf!
#     #
#     #   cmd3!
#     #
#     #   cmd2!
#     #   cmd1.cmd2!
#
#     def dot(uid)
#       split_uid(uid).inject(self) { |object, expr|
#         if expr.is_a?(Integer)
#           object.is_a?(Command) or raise
#           object.args[expr]
#         elsif object.is_a?(Grammar) && expr == :!
#           object.program
#         elsif object.is_a?(Group)
#           object.subcommand?(expr) or raise
#           object.groups.find { |group| group.key?(expr) }[expr]
#         elsif object.is_a?(Command)
#           object.key?(expr) or raise
#           object[expr]
#         else
#           raise
#         end
#       }
#     end

#   def split_uid(uid)
#     exprs = uid.to_s.gsub(/\./, "!.").split(/\./)
#     exprs.map { |expr| expr =~ /^(.*)\[(.*)\]$/ ? ["#$1!".to_sym, $2.to_i] : expr.to_sym }.flatten
#   end
#
#   def dot(uid)
#     split_uid(uid).inject(self) { |object, expr|
#       if object.is_a?(Command)
#         if expr.is_a?(Integer)
#           raise NotImplemented
#         else
#           case object.grammar
#             when Grammar::Group
#               
#             when Grammar::Command
#           else
#             raise
#           end
#
#           object.grammar.subcommand?(expr) or raise
#           object[expr]
#         end
#       if expr.is_a?(Integer)
#         object.is_a?(Command) or raise
#       elsif object.is_a?(Command)
#         case object.grammar
#           when Command
#           when Option
#             raise
#         end
#     }
#   end
      


