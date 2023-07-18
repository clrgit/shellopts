
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
        group = nil # Return value, defined below

        # Handle top-level Program object
        if parent.nil?
          main = defn.command_group.commands.first
          defn.grammar = group = @grammar = Grammar::Grammar.new(spec: main)
          program = Grammar::Program.new(group, name: main.name, spec: main)

        # Qualified command. Qualified commands are always stand-alone
        elsif (cmd = defn.commands.first).qualified?
          curr = grammar.program
          cmd.path.each { |ident|
            if curr.key?(ident)
              curr = curr[ident]
            else
              group = Grammar::Group.new(curr.group, spec: cmd)
              curr = Grammar::Command.new(group, ident, spec: cmd)
            end
          }

          !group.nil? or analyzer_error defn.token, "Duplicate command: #{cmd.token.value}"

        # Same-level unqualified commands
        else
          group = Grammar::Group.new(parent, spec: defn)
          defn.commands.each { |cmd| # check for duplicates and collect idents
            !parent.key?(cmd.ident) or analyzer_error cmd.token, "Duplicate command: #{cmd.name}"
            Grammar::Command.new(group, cmd.ident, spec: cmd)
          }
        end

        # Forward group to children
        group
      }
    end

    def analyze_options
      # Process free-standing options
      spec.pairs(Spec::CommandDefinition, Spec::OptionDefinition).group.each { |cmd_def, opt_defs|
        opt_defs.each { |opt_def|
          opt_def.filter(Spec::Option) { |opt|
            Grammar::GroupOption.new(cmd_def.grammar, spec: opt)
          }
        }
      }

      # Process per-command options
      spec.pairs(Spec::Command, Spec::Option) { |cmd, opt|
        Grammar::CommandOption.new(cmd.grammar, spec: opt)
      }

      # Create arguments
      grammar.filter(Grammar::Option).each { |option|
        opt = option.spec
        if opt.argument?
          arg = opt.argument
          argument = Grammar::Arg.new(option, arg.name.to_sym, arg.type, spec: opt) 
        end
      }
    end

    def analyze_args
      spec.pairs(Spec::CommandDefinition, Spec::ArgSpec) { |cmd_defn, arg_spec|
        command = cmd_defn.grammar
        arg_spec.args.each { |arg|
          Grammar::Arg.new(command, arg.name.to_sym, arg.type, spec: arg)
        }
      }
    end


#   def analyze_args
#     spec.filter(Spec::ArgSpec).each { |arg_spec|
#       p arg_spec.class
#       case arg_spec.parent
#         when Spec::Description
#           command = arg_spec.parent.grammar
#           puts "..........."
#           p arg_spec.parent.class
#           p arg_spec.parent.parent.class
#           p arg_spec.parent.parent.grammar
#           p command
#           constrain command, Grammar::Command
#         when Spec::Command
#           command = arg_spec.parent
#       end
#       arg_spec.args.each { |arg|
#         Grammar::Arg.new(command, arg.name.to_sym, arg.type, spec: arg)
#       }
#     }
#   end
  end
end

