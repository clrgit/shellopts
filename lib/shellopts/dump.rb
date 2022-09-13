module ShellOpts
  module Grammar
    class IdrNode
      def dump_doc
        puts "#{self.class} #{ident}"
        indent {
          children.each(&:dump_doc)
        }
      end
    end
  end

  module Grammar
    class Command
      # Usable after parsing
      def render_structure
        io = StringIO.new
        dump_structure(io)
        io.string
      end

      def dump_structure(device = $stdout)
        device.puts ident
        device.indent { |dev|
          option_groups.each { |group| dev.puts group.options.map(&:name).join(" ") }
          commands.each { |command| command.dump_structure(dev) }
          descrs.each { |descr| dev.puts descr.text }
        }
      end
    end
  end

  module Grammar
    class Node
      def dump_ast
        puts "#{classname} @ #{token.pos} #{token.source}"
        indent { children.each(&:dump_ast) }
      end

      def dump_idr(short = false)
        puts "#{classname}" if !short
      end

      def dump_attrs(*attrs)
        indent {
          Array(attrs).flatten.select { |attr| attr.is_a?(Symbol) }.each { |attr|
            value = self.send(attr)
            case value
              when Brief
                puts "#{attr}: #{value.text}"
              when Node
                puts "#{attr}:"
                indent { value.dump_idr }
              when Array
                case value.first
                  when nil
                    puts "#{attr}: []"
                  when Node
                    puts "#{attr}:"
                    indent { value.each(&:dump_idr) }
                else
                  puts "#{attr}: #{value.inspect}"
                end
              when Type
                puts "#{attr}: #{value}"
            else
#             value = value.inspect if value.nil? || !value.respond_to?(:to_s)
              puts "#{attr}: #{value.inspect}"
            end
          }
        }
      end

    protected
      def classname() self.class.to_s.sub(/.*::/, "") end
    end

    class Option
      def dump_idr(short = false)
        if short
          s = [
              name, 
              argument? ? argument_type.name : nil, 
              optional? ? "?" : nil, 
              repeatable? ? "*" : nil
          ].compact.join(" ")
          puts s
        else
          puts "#{name}: #{classname}"
          dump_attrs(
              :uid, :path, :attr, :ident, :name, :idents, :names,
              :repeatable?, 
              :argument?, argument? && :argument_name, argument? && :argument_type, 
              :enum?, enum? && :argument_enum, 
              :optional?)
          indent { puts "brief: #{group.brief}" }
        end
      end
    end

    class Command
      def dump_idr(short = false)
        if short
          puts name
          indent { 
            options.each { |option| option.dump_idr(short) }
            commands.each { |command| command.dump_idr(short) }
            descrs.each { |descr| descr.dump_idr(short) }
          } 
        else
          puts "#{name}: #{classname}"
          dump_attrs :uid, :path, :ident, :name, :options, :commands, :specs, :descrs, :brief
        end
      end
    end

    class ArgDescr
      def dump_idr(short = false)
        super
        indent { puts token.to_s }
      end
    end

    class ArgSpec < Node
      def dump_idr(short = false)
        super
        dump_attrs :arguments
      end
    end

    class Arg < Node
      def dump_idr(short = false)
        puts "<type>"
      end
    end
  end

class Command
    def __dump__(argv = [])
      ::Kernel.puts __name__
      ::Kernel.indent {
        __options__.each { |ident, value| ::Kernel.puts "#{ident}: #{value.inspect}" }
        __subcommand__!&.__dump__
        ::Kernel.puts argv.map(&:inspect).join(" ") if !argv.empty?
      }
    end

    # Class-level accessor methods
    def self.dump(expr, argv = []) expr.__dump__(argv) end
  end

  class Option
    def dump
      ::Kernel.puts [name, argument].compact.join(" ")
    end
  end
end

