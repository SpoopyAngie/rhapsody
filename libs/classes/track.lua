local discordia = require('discordia')
local youtube = require('utils/youtube')
local spotify = require('utils/spotify')
local debug = function(...) print(string.format('(%s) Track:', os.date('%F %T')), ...) end

local Track = require('class')('Track')

function Track:__init(YTVideoID, Title) 
    self.__title = Title or 'undefined'
    self.__ytvideoid = YTVideoID
    self.__isready = false
end

function Track:__tostring() return string.format('Track: %s [%s]', self:getTitle(), self:getYTVideoID()) end

function Track:getTitle() return self.__title end

function Track:setTitle(Title) assert(type(Title) == 'string') self.__title = Title end

function Track:setUser(User) assert(User) self.__user = User end

function Track:getUser() return self.__user end

function Track:setVoiceChannel(VoiceChannel)
	assert(VoiceChannel)
	
	self.__voicechannel = VoiceChannel
end

function Track:getVoiceChannel() return self.__voicechannel end

function Track:getDuration() return self.__duration end

function Track:isReady() return self.__isready end

function Track:getYTVideoID() return self.__ytvideoid end

function Track:getAudioFilepath() return self.__audiofilepath end

function Track:downloadAudio(Callback)
    local YTVideoID = self:getYTVideoID()

    youtube.downloadAudio(YTVideoID, 
        function(Error, TrackAudioFilePath)
			if Error then
				if Callback then Callback(Error) end
			else
				self.__isready = true
				self.__audiofilepath = TrackAudioFilePath
				
				if Callback then Callback(Error, TrackAudioFilePath) end
			end
        end
    )
end

function Track:updateMetadata(TrackMetadata)
	if TrackMetadata['Title'] then self:setTitle(TrackMetadata['Title']) end
	if TrackMetadata['Duration'] then self.__duration = TrackMetadata['Duration'] end
end

function Track:retrieveMetadata(UpdateTrackMetadata)
	local YTVideoID = self:getYTVideoID()
	
	local Error, YTVideoMetadata = youtube.getYTVideoMetadata(YTVideoID)
	
	if Error then debug(string.format("Error code '%s' while querying metadata for '%s'", Error, YTVideoID)) return end
	
	if UpdateTrackMetadata then self:updateMetadata(YTVideoMetadata) end
	
	return YTVideoMetadata
end

function Track.fromSearchQuery(SearchQuery)
    local Error, YTVideoID = youtube.findVideoID(SearchQuery)

    if Error then debug(string.format("Error code '%s' while querying search '%s'", Error, SearchQuery)) return end

    return Track(YTVideoID, SearchQuery)
end

function Track.fromSpotify(SpotifyTrackID)
	local Error, SpotifyTrackTitle = spotify.getTrackName(SpotifyTrackID)
	
	if Error then debug(string.format("Error code '%s' while querying search 'Spotify Track ID: %s'", Error, SpotifyTrackID)) return end
	
	return Track.fromSearchQuery(SpotifyTrackTitle)
end

function Track.fromSpotifyPlaylist(SpotifyPlaylistID)
	local Error, SpotifyPlaylist = spotify.getPlaylist(SpotifyPlaylistID)
	
	if Error then debug(string.format("Error code '%s' while processing Spotify playlist '%s'", Error, SpotifyPlaylistID)) return end
	
	local TrackPlaylist = {
		Name = SpotifyPlaylist.Name,
		Tracks = {}
	}
	
	for _, TrackTitle in pairs(SpotifyPlaylist.Tracks) do
		local Track = Track.fromSearchQuery(TrackTitle)
		if Track then
			Track:retrieveMetadata()
			
			table.insert(TrackPlaylist.Tracks, #TrackPlaylist.Tracks + 1, Track)
		end
	end
	
	return TrackPlaylist
end

return Track