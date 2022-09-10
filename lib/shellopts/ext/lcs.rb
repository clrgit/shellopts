
# https://gist.github.com/Joseph-N/fbf061aa2347ed2c104f0b3fe1a5b9f2
#
# TODO: Move to String and make find_longest_command_substring_index return a
# range
module LCS
  def self.find_longest_common_substring(s1, s2)
    i, z = find_longest_command_substring_index(s1, s2)
    s1[i .. i + z]
  end

  def self.find_longest_common_substring_index(s1, s2)
    if (s1 == "" || s2 == "")
      return [0,0]
    end
    m = Array.new(s1.length){ [0] * s2.length }
    longest_length, longest_end_pos = 0,0
    (0 .. s1.length - 1).each do |x|
      (0 .. s2.length - 1).each do |y|
        if s1[x] == s2[y]
          m[x][y] = 1
          if (x > 0 && y > 0)
            m[x][y] += m[x-1][y-1]
          end
          if m[x][y] > longest_length
            longest_length = m[x][y]
            longest_end_pos = x
          end
        end
      end
    end
    [longest_end_pos - longest_length + 1, longest_length]
  end
end
