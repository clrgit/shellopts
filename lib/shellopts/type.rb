module ShellOpts
  module Type
    class Type
      # Name of type
      def name = self.class.to_s.sub(/.*::/, "").sub(/Type$/, "")

      # Return truish if +literal+ (String) match the type. Returns false
      # and set #message if the value doesn't match. <name> is used to
      # construct the error message and is the name/alias the user specified on
      # the command line
      def match?(name, literal) true end # FIXME: Why not an abstract method?

      # Error message if match? returned false. Note that this method is not
      # safe for concurrent processing
      attr_reader :message

      # Return true if +value+ is an "instance" of self. Ie. an Integer object
      # if type is an IntegerType
      def value?(value) true end

      # Convert value to Ruby type. This method can also be used to translate
      # special keywords
      def convert(value) value end

      # String representation. Equal to #name
      def to_s() name end

    protected
      # it is important that #set_message return false
      def set_message(msg)
        @message = msg
        false
      end
    end

    class StringType < Type
    end

    class IntegerType < Type
      def match?(name, literal) 
        literal =~ /^-?\d+$/ or 
            set_message "Illegal integer value in #{name}: #{literal}" 
      end

      def value?(value) value.is_a?(Integer) end
      def convert(value) value.to_i end
    end

    class FloatType < Type
      def match?(name, literal) 
        # https://stackoverflow.com/a/21891705/2130986
        literal =~ /^[+-]?(?:0|[1-9]\d*)(?:\.(?:\d*[1-9]|0))?$/ or 
            set_message "Illegal decimal value in #{name}: #{literal}"
      end

      def value?(value) value.is_a?(Numeric) end
      def convert(value) value.to_f end
    end

    class EnumType < Type
      attr_reader :values
      def initialize(values) @values = values.dup end
      def match?(name, literal) value?(literal) or set_message "Illegal value in #{name}: '#{literal}'" end
      def value?(value) @values.include?(value) end
    end

    class FileType < Type
      KINDS = [:file, :dir, :path, :efile, :edir, :epath, :nfile, :ndir, :npath, :ifile, :ofile]
      
      attr_reader :kind

      def initialize(kind)
        constrain kind, *KINDS
        @kind = kind 
      end

      def match?(name, literal)
        # Special-case '-' keyword
        if literal == '-' && [:ifile, :ofile].include?(kind)
          true

        # Special-case standard I/O files
        elsif %w(/dev/stdin /dev/stdout /dev/stderr /dev/null).include?(literal)
          case kind
            when :file, :path, :efile, :epath, :nfile, :npath
              true
            when :ifile
              %w(/dev/stdin /dev/null).include? literal or 
                  set_message "Can't read #{literal}"
            when :ofile
              %w(/dev/stdout /dev/stderr /dev/null).include?(literal) or 
                  set_message "Can't write to #{literal}"
            when :dir, :edir, :ndir
              set_message "Expected file, got directory #{literal}"
          else
            raise ArgumentError, "Unhandled kind: #{kind.inspect}"
          end

        # All other files or directories
        # TODO: node, enode, npath - special files: character, block, socket, etc.
        # TODO: zdir - an empty directory
        else
          case kind 
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
        subject = 
            case kind
              when :file, :efile, :nfile, :ifile, :ofile; "file"
              when :dir, :edir, :ndir; "directory"
              when :path, :epath, :npath; "path"
            else
              raise ArgumentError
            end

        # file exists and is the rigth type?
        if File.send(method, literal)
          if mode == :new
            set_message "#{subject.capitalize} already exists in #{name}: #{literal}"
          elsif kind == :path || kind == :epath
            if File.file?(literal) || File.directory?(literal)
              true
            else
              set_message "Expected file or directory as #{name} argument: #{literal}"
            end
          elsif (kind == :ifile || kind == :ofile) && File.directory?(literal)
            set_message "File expected, got directory: #{literal}"
          else
            true
          end

        # file exists but not the right type?
        elsif File.exist?(literal)
          if kind == :ifile
            set_message "Can't read #{literal}"
          elsif kind == :ofile
            set_message "Can't write to #{literal}"
          elsif mode == :new
            set_message "#{subject.capitalize} already exists - #{literal}"
          else
            set_message "Expected #{subject} as #{name} argument: #{literal}"
          end

        # file does not exist
        else 
          if [:default, :new].include? mode
            if File.exist?(File.dirname(literal)) || kind == :ofile
              true
            else
              set_message "Illegal path in #{name}: #{literal}"
            end
          else
            set_message "Can't find #{literal}"
          end
        end
      end
    end
  end
end