__END__
#       pu  ts "commands: #{

        puts "Grammar commands:"
        indent { 
          grammar.filter(Grammar::Command) { |cmd|
            puts "#{cmd.inspect} @#{cmd.object_id}"
            puts "  #{cmd.spec.inspect} @#{cmd.spec.object_id}"
          }
        }

        puts "Spec commands:"
        indent { 
          spec.filter(Spec::Command) { |cmd|
            puts "#{cmd.inspect} @#{cmd.object_id}"
            puts "  #{cmd.grammar.inspect} @#{cmd&.grammar&.object_id || 'nil'}"
          }
        }

        exit


      # Same-line options
      same_cmds = spec.pairs(Spec::Command, Spec::Option).map { |node, opt|
        p node.class
        p node.token
        command = node.grammar
        p command

        Grammar::Option.new(command, spec: opt)
      }

      }

      # Options on their own line(s)
      spec.filter([Spec::Spec, Spec::CommandDefinition]) { |node|
        command = node.grammar
        opt_defns = node.description.children.select { |node| node.is_a?(Spec::OptionDefinition) }
        opt_defns.each { |opt_defn|
          opt_defn.options.each { |opt|
            Grammar::Option.new(command, spec: opt)
          }
        }
      }




      program = Grammar::Node[nil]
      
      Grammar.program.dump
      exit

      spec.filter(Spec::OptionDefinition) { |node|
        puts node.token
        indent {
          node.options.each { |opt|
            p opt.class
          }
        }
      }
      exit


      # Alternatively
      spec.filter(Spec::Spec, Spec::Command).each { |node|
        # Find Grammar object
        # Find Command options
        # Find Description options
        # Check for duplicates
        # Create options
      }

      # Find commands with same-line options
      same_cmds = spec.pairs([Spec::Spec, Spec::Command], Spec::Option).map { |cmd, opt|
        puts "#{cmd.name} #{opt&.name}"
      }

      # Find commands with nested options
      

      exit


      spec.visit(Spec::Option) { |opt|
        puts opt.token
        indent { 
          if opt.option_subgroup
            puts "subgroup   : #{opt.option_subgroup.token}"
            puts "group      : #{opt.option_group.token}"
            puts "description: #{opt.option_group.description}"
          else
            puts "<command option>"
          end
        }
      }
      # for each command definition
      #   for each command group
      #     for each command
      #       for each option
      #       end
      #     end
      #   end
      # end
      #
      # for each option definition
      #   for each option group
      #     for each option subgroup
      #       for each option
      #       end
      #     end
      #   end
      # end
      puts "done"
    end

#     exit
#
#     grammar = Grammar::Program.new(name: spec.name)
#     spec.accumulate(Spec::CommandDefinition, grammar) { |acc, defn|
#       cmds = defn.subject.commands
#       new_acc = acc
#       cmds.each { |cmd| 
#         ident = "#{cmd.name}!".to_sym
#         new_acc = Grammar::Command.new(acc, ident, spec: cmd) 
#       }
#       new_acc
#     }
#
#     puts
#     grammar.dump
#     exit
#
#     spec.pairs(Spec::CommandDefinition, Spec::Command) { |defn, cmd|
#     }
#
#
#
#     spec.dump
#     exit
#
#     # Create grammar and link back and forth between Grammar and Spec objects
#     grammar = Grammar::Program.new(name: spec.name)
#     finalized = {} # Keeps track of commands not created as part of a dotted command
#
#     puts ">>>>>>>>>>>>>>>>"
#     spec.accumulate(Spec::CommandGroup, grammar) { |acc, defn|
#       cmds = defn.commands
#
#       cmds.each { |cmd|
#         dot_acc = acc
#         names = cmd.token.value.sub(/!$/, "").split(".")
#         while name = names.shift
#           ident = "#{name}!".to_sym
#           dot_acc = dot_acc[ident] || Grammar::Command.new(dot_acc, ident, spec: cmd)
#         end
#         !finalized.key?(dot_acc.uid) or analyzer_error cmd.token, "Duplicate command definition"
#         finalized[dot_acc.uid] = dot_acc
#         cmd.command = dot_acc
#         acc = dot_acc
#       }
#       acc
#     }
#
#     spec.accumulate(Spec::Command, grammar, this: false) { |acc, cmd|
#       puts ">> #{cmd.token.value}"
#       names = cmd.token.value.sub(/!$/, "").split(".")
#       while name = names.shift
#         ident = "#{name}!".to_sym
#         acc = acc[ident] || Grammar::Command.new(acc, ident, spec: cmd)
#       end
#       !finalized.key?(acc.uid) or analyzer_error cmd.token, "Duplicate command definition"
#       finalized[acc.uid] = acc
#       cmd.command = acc
#     }

#     grammar.dump
#     exit

  end
end









__END__
# IDEA: Create an option-soup from the Grammar, and let the interpreter remove
# options from it as they are processed. Duplicate options are removed when
# commands are processed as they disamguates options. We need to mark duplicate
# options as such
#


