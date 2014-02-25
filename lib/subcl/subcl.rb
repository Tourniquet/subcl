
class Subcl
  attr_accessor :player, :api, :notifier

  def initialize(options = {})
    #TODO merge options and configs
    @options = {
      :interactive => true,
      :tty => true,
      :insert => false,
      :out_stream => STDOUT,
      :err_stream => STDERR
    }.merge! options

    @out = @options[:out_stream]
    @err = @options[:err_stream]

    begin
      @configs = Configs.new
    rescue => e
      @err.puts "Error initializing config"
      @err.puts e.message
      exit 4
    end

    @configs[:random_song_count] = @options[:random_song_count] if @options[:random_song_count]

    @player = @options[:mock_player] || Player.new

    @api = @options[:mock_api] || SubsonicAPI.new(@configs)

    @notifier = Notify.new @configs[:notify_method]

    @display = {
      :song => proc { |song|
        @out.puts sprintf "%-20.20s %-20.20s %-20.20s %-4.4s", song[:title], song[:artist], song[:album], song[:year]
      },
      :album => proc { |album|
        @out.puts sprintf "%-30.30s %-30.30s %-4.4s", album[:name], album[:artist], album[:year]
      },
      :artist => proc { |artist|
        @out.puts "#{artist[:name]}"
      },
      :playlist => proc { |playlist|
        @out.puts "#{playlist[:name]} by #{playlist[:owner]}"
      },
    }

  end

  def albumart_url(size = nil)
    current = @player.current_song
    @api.albumart_url(current.file, size) if current
  end

  def queue(query, type, inArgs = {})
    args = {
      :clear => false, #whether to clear the playlist prior to adding songs
      :play => false, #whether to start the player after adding the songs
      :insert => false #whether to insert the songs after the current instead of the last one
    }
    args.merge! inArgs

    if @options[:current]
      query = case type
              when :album
                @player.current_song.album
              when :artist
                @player.current_song.artist
              else
                raise ArgumentError, "'current' option can only be used with albums or artists."
              end
    end

    songs = case type
            when :randomSong
              begin
                count = query.empty? ? @configs[:random_song_count] : query
                @api.random_songs(count)
              rescue ArgumentError
                raise ArgumentError, "random-songs takes an integer as argument"
              end
            else #song, album, artist, playlist
              entities = @api.search(query, type)
              entities = invoke_picker(entities, &@display[type])
              @api.get_songs(entities)
            end

    no_matches if songs.empty?

    @player.clearstop if args[:clear]

    songs.shuffle! if @options[:shuffle]

    songs.each do |song|
      @player.add(song, args[:insert])
    end

    @player.play if args[:play]
  end

  def print(name, type)
    entities = @api.search(name, type)
    no_matches(type) if entities.empty?
    entities.each do |entity|
      @display[type].call(entity)
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

  PLAYER_METHODS = %i{play pause toggle stop next previous rewind}
  def method_missing(name, args)
    raise NoMethodError unless PLAYER_METHODS.include? name
    @player.send(name)
  end

end
