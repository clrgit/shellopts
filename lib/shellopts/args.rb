
module ShellOpts
  # Specialization of Array for arguments lists. Args extends Array with a
  # #extract and an #expect method to extract elements from the array. The
  # methods raise a ShellOpts::Error exception in case of errors
  #
  class Args < Array
    def initialize(*args, exception: false)
      super(*args)
      @exception = exception
    end

    # :call-seq:
    #   extract(count, message = nil)
    #   extract(range, message = nil)
    #
    # Remove and return elements from beginning of the array
    #
    # If +count_or_range+ is a number, that number of elements will be
    # returned.  If the count is one, a simple value is returned instead of an
    # array. If the count is negative, the elements will be removed from the
    # end of the array. If +count_or_range+ is a range, the number of elements
    # returned will be in that range. Note that the range can't contain
    # negative numbers
    #
    # #extract raise a ShellOpts::Error exception if there's is not enough
    # elements in the array to satisfy the request
    #
    # TODO: Better handling of ranges. Allow: 2..-1, -2..-4, etc.
    def extract(count_or_range, message = nil)
      case count_or_range
        when Range
          range = count_or_range
          range.min <= self.size or inoa(message)
          return self.to_a if range.end.nil?
          n_extract = [self.size, range.max].min
          n_extend = range.max > self.size ? range.max - self.size : 0
          r = self.shift(n_extract) + Array.new(n_extend)
          range.max <= 1 ? r.first : r
        when Integer
          count = count_or_range
          count.abs <= self.size or inoa(message)
          start = count >= 0 ? 0 : size + count
          r = slice!(start, count.abs)
          r.size == 1 ? r.first : r
        else
          raise ArgumentError
      end
    end

    # Return true args contains at least the given count or range of elements
    def extract?(count_or_range)
      case count_or_range
        when Range
          count_or_range.min <= self.size
        when Integer
          count_or_range.abs <= self.size
      else
        raise ArgumentError
      end
    end

    # As #extract except the array is expected to be emptied by the operation.
    # Raise a #inoa exception if count is negative
    #
    # #expect raise a ShellOpts::Error exception if the array is not emptied
    # by the operation
    #
    # TODO: Better handling of ranges. Allow: 2..-1, -2..-4, etc.
    def expect(count_or_range, message = nil)
      case count_or_range
        when Range
          count_or_range === self.size or inoa(message)
          return self.to_a if count_or_range.end.nil?
        when Integer
          count_or_range >= 0 or inoa(message)
          count_or_range.abs == self.size or inoa(message)
      end
      extract(count_or_range) # Can't fail
    end

    # Return true args contains the given count or range of elements
    def expect?(count_or_range, message = nil)
      case count_or_range
        when Range
          count_or_range === self.size
        when Integer
          count_or_range >= 0 or raise ArgumentError # FIXME in #expect
          count_or_range.abs == self.size
      else
        raise ArgumentError
      end
    end

  private
    def inoa(message = nil)
      message ||= "Illegal number of arguments"
      raise Error, message if @exception
      ::ShellOpts.error(message)
    end
  end
end

