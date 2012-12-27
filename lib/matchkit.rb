require 'amatch'
include Amatch

class Matchkit
  def test

    # m = Sellers.new("pattern")
    # # => #<Amatch::Sellers:0x40366324>
    # puts m.match("pattren")
    # # => 2.0
    # m.substitution = m.insertion = 3
    # # => 3
    # m.match("pattren")
    # # => 4.0
    # m.reset_weights
    # # => #<Amatch::Sellers:0x40366324>
    # m.match(["pattren","parent"])
    # # => [2.0, 4.0]
    # m.search("abcpattrendef")
    # # => 2.0

    m = Levenshtein.new("pattern")
    # => #<Amatch::Levenshtein:0x4035919c>
    m.match("pattren")
    # => 2
    m.search("abcpattrendef")
    # => 2
    "pattern language".levenshtein_similar("language of patterns")
    # => 0.2

    m = Hamming.new("pattern")
    # => #<Amatch::Hamming:0x40350858>
    m.match("pattren")
    # => 2
    "pattern language".hamming_similar("language of patterns")
    # => 0.1

    m = PairDistance.new("pattern")
    # => #<Amatch::PairDistance:0x40349be8>
    m.match("pattr en")
    # => 0.545454545454545
    m.match("pattr en", nil)
    # => 0.461538461538462
    m.match("pattr en", /t+/)
    # => 0.285714285714286
    "pattern language".pair_distance_similar("language of patterns")
    # => 0.928571428571429

    m = LongestSubsequence.new("pattern")
    # => #<Amatch::LongestSubsequence:0x4033e900>
    m.match("pattren")
    # => 6
    "pattern language".longest_subsequence_similar("language of patterns")
    # => 0.4

    m = LongestSubstring.new("pattern")
    # => #<Amatch::LongestSubstring:0x403378d0>
    m.match("pattren")
    # => 4
    "pattern language".longest_substring_similar("language of patterns")
    # => 0.4

    m = Jaro.new("pattern")
    # => #<Amatch::Jaro:0x363b70>
    m.match("paTTren")
    # => 0.952380952380952
    m.ignore_case = false
    m.match("paTTren")
    # => 0.742857142857143
    "pattern language".jaro_similar("language of patterns")
    # => 0.672222222222222

    m = JaroWinkler.new("pattern")
    # #<Amatch::JaroWinkler:0x3530b8>
    m.match("paTTren")
    # => 0.971428571712403
    m.ignore_case = false
    m.match("paTTren")
    # => 0.79428571505206
    m.scaling_factor = 0.05
    m.match("pattren")
    # => 0.961904762046678
    "pattern language".jarowinkler_similar("language of patterns")
    # => 0.672222222222222
  end
end