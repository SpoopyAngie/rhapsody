local discordia = require('discordia')
local url = require('url')
local track = require('classes/track')
local queue = require('classes/queue')
local youtube = require('utils/youtube')
local spotify = require('utils/spotify')
local ini = require('ini')
local debug = function(...) print(string.format('(%s) Music Player 2:', os.date('%F %T')), ...) end

discordia.extensions()

local musicplayer = {
	Client = discordia.Client(),
	CommandPrefix = '!',
	
	Commands = {}
}

musicplayer.findAvailableVoiceChannel = function(Message)
	for _, Guild in pairs(Message.author.mutualGuilds) do
		for _, VoiceChannel in pairs(Guild.voiceChannels) do
			for _, User in pairs(VoiceChannel.connectedMembers) do
				if User.id == Message.author.id then return VoiceChannel end
			end
		end
	end
end

musicplayer.queueTrack = function(Message, Track, Reply)
	assert(Message) assert(Track)
	
	Track:setUser(Message.author)
	Track:retrieveMetadata(true)
	
	local VoiceChannel = musicplayer.findAvailableVoiceChannel(Message)
	
	if VoiceChannel then
		Track:setVoiceChannel(VoiceChannel)
		
		local Queue = queue.getGuildQueue(VoiceChannel.guild)
		local TrackQueuePlace = Queue:queueTrack(Track)
		
		if Queue:getStatus() == queue.Enumeration.Idle then Queue() end
		
		if Reply then
			Message:reply {
				content = string.format('>>> `#%02d`: \'__%s__\'', TrackQueuePlace, Track:getTitle()),
				
				reference = {
					message = Message,
					mention = false
				}
			}
		end
		
		return TrackQueuePlace
	end
end

