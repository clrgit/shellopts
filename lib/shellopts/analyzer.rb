
module ShellOpts
  class Analyzer
    attr_reader :ast
    attr_reader :grammar

    def initialize(ast)
      constrain ast, Ast::Spec
      @ast = ast
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

    def self.analyze(ast) = self.new(ast).analyze

    def analyzer_error(token, message) = self.class.analyzer_error(token, message)

    def self.analyzer_error(token, message)
      raise AnalyzerError.new(token), message 
    end

  protected
    # List of classes derived from Ast::Node (incl. Ast::Node)
    def spec_classes
      @spec_classes ||= Ast::Node.descendants(this: true)
    end

    # Return list of Ast classes that accepts objects of the given class
    def accepts(klass)
      spec_classes.select { |klasses| klasses.accepts.any? { |k| k >= klass } }
    end

    def check_options
      ast.pairs(Ast::OptionDefinition, Ast::OptionDefinition) { |first, last|
        analyzer_error last.token, "Options can't be nested within an option"
      }
    end

    def check_briefs
      ast.filter([Ast::CommandDefinition, Ast::OptionDefinition]) { |defn|
        defn.description.children.select { _1.is_a? Ast::Brief }.size <= 1 or 
            analyzer_error defn.token, "Duplicate brief definition"
      }
    end

    def check_arg_specs
      h = Set.new
      ast.filter(Ast::ArgSpec) { |arg_spec|
        !h.include?(arg_spec.parent) or analyzer_error arg_spec.token, "Duplicate argument specification"
        h.add arg_spec.parent
      }
    end

    def check_arg_descrs
      ast.pairs(Ast::Definition, Ast::ArgDescr).group.each { |_, children|
        children.size <= 1 or analyzer_error children[1].token, "Multiple argument descriptions"
      }
    end

    def check_commands
      # Check that commands are not nested within options
      ast.pairs(Ast::OptionDefinition, Ast::Command).each { |defn, cmd|
        analyzer_error cmd.token, "Commands can't be nested within an option"
      }

      # Check that dotted commands are stand-alone. This may be relaxed later
      is_qualified = lambda { |node| node.qualified? }
      ast.filter(:qualified?).each { |cmd|
        cmd.command_group.size == 1 or analyzer_error cmd.token, "Qualified commands must be stand-alone"
      }
    end

    def analyze_commands
      qualified_commands = []
      ast.accumulate(Ast::CommandDefinition, nil) { |parent,defn|
        group = nil # Forward value, defined below

        # Handle top-level Program object
        if parent.nil?
          main = defn.command_group.commands.first
          group = @grammar = Grammar::Grammar.new(main)
          program = Grammar::Program.new(group, ast, name: main.name)

        # Collect qualified commands
        elsif (cmd = defn.commands.first).qualified?
          qualified_commands << [parent, defn, cmd]

        # Same-level unqualified commands
        else
          group = Grammar::Group.new(parent, parent.groups.size, defn)
          defn.commands.each { |cmd| # check for duplicates and collect idents
            !parent.subcommand?(cmd.ident) or analyzer_error cmd.token, "Duplicate command: #{cmd.name}"
            Grammar::Command.new(group, cmd.ident, cmd)
          }
        end

        # Assign grammar and forward to children
        defn.grammar = group
      }

      # Qualified commands are initialized after unqualified commands because
      # otherwise they could create non-callable commands that would later
      # conflict a callable command
      qualified_commands.each { |parent, defn, cmd|
        group = @grammar
        command = nil
        cmd.path.each { |ident|
          if match = group.groups.find { _1.key?(ident) }
            group = match
          else
            group = Grammar::Group.new(group, group.groups.size, defn)
            command = Grammar::Command.new(group, ident, cmd, callable: false)
          end
        }
        !command.nil? or analyzer_error defn.token, "Duplicate command: #{cmd.token.value}"
      }
    end

    def analyze_options
      # Process free-standing options. These are attached to the command group
      ast.pairs(Ast::CommandDefinition, Ast::OptionDefinition).group.each { |cmd_def, opt_defs|
        opt_defs.each { |opt_def|
          opt_def.filter(Ast::Option) { |opt|
            Grammar::Option.new(cmd_def.grammar, opt)
          }
        }
      }

      # Process per-command options. These are attached to the command
      ast.pairs(Ast::Command, Ast::Option) { |cmd, opt|
        Grammar::Option.new(cmd.grammar, opt)
      }

      # Create option arguments
      grammar.filter(Grammar::Option).each { |option|
        opt = option.ast
        if opt.argument?
          arg = opt.argument
          argument = Grammar::Arg.new(option, arg.name.to_sym, arg.type, opt) 
        end
      }
    end

    def analyze_args
      ast.filter(Ast::ArgSpec) { |arg_spec|
        parent = arg_spec.parent.grammar
        arg_spec.args.each { |arg|
          Grammar::Arg.new(parent, arg.name.to_sym, arg.type, arg)
        }
      }
    end
  end
end

