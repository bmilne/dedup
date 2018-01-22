#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

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

def parenthetical_with a
  Regexp.new( '[\(\[][^)\]]*(' + a.join('|') + ')[^)\]]*[)\]]', 'i')
end

def underscore_infer(s, is_track=false)
  s = s.gsub(160.chr('UTF-8'), ' ')  # replace &nbsp; with space

  s = s.gsub(8226.chr('UTF-8'), '-')  # replace &bullet; with dash

  s = s.gsub(parenthetical_with(%w(Soundtrack Movie Motion)), '(Soundtrack)') # (Original Motion Picture Soundtrack) --> (Soundtrack)
  
  s = s.gsub(parenthetical_with(%w(Live)), '(Live)') unless is_track
  s = s.gsub(parenthetical_with(%w(Bonus Deluxe Remastered Special Edition Version)), '') unless is_track # strip (Special Version) etc.

  s = s.gsub(parenthetical_with(%w(The Voice)), '- The Voice -') # (The Voice Performance) etc.

  s = s.gsub(/\b_(\B[^_]*(\B|[!.]))_(\b|_)/, '\1\3')  # strip underscores surrounding word or phrase (e.g. _Jupiter_ ; _The Planets_)
  s = s.gsub('I_II', 'I&II')
  s = s.gsub(/\B_(d|m|s|t|re)\b/i, '\'\1')  # replace underscores placeholding contractions (e.g. I_m --> I'm)
  s = s.gsub(/(cryin)_\b/i, '\1\'')  # replace underscores placeholding contractions (e.g. cryin_ --> cryin')
  s = s.gsub(/\bl_\B/i, 'l\'')  # replace underscores placeholding l'...
  s = s.gsub(/\bd_\B/i, 'l\'')  # replace underscores placeholding d'...
  s = s.gsub(/([0-9])_([0-9])/, '\1:\2')  # replace underscores between numerals with : (e.g. 3_11 --> 3:11)
  s = s.sub(/_+\s*$/, '')  # strip trailing underscores
  s = s.sub(/^\s*_+/, '')  # strip leading underscores
  s = s.gsub(/^(([0-9]-)?[0-9]+\s*)_+/, '\1 ')  # strip leading underscores, accounting for track numbering scheme
  s = s.gsub(/([,;.!\)\]\(\[]\s*)_+(\s*)/, '\1\2')  # strip leading underscores within phrases and parentheticals
  s = s.gsub(/_+\s*([,;.!\)\]\(\[])/, '\1')  # strip trailing underscores within phrases and parentheticals

  s = s.gsub(/\B\s?_\s+\b/, ' - ')  # turn word-follwing underscores into dashes, e.g. Bach_ Blah --> Bach - Blah
  s = s.gsub(/(__+)/) {|m| '*'*m.length } # turn repeated underscores into repeated asterisks e.g. f__k --> f**k

  s = s.gsub(/_([0-9])/,'-\1')  # replace underscores preceeding numerals with dashes, e.g. IIb_7 --> IIb-7

  s = s.gsub(/_+/, ' - ')  # turn any onther underscores into space-padded dashes

  s = s.gsub(/-\s*-[\-\s]*/, ' - ')  # collapse multiple dashes (and any whitespce) to single dash
  s = s.gsub(/-\s*$/, '')  # strip trailing dashes

  s = s.gsub(/\s+/, ' ')  # collapse whitespace

  return s
end

