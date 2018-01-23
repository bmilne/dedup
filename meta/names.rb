#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'namae'
require 'yaml'

module Namae

  # NameFormatting can be mixed in by an object providing individual
  # name parts (family, given, suffix, particle, etc.) to add support
  # for name formatting.
  module NameFormatting

    # @return [String] the name in sort order
    def sort_order(delimiter = ', ')
      gp = [given, particle].compact.reject(&:empty?).join(' ')
      [family, suffix, gp].compact.reject(&:empty?).join(delimiter)
    end
  end
end

fname = 'data/test.txt'

carried_tags = {}
File.readlines(fname).each do |line|
  if line =~ /^\s*(#+)(.*)$/
    if line =~/^\s*#([a-zA-Z_]+)\s*:\s*(.*)$/
      k = $1
      v = $2
      carried_tags[k] = v  unless k=='Description'
    end
  elsif line =~ /^\s*$/
    #
  elsif line =~ /^\s*[a-zA-Z]/
    if line =~/^\s*(\b[^(]+)\(([^(]+)\)$/
      nm = Namae.parse($1)[0]
      sort_order_name = nm.sort_order
      dates = $2
      blob = carried_tags.clone
      blob["Name"] = sort_order_name
      blob["Dates"] = dates
      puts blob.to_yaml
    end
  end
end
