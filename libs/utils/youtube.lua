local http = require('coro-http')
local querystring = require('querystring')
local json = require('json')
local childprocess = require('childprocess')
local fs = require('fs')
local uv = require('uv')
local extentions = require('utils/extentions')
local debug = function(...) print(string.format('(%s) YouTube:', os.date('%F %T')), ...) end

local youtube = {
    API = 'https://www.googleapis.com/youtube/v3',
	
	AudioDownloadPath = 'cache/media',
	AudioCache = {},
	
	SearchCacheFilePath = 'cache/search.json',
	SearchCache = {}
}

youtube.setAPIKey = function(APIKey) youtube.APIKey = APIKey end

youtube.findVideoID = function(SearchQuery)
    assert(type(SearchQuery) == 'string')
	
	local SearchCache = youtube.SearchCache
	
	if SearchCache[SearchQuery] then return nil, SearchCache[SearchQuery] else
		local SearchQueryEncoded = querystring.urlencode(SearchQuery)
		local SearchQueryURL = string.format('%s/search?q=%s&type=video&key=%s&maxResults=1', youtube.API, SearchQueryEncoded, youtube.APIKey)
		
		local RequestResponse, RequestBody = http.request("GET", SearchQueryURL, {Accept = 'application/json'})
		
		if RequestResponse.code == 200 then
			local SearchQueryResult = json.decode(RequestBody).items[1]
			local YTVideoID = SearchQueryResult.id.videoId
			
			SearchCache[SearchQuery] = YTVideoID
			fs.writeFile(youtube.SearchCacheFilePath, json.encode(SearchCache))
			
			return nil, YTVideoID
		else return RequestResponse.code end
	end
end

youtube.getYTVideoMetadata = function(YTVideoID)
    assert(type(YTVideoID) == 'string') assert(#YTVideoID == 11)

	local YTVideoMetadataQueryURL = string.format('%s/videos?part=snippet%%2CcontentDetails%%2Cstatistics&id=%s&key=%s', youtube.API, YTVideoID, youtube.APIKey)
	
	local RequestResponse, RequestBody = http.request("GET", YTVideoMetadataQueryURL, {Accept = 'application/json'})
	
	if RequestResponse.code == 200 then
		local RequestBodyJSONDecoded = json.decode(RequestBody)
        local YTVideoMetadataQueryResult = RequestBodyJSONDecoded.items
		
		if #YTVideoMetadataQueryResult == 0 then
			return 'Returned 0 items'
		else
			local YTVideoMetadata = {
				Title = YTVideoMetadataQueryResult[1].snippet.title,
				Duration = extentions.ISO8601toSeconds(YTVideoMetadataQueryResult[1].contentDetails.duration)
			}
			
			return nil, YTVideoMetadata
		end
    else return RequestResponse.code end
end

youtube.downloadAudio = function(YTVideoID, Callback)
    assert(type(YTVideoID) == 'string') assert(#YTVideoID == 11)
	
	if youtube.AudioCache[YTVideoID] then
		Callback(nil, youtube.AudioCache[YTVideoID])
	else
		local StandardInput = uv.new_pipe()
		local StandardOutput = uv.new_pipe()
		local StandardError = uv.new_pipe()

		assert(
			uv.spawn(
				"yt-dlp", {
					args = {'-f', 'ba', string.format('https://www.youtube.com/watch?v=%s', YTVideoID), '-o', string.format('%s/%%(id)s.%%(ext)s', youtube.AudioDownloadPath)},
					stdio = {StandardInput, StandardOutput, StandardError}
				},
				function(Code, Signal)
					if Code == 0 then
						fs.readdir(youtube.AudioDownloadPath,
							function(Error, Data)
								for _, File in pairs(Data) do
									if string.sub(File, 1, 11) == YTVideoID then
										local TrackAudioFilePath = string.format('%s/%s', youtube.AudioDownloadPath, File)
										
										youtube.AudioCache[YTVideoID] = TrackAudioFilePath
										
										if Callback then coroutine.wrap(function() Callback(nil, TrackAudioFilePath) end)() end
									end
								end
							end
						)
					else
						debug(string.format("Error code %s while downloading audio for '%s'", Code, YTVideoID))
					
						if Callback then coroutine.wrap(function() Callback(Error, nil) end)() end
					end
				end
			),
			'yt-dlp could not be started, is it installed and on your executable path?'
		)

		StandardInput:read_start(debug)
		StandardOutput:read_start(debug)
		StandardError:read_start(debug)

		StandardOutput:shutdown()
	end
end

fs.readdir(youtube.AudioDownloadPath,
	function(Error, Data)
		if not Error then
			for _, File in pairs(Data) do
				youtube.AudioCache[string.sub(File, 1, 11)] = string.format('%s/%s', youtube.AudioDownloadPath, File)
			end
		else debug(string.format("Error at loading audio cache of '%s'", youtube.AudioDownloadPath)) end
	end
)

fs.readFile(youtube.SearchCacheFilePath,
	function(Error, Data)
		if not Error then
			for SearchQuery, YTVideoID in pairs(json.decode(#Data > 0 and Data or '{ }')) do
				youtube.SearchCache[SearchQuery] = YTVideoID
			end
		else debug(string.format("Error at loading search cache at '%s'", youtube.SearchCacheFilePath)) end
	end
)

return youtube