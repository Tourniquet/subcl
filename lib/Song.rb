class Song < Hash
	def initialize(subsonic, attributes)
		@subsonic = subsonic
		self['type'] = 'song'
		attributes.each do |key, val|
			self[key] = val
		end
	end

	#returns the streaming url for a song
	def url
		@subsonic.songUrl(self['id'])
	end
end
