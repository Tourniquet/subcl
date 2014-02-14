
class Subcl
  attr_accessor :player, :api, :notifier

  def initialize(options = {})
    #default options
    @options = {
      :interactive => true,
      :tty => true,
      :insert => false,
      :out_stream => STDOUT,
      :err_stream => STDERR
    }

    #overwrite defaults with given options
    @options.merge! options

    @out = @options[:out_stream]
    @err = @options[:err_stream]

    begin
      @configs = Configs.new
    rescue => e
      @err.puts "Error initializing config"
      @err.puts e.message
      exit 4
    end

    @player = Mpc.new

    @notifier = Notify.new @configs[:notify_method]

    @display = {
      :song => proc { |song|
        @out.puts "#{song[:title]} by #{song[:artist]} on #{song[:album]} (#{song[:year]})"
      },
      :album => proc { |album|
        @out.puts "#{album[:name]} by #{album[:artist]} in #{album[:year]}"
      },
      :artist => proc { |artist|
        @out.puts "#{artist[:name]}"
      },
      :playlist => proc { |playlist|
        @out.puts "#{playlist[:name]} by #{playlist[:owner]}"
      },
    }

    @api = SubsonicAPI.new(@configs)
  end

  def albumart_url(size = nil)
    current = @player.current
    @out.puts @api.albumart_url(current, size) unless current.empty?
  end

  def queue(query, type, inArgs = {})
    args = {
      :clear => false, #whether to clear the playlist prior to adding songs
      :play => false, #whether to start the player after adding the songs
      :insert => false #whether to insert the songs after the current instead of the last one
    }
    args.merge! inArgs

    if @options[:current]
      unless [:album, :artist].include? type
        raise ArgumentError, "'current' option can only be used with albums or artists."
      end
      query = @player.current type
    end

    songs = case type
            when :song
              @api.song(query)
            when :album
              @api.album_songs(query)
            when :artist
              @api.artist_songs(query)
            when :playlist
              @api.playlist_songs(query)
            when :randomSong
              begin
                @api.random_songs(query)
              rescue ArgumentError
                raise ArgumentError, "random-songs takes an integer as argument"
              end
            end

    if songs.empty?
      no_matches
    end

    @player.clear if args[:clear]

    songs.shuffle! if @options[:shuffle]

    songs.each do |song|
      @player.add(song, args[:insert])
    end

    @player.play if args[:play]
  end

  def search_song(name)
    songs = @api.songs(name)
    if(songs.size == 0)
      no_matches("song")
    else
      songs.each do |song|
        @display[:song].call(song)
      end
    end
  end

  def search_album(name)
    albums = @api.albums(name)
    if(albums.size == 0)
      no_matches("album")
    else
      albums.each do |album|
        @display[:album].call(album)
      end
    end
  end

  def search_artist(name)
    artists = @api.artists(name)
    if(artists.size == 0)
      no_matches("artist")
    else
      artists.each do |artist|
        @display[:artist].call(artist)
      end
    end
  end

  #print an error that no matches were found, then exit with code 2
  def no_matches(what = nil)
    if what
      message = "No matching #{what}"
    else
      message = "No matches"
    end

    if @options[:tty]
      @err.puts message
    else
      @notifier.notify(message)
    end
    exit 2
  end

  def testNotify
    @notifier.notify("Hi!")
  end

  def albumlist
    @api.albumlist.each do |album|
      @display[:album].call(album)
    end
  end

  #show an interactive picker that lists every element of the array using &display_proc
  #The user can then choose one, many or no of the elements which will be returned as array
  def invoke_picker(array, &display_proc)
    return array if array.length <= 1
    return [array.first] unless @options[:interactive]
    return Picker.new(array).pick(&display_proc)
  end



end