musicplayer.queueTrackPlaylist = function(Message, TrackPlaylist, Reply)
	assert(Message) assert(TrackPlaylist)

	if TrackPlaylist then
		local MessageReplyContent = '>>> '
		
		MessageReplyContent = MessageReplyContent .. string.format('`Playlist`: \'%s\' (%s entries):', TrackPlaylist.Name, #TrackPlaylist.Tracks)
		
		local MessageReplyLimit = false
		
		for TrackIndex, Track in pairs(TrackPlaylist.Tracks) do
			local TrackQueuePlace = musicplayer.queueTrack(Message, Track, false)
			
			if TrackQueuePlace then
				local TrackMessageReplyContent = string.format('\n	`#%02d`: \'__%s__\'', TrackQueuePlace, Track:getTitle())
				
				if (#MessageReplyContent + #TrackMessageReplyContent) < 1995 then
					MessageReplyContent = MessageReplyContent .. TrackMessageReplyContent
				else
					MessageReplyLimit = true
				end
			end
		end
		
		if MessageReplyLimit then MessageReplyContent = MessageReplyContent .. '\n...' end
		
		if Reply then
			Message:reply {
				content = MessageReplyContent,
				reference = {
					message = Message,
					mention = false
				}
			}
		end
	end
end

musicplayer.Commands.skip = function(Message, ...)
	assert(Message)
	
	local VoiceChannel = musicplayer.findAvailableVoiceChannel(Message)
	
	if VoiceChannel then
		local Queue = queue.getGuildQueue(VoiceChannel.guild)
		local Track, VoiceChannel, VoiceChannelConnection = Queue:getPlayingTrack()
		
		if Track and VoiceChannelConnection then
			Message:reply {
				content = string.format('>>> `Skipping` \'__%s__\' requested by <@%s>', Track:getTitle(), Track:getUser().id),
				
				reference = {
					message = Message,
					mention = false
				}
			}
			
			VoiceChannelConnection:stopStream()
		else
			Message:reply {
				content = string.format('>>> There\'s nothing to `Skip`'),
				
				reference = {
					message = Message,
					mention = false
				}
			}
		end
	end
end

musicplayer.Commands.queue = function(Message, ...)
	assert(Message)
	
	local VoiceChannel = musicplayer.findAvailableVoiceChannel(Message)
	
	if VoiceChannel then
		local Queue = queue.getGuildQueue(VoiceChannel.guild)
		local QueueTrackList = Queue:getTrackPlaylist()
		
		if #QueueTrackList > 0 then
			local MessageReplyContent = '>>> '
			
			MessageReplyContent = MessageReplyContent .. string.format('`Queue` (%s entries):', #QueueTrackList)
			
			local MessageReplyLimit = false
			
			for TrackIndex, Track in pairs(QueueTrackList) do
				local TrackMessageReplyContent = string.format('\n	`#%02d`: \'__%s__\' requested by <@%s>', TrackIndex, Track:getTitle(), Track:getUser().id)
				
				if (#MessageReplyContent + #TrackMessageReplyContent) < 1995 then
					MessageReplyContent = MessageReplyContent .. TrackMessageReplyContent
				else
					MessageReplyLimit = true
				end
			end
			
			if MessageReplyLimit then MessageReplyContent = MessageReplyContent .. '\n...' end
			
			Message:reply {
				content = MessageReplyContent,
				reference = {
					message = Message,
					mention = false
				}
			}
		else
			Message:reply {
				content = '>>> `Queue` is empty',
				reference = {
					message = Message,
					mention = false
				}
			}
		end
	end
end

musicplayer.Commands.playsomething = function(Message, ...)
	assert(Message)
	
	local VoiceChannel = musicplayer.findAvailableVoiceChannel(Message)
	local Arguments = {...}
	
	if VoiceChannel then
		local NumberOfTracks = #Arguments and tonumber(Arguments[1]) or 1
		
		for Index = 1, math.min(NumberOfTracks, 10) do
			local CacheYTVideoIDs = table.keys(youtube.AudioCache)
			
			local Track = track(CacheYTVideoIDs[math.random(1, #CacheYTVideoIDs)])
			
			if Track then musicplayer.queueTrack(Message, Track, true) end
		end
	end
end

musicplayer.Commands.clear = function(Message, ...)
	assert(Message)
	
	local VoiceChannel = musicplayer.findAvailableVoiceChannel(Message)
	
	if VoiceChannel then
		local Queue = queue.getGuildQueue(VoiceChannel.guild)
		local QueueTrackList = Queue:getTrackPlaylist()
		
		if #QueueTrackList > 0 then
			for Index = 1, #QueueTrackList do table.remove(QueueTrackList, 1) end
			
			Message:reply {
				content = '>>> `Queue` is now empty',
				reference = {
					message = Message,
					mention = false
				}
			}
		end
	end
end

musicplayer.Commands.fs = musicplayer.Commands.skip
musicplayer.Commands.random = musicplayer.Commands.playsomething
musicplayer.Commands.q = musicplayer.Commands.queue

musicplayer.Client:on(
	'messageCreate',
	function(Message)
		assert(Message)
		
		if Message.channel.type ~= 1 then return end
		if Message.author.bot then return end
		
		if string.sub(Message.content, 1, 8) == 'https://' then
			local URLParsed = url.parse(Message.content)
			
			if URLParsed.hostname == 'www.youtube.com' then
				if URLParsed.pathname == '/watch' then
					local YTVideoID = string.sub(URLParsed.query, 3, 13)
					
					local Track = track(YTVideoID)
					
					if Track then musicplayer.queueTrack(Message, Track, true) end
				elseif URLParsed.pathname == '/playlist' then
					local YTPlaylistID = string.sub(URLParsed.query, 6, 40)
					
					-- TO-DO
					debug('YTPlaylistID', YTPlaylistID)
				end
			elseif URLParsed.hostname == 'open.spotify.com' then
				if string.sub(URLParsed.pathname, 1, 7) == '/track/' then
					local SpotifyTrackID = string.sub(URLParsed.pathname, 8, #URLParsed.pathname)
					
					local Track = track.fromSpotify(SpotifyTrackID)
					
					if Track then musicplayer.queueTrack(Message, Track, true) end
				elseif string.sub(URLParsed.pathname, 1, 7) == '/album/' then
					local SpotifyAlbumID = string.sub(URLParsed.pathname, 8, #URLParsed.pathname)
					
					-- TO-DO
					debug('SpotifyAlbumID', SpotifyAlbumID)
				elseif string.sub(URLParsed.pathname, 1, 10) == '/playlist/' then
					local SpotifyPlaylistID = string.sub(URLParsed.pathname, 11, #URLParsed.pathname)
					local TrackPlaylist = track.fromSpotifyPlaylist(SpotifyPlaylistID)
					
					if TrackPlaylist then musicplayer.queueTrackPlaylist(Message, TrackPlaylist, true) end
				end
			end
		elseif string.sub(Message.content, 1, #musicplayer.CommandPrefix) == musicplayer.CommandPrefix then
			local Arguments = string.split(string.sub(Message.content, #musicplayer.CommandPrefix + 1, #Message.content), ' ')
			local Command = table.remove(Arguments, 1)
			
			if musicplayer.Commands[Command] then musicplayer.Commands[Command](Message, table.unpack(Arguments)) end
		else
			local Track = track.fromSearchQuery(Message.content)
			
			if Track then musicplayer.queueTrack(Message, Track, true) end
		end
	end
)

local config = ini.parse_file('./config.ini')

if config then
	if config.Discord and config.YouTube and config.Spotify then
		youtube.setAPIKey(config.YouTube.APIKey)
		spotify.setClientID(config.Spotify.ClientID)
		spotify.setClientSecret(config.Spotify.ClientSecret)

		musicplayer.Client:run(string.format('Bot %s', config.Discord.BotToken))
	end
end