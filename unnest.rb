#!/usr/bin/env ruby

require "set"

def process fname
  cmds = SortedSet.new();
  base = nil
  File.readlines(fname).each do |line|
    ln = line.chomp;
    next unless ln =~ /\/Music\/Music\//
    src = ln
    tgt = src.sub("/Music/Music/","/Music/")
    base = src.sub(/\/Music\/Music\/.*$/,"/Music/Music/")
    path = tgt.split('/')
    path.pop
    cmds.add "mkdir -p \"#{path.join('/')}\""
    cmds.add "mv \"#{src}\" \"#{tgt}\""
  end
  cmds.each { |c| puts c }
  puts "find \"#{base}\" -type d -empty -delete"
  puts "rmdir \"#{base}\""
end

process ARGV[0]