def xx s
  s2 = underscore_infer s
  if s != s2
    special_chars = (s.each_char.map {|c| c.ord}).select {|ord| ord<32 || ord>128}
    puts s
    puts ("  special chars: " + special_chars.to_s) if special_chars.length>0
    puts ("  " + s2)

  end
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

  def qual_album
    (@path).join("/")
  end  

  def abs_path
    ([$base_dir] + @path + [fname]).join("/")
  end 

  def qual_track
    (@path + [track]).join("/")
  end

  def chg_album tgt
    Song.new [artist, tgt, fname]
  end

  def chg_artist tgt
    Song.new [tgt, album, fname]
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
    @artist_names = SortedSet.new
    @album_names = SortedSet.new
    @extensions = SortedSet.new
  end
  # Expected file types (extensions) in library.. Audio types:
  # m4a: Lossless - ALAC
  # m4b: Audio Books: m4a + indexing
  # m4p: Apple Lossy w/ DRM Playback Protection - iTunes only
  # mp3: Lossy
  # mp4: Lossy - AAC
  # Non audio types:
  # m4v: Video (Apple format) # these get cleaned up / removed
  # mov: Video # these get cleaned up / removed
  # pdf: documents

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

    @artist_names.add s.artist
    @album_names.add s.album
    @extensions.add s.ext
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

  # As a prelude to the combine_sets command below, remove any 1-xx track prefixing from non-box-set disks
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


  def cleanup_track_names
    @songs.each do |s| 
      tgt = underscore_infer(s.track, true)
      if (tgt != s.track)
        qtgt = "#{s.qual_album}/#{tgt}.#{s.ext}"
        puts "mv #{qt(s.qual_fname)} #{qt(qtgt)}"
      end
    end
  end

  def cleanup_album_names
    cmds = SortedSet.new
    @songs.each do |s| 
      tgt = underscore_infer s.album
      if (tgt != s.album)
        qtgt = "#{s.artist}/#{tgt}/#{s.fname}"
        x = matches qtgt
        exists = false
        x.each do |s2|   
          exists = true  if s.ext == s2.ext
          # p qtgt
          # puts "exists"
          # p s2
        end
        if exists
          cmds.add "rm #{qt(s.qual_fname)}"
        else
          cmds.add "mkdir -p  #{qt(s.artist+'/'+tgt)}"
          cmds.add "mv #{qt(s.qual_fname)} #{qt(qtgt)}"
        end
      end
    end
    cmds.each {|a| puts a}
  end

  def cleanup_artist_names
    rename_artists = {
      'Bach_PierreFournier' => 'Bach: Pierre Fournier',
      'Billy Bragg and Wilco' => 'Billy Bragg & Wilco',
      'Blake Shelton & Dia Frampton' => 'Dia Frampton',
      'Daria Hovora, Mischa Maisky & Orpheus Chamber Orchestra' => 'Orpheus Chamber Orchestra',
      'Dennis Keene_ Voices Of Ascension' => 'Voices Of Ascension',
      'Emma Kirkby; Christopher Page_ Gothic Voices' => 'Gothic Voices',
      'Eyck, Jakob van (1590-1657)' => 'Jakob van Eyck',
      'Fritz Reiner_ Chicago Symphony Orchestra' => 'Fritz Reiner_ Chicago Symphony Orchestra',
      'Gustavo Dudamel_ Simón Bolívar Youth Orchestra of Venezuela' => 'Dudamel, Youth Orchestra of Venezuela',
      'Iron and Wine' => 'Iron & Wine',
      'Israel Kamakawiwo`ole' => 'Israel Kamakawiwo\'ole',
      'Jennifer S. Paul, Harpsichord' => 'Jennifer S. Paul',
      'Jeremy Summerly_ Oxford Camerata' => 'Oxford Camerata',
      'Joshua Rifkin_ The Bach Ensemble' => 'The Bach Ensemble',
      'Karl Dent; Robert Shaw_ Robert Shaw Festival Singers' => 'Robert Shaw Festival Singers',
      'Katia & Marielle Labeque' => 'Katia & Marielle Labèque',
      'Klaus Tennstedt_ Berlin Philharmonic Orchestra' => 'Berlin Philharmonic Orchestra',
      'Le Poème Harmonique _ Vincent Dumestre' => 'Le Poème Harmonique',
      'Marcel Pérès_ Ensemble Organum' => 'Ensemble Organum',
      'Monteverdi Choir, English Baroque Soloists, John Eliot Gardiner & Various Artists' =>
        'Monteverdi Choir, English Baroque Soloists',
      'Neville Marriner_ Academy Of St. Martin In The Fields' => 'Academy Of St. Martin In The Fields',
      'Peter Hurford; Charles Dutoit_ Montreal Symphony Orchestra' => 'Montreal Symphony Orchestra',
      'Peter Phillips_ The Tallis Scholars' => 'Tallis Scholars',
      'Philippe Herreweghe_ Ensemble Vocal Européen De La Chapelle Royale' => 'Ensemble Vocal Européen',
      'Philippe Herreweghe_ Ensemble Vocal Européen, Ensemble Organum' => 'Ensemble Vocal Européen',
      'Robin Johannsen, Mari Eriksmoen, Etc.; René Jacobs_ Akademie Für Alte Musik Berlin, RIAS Chamber Choir' =>
        'Robin Johannsen, Mari Eriksmoen',
      'Sawyer' => 'Sawyer Fredericks',
      'Stefano Sabene, Dir_ Schola Romana Ensemble, Orig. Instrts' => 'Schola Romana Ensemble',
      'Vincent Dumestre_ Le Poème Harmonique' => 'Le Poème Harmonique',
    }

    truncate_artists_at = [
                           'Academy Award Winners, The Pacific _Pops_ Orchestra',
                           'Alban Berg Quartet',
                           'Alison Krauss',
                           'Beau Jocque',
                           'Ben Harper',
                           'Berliner Philharmoniker',
                           'Callas',
                           'Cecilia Bartoli',
                           'Chip Taylor',
                           'Choeur des moines de l\'Abbaye Saint-Pierre de Solesmes',
                           'David Murray',
                           'Gabrieli Consort',
                           'Giovanni Pierluigi da Palestrina',
                           'Glenn Gould',
                           'Itzhak Perlman',
                           'Jan Garbarek',
                           'Jason Isbell',
                           'Jenny Lewis',
                           'Joseph Curiale',
                           'Kelly Hogan',
                           'Lloyd Cole',
                           'Louis Armstrong',
                           'Luciano Pavarotti, Cecilia Bartoli',
                           'Ludwig van Beethoven',
                           'Miley Cyrus',
                           'Mstislav Rostropovich',
                           'Neko Case',
                           'Orlando Consort',
                           'Peter Malick Group',
                           'Prince',
                           'Sawyer Fredericks',
                           'Steve Earle',
                           'Ted Leo',
                           'Tom Petty',
                           'Various Artists',
                           'Yo-Yo Ma',
                           'k.d. lang',
                          ]

    cmds = SortedSet.new
    @artist_names.each do |n| 
      tgt = nil;
      if (n=~ /^The /)
        tgt = n.sub(/^The /,'')
      elsif rename_artists[n]!=nil
        tgt = rename_artists[n]
      end
      if tgt.nil?
        truncate_artists_at.each do |a|
          if n.length>a.length && n.start_with?(a)
            tgt = a
          end
        end
      end
      if tgt.nil?
        n2 = underscore_infer n
        tgt = n2 if n2!=n
      else
        tgt = underscore_infer tgt
      end
      unless tgt.nil?
        x = matches n
        x.each do |s|
          s2 = s.chg_artist(tgt)

          x2 = matches s2.qual_track
          exists = false
          x2.each do |s3| 
            exists = true  if s.ext == s3.ext
          end
          if exists
            cmds.add "rm #{qt(s2.qual_fname)}"
          else
            cmds.add "mkdir -p  #{qt(s2.qual_album)}"
            cmds.add "mv #{qt(s.qual_fname)} #{qt(s2.qual_fname)}"
          end
        end
      end
    end
    cmds.each {|a| puts a}
  end

  def cleanup_naming
    prev = ''
    @album_names.each do |n| 
      note = ''
      note = '** ' if prev[0...8]==n[0...8]
      puts "#{note}#{n}"
      prev = n
    end
    exit


    # 1. rename tracks (Note - sequence matters... do this before moving albums, artists)
    # HMM... no, these need to be done in passes over the library and re-inits...

    @songs.each do |s| 
      tgt = underscore_infer s.track
      if tgt != s.track
        cmds.add "mv #{qt(s.qual_fname)} #{qt(s.qual_album + '/' + tgt + '.' + s.extension)}"
        puts 
      end
    end

    # 2. rename albums

    # 3. rename artists
    
    prev = ''
    @artist_names.each do |n| 
      note = ''
      note = '** ' if prev[0...9]==n[0...9]
      note = '** ' if n =~ /(&|\band\b)/i
      puts "#{note}#{n}"
      prev = n
    end
    exit
    @artist_names.each {|n| xx n}
    @album_names.each {|n| xx n}
    @songs.each {|s| xx s.track}
    # @extensions.each {|n| puts n}
    @songs.each do |s| 
    end
  end

  # move any mp3's that are encoded as lossless (m4a) to a parallel dir, ../MP3/
  # and move any m4p's (regardless of whether matched) to ../M4P/ 
  def handle_mp3s
    cmds = SortedSet.new

    @songs.each do |s| 
      if s.ext == 'mp3'
        alac = s.qual_track.sub(/ [1-9]$/,'') + '.m4a'
        if contains? alac 
          cmds.add "mkdir -p  #{qt('../MP3/'+s.qual_album)}"
          cmds.add "mv #{qt(s.qual_fname)} #{qt('../MP3/'+s.qual_fname)}"
        end
      elsif s.ext == 'm4p'
        cmds.add "mkdir -p  #{qt('../M4P/'+s.qual_album)}"
        cmds.add "mv #{qt(s.qual_fname)} #{qt('../M4P/'+s.qual_fname)}"
      end
    end
    cmds.each {|a| puts a}
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

  $base_dir = common

  # lib = @data.map { |p| Song.new(p) }
  lib = Library.new
  @data.each { |p| lib.add Song.new(p) }

  # depths = [0, 0, 0, 0, 0]
  # lib.each { |s| puts s.qual_fname if depths[s.depth]==0; depths[s.depth]+=1 }
  # p depths

  # puts "base_dir = #{$base_dir.join('/')}"
  # p lib.matches('10,000 Maniacs/In My Tribe')

  return lib
end

def process source_list
  library = load_data source_list
  puts "cd #{$base_dir.join('/')}"
  # library.handle_copies
  # library.cleanup_numbering
  # library.combine_sets
  # library.cleanup_track_names
  # library.cleanup_album_names
  # library.cleanup_artist_names
  library.handle_mp3s
end

process ARGV[0]

