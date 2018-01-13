#!/usr/bin/env ruby

class Song
  def initialize(path)  
    t = path.pop.split('.')
    @ext = t.pop if t.length>0
    @tract = t.join('.') # note, some track names contain dots
    @path = path
  end  
  
  def fname
    [@tract, @ext].join(".")
  end

  def rel_fname
    (@path + [fname]).join("/")
  end  

  def depth
    @path.length
  end
end  

def load_data fname
  @data = []
  File.readlines(fname).each do |line|
    components = line.chomp.split('/')
    @data.push(components)
  end

  common = nil
  @data.each do |p|
    common = p if common == nil 
    common = common[0,p.size].take_while.with_index { |e,i| e == p[i] }
  end
  @data = @data.map { |p| p.drop(common.length) }

  @base_dir = common

  @songs = @data.map { |p| Song.new(p) }
  p @songs[0]

  depths = [0, 0, 0, 0, 0]
  @songs.each { |s| puts s.rel_fname if depths[s.depth]==0; depths[s.depth]+=1 }
  p depths

  puts "base_dir = #{@base_dir.join('/')}"
  puts @songs[128].rel_fname
  puts @songs.length
end

def process source_list
  load_data source_list
end

process ARGV[0]

