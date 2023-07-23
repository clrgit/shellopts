
module ShellOpts
  class Analyzer
    attr_reader :grammar
    attr_reader :spec

    def initialize(spec)
      @spec = spec
    end

    def validate
    end

    def analyze
      # Pre-checks
      check_options
      check_briefs
      check_arg_specs
      check_arg_descrs
      check_commands

      analyze_commands
      analyze_options
      analyze_args

      [@grammar, @doc]
    end

    def analyzer_error(token, message) = self.class.analyzer_error(token, message)

    def self.analyzer_error(token, message)
      raise AnalyzerError.new(token), message 
    end

  protected
    # List of classes derived from Spec::Node (incl. Spec::Node)
    def spec_classes
      @spec_classes ||= Spec::Node.descendants(this: true)
    end

    # Return list of Spec classes that accepts objects of the given class
    def accepts(klass)
      spec_classes.select { |klasses| klasses.accepts.any? { |k| k >= klass } }
    end

    def check_options
      spec.pairs(Spec::OptionDefinition, Spec::OptionDefinition) { |first, last|
        analyzer_error last.token, "Options can't be nested within an option"
      }
    end

    def check_briefs
      spec.filter([Spec::CommandDefinition, Spec::OptionDefinition]) { |defn|
        defn.description.children.select { _1.is_a? Spec::Brief }.size <= 1 or 
            analyzer_error defn.token, "Duplicate brief definition"
      }
    end

    def check_arg_specs
      h = Set.new
      spec.filter(Spec::ArgSpec) { |arg_spec|
        !h.include?(arg_spec.parent) or analyzer_error arg_spec.token, "Duplicate argument specification"
        h.add arg_spec.parent
      }
    end

    def check_arg_descrs
      spec.pairs(Spec::Definition, Spec::ArgDescr).group.each { |_, children|
        children.size <= 1 or analyzer_error children[1].token, "Multiple argument descriptions"
      }
    end

    def check_commands
      # Check that commands are not nested within options
      spec.pairs(Spec::OptionDefinition, Spec::Command).each { |defn, cmd|
        analyzer_error cmd.token, "Commands can't be nested within an option"
      }

      # Check that dotted commands are stand-alone. This may be relaxed later
      is_qualified = lambda { |node| node.qualified? }
      spec.filter(:qualified?).each { |cmd|
        cmd.command_group.size == 1 or analyzer_error cmd.token, "Qualified commands must be stand-alone"
      }
    end

    def analyze_commands
      spec.accumulate(Spec::CommandDefinition, nil) { |parent,defn|
        group = nil # Forward value, defined below

        # Handle top-level Program object
        if parent.nil?
          main = defn.command_group.commands.first
          group = @grammar = Grammar::Grammar.new(main)
          program = Grammar::Program.new(group, spec, name: main.name)

        # Qualified command. Qualified commands are always stand-alone. TODO:
        # Create a QualifiedCommand class
        elsif (cmd = defn.commands.first).qualified?
          group = @grammar
          command = nil
          cmd.path.each { |ident|
            if match = group.groups.find { _1.key?(ident) }
              group = match
            else
              group = Grammar::Group.new(group, group.groups.size, cmd)
              command = Grammar::Command.new(group, ident, cmd, callable: false)
            end
          }
          !command.nil? or analyzer_error defn.token, "Duplicate command: #{cmd.token.value}"

        # Same-level unqualified commands
        else
          group = Grammar::Group.new(parent, parent.groups.size, defn)
          defn.commands.each { |cmd| # check for duplicates and collect idents
            !group.key?(cmd.ident) or analyzer_error cmd.token, "Duplicate command: #{cmd.name}"
            Grammar::Command.new(group, cmd.ident, cmd)
          }
        end

        # Assign grammar and forward to children
        defn.grammar = group
      }
    end

    def analyze_options
      # Process free-standing options. These are attached to the command group
      spec.pairs(Spec::CommandDefinition, Spec::OptionDefinition).group.each { |cmd_def, opt_defs|
        opt_defs.each { |opt_def|
          opt_def.filter(Spec::Option) { |opt|
            Grammar::Option.new(cmd_def.grammar, opt)
          }
        }
      }

      # Process per-command options. These are attached to the command
      spec.pairs(Spec::Command, Spec::Option) { |cmd, opt|
        Grammar::Option.new(cmd.grammar, opt)
      }

      # Create option arguments
      grammar.filter(Grammar::Option).each { |option|
        opt = option.spec
        if opt.argument?
          arg = opt.argument
          argument = Grammar::Arg.new(option, arg.name.to_sym, arg.type, opt) 
        end
      }
    end

    def analyze_args
      spec.filter(Spec::ArgSpec) { |arg_spec|
        parent = arg_spec.parent.grammar
        arg_spec.args.each { |arg|
          Grammar::Arg.new(parent, arg.name.to_sym, arg.type, arg)
        }
      }
    end
  end
end

