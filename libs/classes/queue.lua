local discordia = require('discordia')
local track = require('classes/track')
local uv = require('uv')
local debug = function(...) print(string.format('(%s) Queue:', os.date('%F %T')), ...) end

local QueueTable = {}

local Queue = require('class')('Queue')

function Queue:__init(Guild)
	assert(Guild)
	
	QueueTable[Guild.id] = self
	
	self.__guild = Guild
	self.__trackqueue = {}
	
	self.__status = 0
	-- self.__playing = nil
end

Queue.Enumeration = {
	Idle = 0,
	Playing = 1,
	Downloading = 2,
	Ready = 3
}

function Queue:setStatus(Status)
	assert(Status)
	
	self.__status = Status
end

function Queue:getStatus() return self.__status end

function Queue:__call(Status)
	local Status = Status or self:getStatus()
	self:setStatus(Status)
	
	-- debug(string.format('%s\'s queue status: %s', self:getGuild().name, self:getStatus()))
	
	local Track = self:nextTrack(false)
	
	if Status == Queue.Enumeration.Idle and Track then
		if Track:isReady() then
			self(Queue.Enumeration.Ready)
		else
			self:setStatus(Queue.Enumeration.Downloading)
			
			Track:downloadAudio(
				function(Error, TrackAudioFilePath)
					if Error then
						local Track = self:nextTrack(true)
						debug(string.format('Error while downloading audio for \'%s\'. Skipping ...', Track:getTitle()))
						
						self(Queue.Enumeration.Idle)
					else
						self(Queue.Enumeration.Ready)
					end	
				end
			)
		end
	elseif Status == Queue.Enumeration.Downloading then
		-- debug('Downloading ...')
	elseif Status == Queue.Enumeration.Ready then
		local Track = self:nextTrack(false)
		local VoiceChannel = Track:getVoiceChannel()
		
		debug(string.format('Playing now \'%s\' in \'%s\' requested by \'%s\'', Track:getTitle(), VoiceChannel.name, Track:getUser().name))
		
		self(Queue.Enumeration.Playing)
	elseif Status == Queue.Enumeration.Playing then
		local Track = self:nextTrack(true)
		local VoiceChannel = Track:getVoiceChannel()
		
		coroutine.wrap(
			function()
				local VoiceChannelConnection = VoiceChannel:join()
				
				if VoiceChannelConnection then
					self.__playing = {Track, VoiceChannel, VoiceChannelConnection}
					
					VoiceChannelConnection:setComplexity(10)
					VoiceChannelConnection:setBitrate(128000)

					VoiceChannelConnection:playFFmpeg(Track:getAudioFilepath())
					VoiceChannelConnection:stopStream()
					
					uv.new_timer():start(5000, 0,
						function(...)
							if self:getStatus() == Queue.Enumeration.Idle then
								coroutine.wrap( function() VoiceChannelConnection:close() end )()
							end
						end
					)
				end
				
				self(Queue.Enumeration.Idle)
			end
		)()
	end
end

function Queue:__tostring() return string.format('Queue: %s', self:getGuild().id) end

Queue.getGuildQueue = function(Guild)
	assert(Guild)
	
	return QueueTable[Guild.id] and QueueTable[Guild.id] or Queue(Guild)
end

function Queue:getGuild() return self.__guild end

function Queue:getTrackPlaylist() return self.__trackqueue end

function Queue:queueTrack(Track)
	assert(Track)
	
	local TrackQueue = self:getTrackPlaylist()
	table.insert(TrackQueue, #TrackQueue + 1, Track)
	
	return #TrackQueue
end

function Queue:nextTrack(Remove)
	local TrackQueue = self:getTrackPlaylist()
	
	if #TrackQueue > 0 then return Remove and table.remove(TrackQueue, 1) or TrackQueue[1] end
end

function Queue:getPlayingTrack()
	if self:getStatus() == Queue.Enumeration.Playing then return table.unpack(self.__playing) end
end

return Queue