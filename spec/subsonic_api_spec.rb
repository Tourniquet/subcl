require 'spec_helper'

describe SubsonicAPI do
  def doc(file)
    prefix = 'spec/responses/'
    Document.new(open(prefix + file))
  end

  before :each do
    @default_configs = {
      :max_search_results => 100,
      :server => 'http://example.com',
      :username => 'username',
      :password => 'password',
      :proto_version => '1.9.0',
      :appname => 'subcl-spec'
    }

    @api = SubsonicAPI.new(@default_configs)
  end

  describe '#search' do
    it 'should return some songs with stream url' do
      @api.should_receive(:query).with('search3.view', anything()).and_return(doc('songs_search.xml'))
      re = @api.search('foo',:song) #the query result is mocked anyway
      re.length.should == 1
      url = re.first[:stream_url]
      url.to_s.should == 'http://username:password@example.com/rest/stream.view?id=11048&v=1.9.0&c=subcl-spec'
    end

    it 'should return some albums' do
      @api.should_receive(:query).with('search3.view', anything()).and_return(doc('album_search.xml'))
      re = @api.search('foo', :album)
      re.length.should == 2
      re.first[:id].should == '473'
      re[1][:id].should == '474'
    end

    it 'should return some artists' do
      @api.should_receive(:query).with('search3.view', anything()).and_return(doc('artist_search.xml'))
      re = @api.search('foo', :artist)
      re.length.should == 2
      re.first[:id].should == '38'
      re[1][:id].should == '39'
    end

    it 'should return anything that matches' do
      @api.should_receive(:query).with('search3.view', anything()).and_return(doc('any_search.xml'))
      re = @api.search('foo', :any)
      re.length.should == 3
      artist = re[0]
      artist[:type].should == :artist
      artist[:id].should == '45'
      album = re[1]
      album[:type].should == :album
      album[:id].should == '128'
      song = re[2]
      song[:type].should == :song
      song[:id].should == '1577'
    end
  end

  describe '#random_songs' do
    it 'should return some random songs with default count' do
      default_count = 10 #set in subsonicAPI
      @api.should_receive(:query) do |path, args|
        path.should == 'getRandomSongs.view'
        p args
        args[:size].should == default_count
      end.and_return(doc('random.xml'))
      re = @api.random_songs
      re.length.should == default_count
    end

    it 'should return some random songs with explicit count' do
      count = 15
      api = SubsonicAPI.new(@default_configs.merge({:random_song_count => count}))
      api.should_receive(:query) do |path, args|
        path.should == 'getRandomSongs.view'
        args[:size].should == count
      end.and_return(doc('random-15.xml'))
      re = api.random_songs(count)
      re.length.should == count
    end
  end
end
