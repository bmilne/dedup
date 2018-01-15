#!/usr/bin/env ruby

require "set"

def file_and_ext f
 # note, some track names contain dots
  t = f.split('.')
  ext = t.pop if t.length>1
  fname = t.join('.')
  return [fname, ext]
end

def qt s
  "'" + s.gsub("'","'\\\\''") + "'"
end

class Song
  attr_accessor :track
  attr_accessor :ext

  def initialize(path)  
    @track, @ext = file_and_ext path.pop
    @path = path
  end  
  
  def artist
    @path[0]
  end
  def artist=(a)
    @path[0]=a
  end

  def album
    @path[1]
  end
  def album=(a)
    @path[1]=a
  end

  def fname
    [@track, @ext].join(".")
  end

  def qual_fname
    (@path + [fname]).join("/")
  end  

  def abs_path
    ([@@base_dir] + @path + [fname]).join("/")
  end 

  def qual_track
    (@path + [track]).join("/")
  end

  def <=> (other)
    qual_fname <=> @other.qual_fname
  end

  def depth
    @path.length
  end
end  

class Library
  include Enumerable
  def initialize
    @songs = []
    @artist_hash = {}
    @album_hash = {}
    @track_hash = {}
  end
  def add s
    index = @songs.length
    @songs.push(s)

    key = s.artist
    @artist_hash[key] ||= []
    @artist_hash[key].push index

    key = [s.artist, s.album].join('/')
    @album_hash[key] ||= []
    @album_hash[key].push index

    key = [s.artist, s.album, s.track].join('/')
    @track_hash[key] ||= []
    @track_hash[key].push index
  end

  def matches p
    comp = p.split('/')
    f, ext = file_and_ext comp.last
    m = case comp.length
          when 1 then @artist_hash[p]
          when 2 then @album_hash[p]
          when 3 then @track_hash[ [comp[0], comp[1], f].join('/') ]
          else nil
    end
    return [] if m.nil?
    sm = m.map { | i | @songs[i] }
    return  sm if ext.nil?
    return sm.select { | s | s.ext==ext }
  end

  def contains? p
    matches(p).length>0
  end

  def each
    @songs.each { |s| yield s; }
  end

  def size
    @songs.length
  end

  def handle_copies
    @songs.each do |s| 
      if s.track =~ / [1-9]$/
        base = s.qual_track.sub(/ [1-9]$/,'') + '.' + s.ext
        if contains? base 
          puts "rm #{qt(s.qual_fname)}"
        end
      end
    end
  end

  def cleanup_numbering
    @songs.each do |s| 
      next if s.album =~ /Disc/
      if s.track =~ /^1-/
        tgt = s.qual_fname.sub('/1-','/')
        abort if tgt =~ /\/1-/
        if contains? tgt
          puts "rm #{qt(s.qual_fname)}"
        else
          puts "mv #{qt(s.qual_fname)} #{qt(tgt)}"
        end
      end
    end
  end

  # Search for multi-disc sets and combine into shared album directory
  def combine_sets

    md_set_regex = /[,_]?\s?[\[\(]?Disc\s+([1-9])[\]\)]?/
    md_set_latin_regex = /\s[\[\(](I+)[\]\)]/     # [I] [II]
    bd_regex = / \[Bonus Disc\]$/

    cmds = SortedSet.new();
    
    @songs.each do |s| 
      tgt = nil
      track_tgt = nil
      if s.album =~ md_set_regex
        tgt = s.album.sub(md_set_regex,'')
        id = md_set_regex.match(s.album)[1]
      elsif s.album =~ md_set_latin_regex
        tgt = s.album.sub(md_set_latin_regex,'')
        id = md_set_latin_regex.match(s.album)[1].length.to_s
      elsif s.album =~ bd_regex  #  23rs Street Lullaby [Bonus Disc]
        tgt = s.album.sub(bd_regex,'')
        id = 'Bonus'
      end
      unless tgt.nil?
        # check track numbering against Disk Number from Album
        m = /^([a-z0-9]+)-([0-9]+.*)$/.match(s.track)
        if m
          if m[1] != id
            track_tgt = "#{id}-#{m[2]}"
          else
            track_tgt = nil
          end
        else
          track_tgt = "#{id}-#{s.track}"
        end

        track_tgt ||= s.track
        qtgt = "#{s.artist}/#{tgt}/#{track_tgt}.#{s.ext}"
        cmds.add "mkdir -p  #{qt(s.artist+'/'+tgt)}"
        cmds.add "mv #{qt(s.qual_fname)} #{qt(qtgt)}"
      end
    end
    cmds.each {|a| puts a}
  end

  def handle_mp3s
    @songs.each do |s| 
      if s.ext == 'mp3'
        alac = s.qual_track.sub(/ [1-9]$/,'') + '.m4a'
        unless contains? alac 
          puts "mv #{qt(s.qual_fname)} #{qt('../MP3/'+s.qual_fname)}"
          exit 0
        end
      end
    end
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

  @@base_dir = common

  # lib = @data.map { |p| Song.new(p) }
  lib = Library.new
  @data.each { |p| lib.add Song.new(p) }

  # depths = [0, 0, 0, 0, 0]
  # lib.each { |s| puts s.qual_fname if depths[s.depth]==0; depths[s.depth]+=1 }
  # p depths

  # puts "base_dir = #{@@base_dir.join('/')}"
  # p lib.matches('10,000 Maniacs/In My Tribe')

  return lib
end

def process source_list
  library = load_data source_list
  puts "cd #{@@base_dir.join('/')}"
  # library.handle_copies
  # library.cleanup_numbering
  library.combine_sets
  # library.handle_mp3s
end

process ARGV[0]