module ShellOpts
  module Grammar
    class Node
      def remove_brief_nodes
        children.delete_if { |node| node.is_a?(Brief) }
      end

      def remove_arg_descr_nodes
        children.delete_if { |node| node.is_a?(ArgDescr) }
      end

      def remove_arg_spec_nodes
        children.delete_if { |node| node.is_a?(Spec) }
      end

      def analyzer_error(token, message) 
        raise AnalyzerError.new(token), message 
      end
    end

    class Command
      def collect_options
        @options = option_groups.map(&:options).flatten
      end

      # Move options before first command or before explicit COMMAND section
      def reorder_options
        if commands.any?
          i = children.find_index { |child| 
            child.is_a?(Command) || child.is_a?(Section) && child.name == "COMMAND"
          }
          if i
            options, rest = children[i+1..-1].partition { |child| child.is_a?(OptionGroup) }
            @children = children[0, i] + options + children[i..i] + rest
          end
        end
      end

      def compute_option_hashes
        options.each { |option|
          option.idents.zip(option.names).each { |ident, name|
            !@options_hash.key?(name) or 
                analyzer_error option.token, "Duplicate option name: #{name}"
            @options_hash[name] = option
            !@options_hash.key?(ident) or 
                analyzer_error option.token, "Can't use both #{@options_hash[ident].name} and #{name}"
            @options_hash[ident] = option
          }
        }
      end

      # TODO Check for dash-collision
      def compute_command_hashes
        commands.each { |command|
          !@commands_hash.key?(command.name) or 
              analyzer_error command.token, "Duplicate command name: #{command.name}"
          @commands_hash[command.name] = command
          @commands_hash[command.ident] = command
          command.compute_command_hashes
        }
      end
    end
  end

  class Analyzer
    include Grammar

    attr_reader :grammar

    def initialize(grammar)
      @grammar = grammar
    end

    def create_implicit_commands(cmd)
      path = cmd.path[0..-2]
    end

    # Link up commands with supercommands. This is only done for commands that
    # are nested within a different command than it belongs to. The
    # parent/child relationship is not changed Example:
    #
    #   cmd!
    #   cmd.subcmd! 
    #
    # Here subcmd is added to cmd's list of commands. It keeps its position in
    # the program's parent/child relationship so that documentation will print the
    # commands in the given order and with the given indentation level
    #
    def link_commands
      # We can't use Command#[] at this point so we collect the commands here
      h = {}
      @grammar.traverse(Grammar::Command) { |command|
        h[command.path] = command
        # TODO: Pick up parent-less commands
      }

      # Command to link
      link = []

      # Create implicit commands
      h.sort { |l,r| l.size <=> r.size }.each { |path, command|
        path = path[0..-2]
        while !h.key?(path)
          cmd = Grammar::Command.new(nil, command.token)
          cmd.set_name(path.last.to_s.sub(/!/, ""), path.dup)
          link << cmd
          h[cmd.path] = cmd
          path.pop
        end
      }

      # Find commands to link
      #
      # Commands are linked in two steps because the behaviour of #traverse is
      # not defined when the data structure changes beneath it. (FIXME: Does it
      # change when we don't touch the parent/child relationship?)
      @grammar.traverse(Grammar::Command) { |command|
        if command.path.size > 1 && command.parent && command.parent.path != command.path[0..-2]
#       if command.path.size > 1 && command.parent.path != command.path[0..-2]
          link << command
        else
          command.instance_variable_set(:@command, command.parent)
        end
      }

      # Link commands but do not change parent/child relationship
      link.each { |command|
        path = command.path[0..-2]
        path.pop while (supercommand = h[path]).nil?
        command.parent.commands.delete(command) if command.parent
        supercommand.commands << command
        command.instance_variable_set(:@command, supercommand)
      }
    end

    def analyze()
      link_commands

      @grammar.traverse(Grammar::Command) { |command|
        command.reorder_options
        command.collect_options
        command.compute_option_hashes
      }

      @grammar.compute_command_hashes

      @grammar.traverse { |node| 
        node.remove_brief_nodes 
        node.remove_arg_descr_nodes
        node.remove_arg_spec_nodes
      }

      @grammar
    end

    def Analyzer.analyze(source) self.new(source).analyze end
  end
end

