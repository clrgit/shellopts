module ShellOpts
  module Grammar
    class ArgumentType
      # Name of type
      def name() self.class.to_s.sub(/.*::/, "").sub(/Argument/, "") end

      # Return truish if value literal (String) match the type. Returns false
      # and set #message if the value doesn't match. <name> is used to
      # construct the error message and is the name/alias the user specified on
      # the command line
      def match?(name, literal) true end

      # Error message if match? returned false. Note that this method is not
      # safe for concurrent processing
      attr_reader :message

      # Return true if .value is an "instance" of self. Ie. an Integer object
      # if type is an IntegerArgument
      def value?(value) true end

      # Convert value to Ruby type. This method can also be used to translate
      # special keywords
      def convert(value) value end

      # String representation. Equal to #name
      def to_s() name end

    protected
      # Note that it is important that #set_message return false
      def set_message(msg)
        @message = msg
        false
      end
    end

    class StringType < ArgumentType
    end

    class IntegerArgument < ArgumentType
      def match?(name, literal)
        literal =~ /^-?\d+$/ or
            set_message "Illegal integer value in #{name}: #{literal}"
      end

      def value?(value) value.is_a?(Integer) end
      def convert(value) value.to_i end
    end

    class FloatArgument < ArgumentType
      def match?(name, literal)
        # https://stackoverflow.com/a/21891705/2130986
        literal =~ /^[+-]?(?:0|[1-9]\d*)(?:\.(?:\d*[1-9]|0))?$/ or
            set_message "Illegal decimal value in #{name}: #{literal}"
      end

      def value?(value) value.is_a?(Numeric) end
      def convert(value) value.to_f end
    end

    class FileArgument < ArgumentType
      attr_reader :kind

      def subject # Used in error messages
        @subject ||=
            case kind
              when :file, :efile; "regular file"
              when :nfile, :ifile, :ofile; "file"
              when :dir, :edir, :ndir; "directory"
              when :path, :epath, :npath; "path"
            else
              raise ArgumentError
            end
      end

      def initialize(kind)
        constrain kind, :file, :dir, :path, :efile, :edir, :epath, :nfile, :ndir, :npath, :ifile, :ofile
        @kind = kind
      end

      def match?(name, literal)
        # Special-case '-' keyword
        if literal == '-' && [:ifile, :ofile].include?(kind)
          true

        # Special-case standard I/O files. These files have read-write (rw)
        # filesystem permissions so they need to be handled individually
        elsif %w(/dev/stdin /dev/stdout /dev/stderr /dev/null).include?(literal)
          case kind
            when :file, :path, :efile, :epath, :nfile, :npath
              true
            when :ifile
              %w(/dev/stdin /dev/null).include? literal or set_message "Can't read #{literal}"
            when :ofile
              %w(/dev/stdout /dev/stderr /dev/null).include?(literal) or set_message "Can't write to #{literal}"
            when :dir, :edir, :ndir
              set_message "#{literal} is not a directory"
          else
            raise ArgumentError, "Unhandled kind: #{kind.inspect}"
          end

        # All other files or directories
        else
          case kind # TODO: node, enode, npath - special files: character, block, socket, etc.
            when :file; match_path(name, literal, kind, :file?, :default)
            when :dir; match_path(name, literal, kind, :directory?, :default)
            when :path; match_path(name, literal, kind, :exist?, :default)

            when :efile; match_path(name, literal, kind, :file?, :exist)
            when :edir; match_path(name, literal, kind, :directory?, :exist)
            when :epath; match_path(name, literal, kind, :exist?, :exist)

            when :nfile; match_path(name, literal, kind, :file?, :new)
            when :ndir; match_path(name, literal, kind, :directory?, :new)
            when :npath; match_path(name, literal, kind, :exist?, :new)

            when :ifile; match_path(name, literal, kind, :readable?, :default)
            when :ofile; match_path(name, literal, kind, :writable?, :default)
          else
            raise InternalError, "Illegal kind: #{kind.inspect}"
          end
        end
      end

      # Note: No checks done, not sure if it is a feature or a bug
      def value?(value) value.is_a?(String) end

      def convert(value)
        if value == "-"
          case kind
            when :ifile; "/dev/stdin"
            when :ofile; "/dev/stdout"
          else
            value
          end
        else
          value
        end
      end

    protected
      def match_path(name, literal, kind, method, mode)
        # file exists and the method returned true
        if File.send(method, literal)
          if mode == :new
            set_message "Won't overwrite #{literal}"
          elsif kind == :path || kind == :epath
            if File.file?(literal) || File.directory?(literal)
              true
            else
              set_message "#{literal} is not a file or a directory"
            end
          elsif (kind == :ifile || kind == :ofile) && File.directory?(literal)
            set_message "#{literal} is not a device file"
          else
            true
          end

        # file exists but the method returned false
        elsif File.exist?(literal)
          if kind == :ifile
            set_message "Can't read #{literal}"
          elsif kind == :ofile
            set_message "Can't write to #{literal}"
          elsif mode == :new
            set_message "Won't overwrite #{literal}"
          else
            set_message "#{literal} is not a #{subject}"
          end

        # file does not exist
        else
          if [:default, :new].include? mode
            dir = File.dirname(literal)
            if !File.directory?(dir)
              set_message "Illegal path - #{literal}"
            elsif !File.writable?(dir)
              set_message "Can't create #{subject} #{literal}"
            else
              true
            end
          else
            set_message "Can't find #{literal}"
          end
        end
      end
    end

    class EnumArgument < ArgumentType
      attr_reader :values
      def initialize(values) @values = values.dup end
      def match?(name, literal) value?(literal) or set_message "Illegal value - #{literal}" end
      def value?(value) @values.include?(value) end
    end
  end
end

