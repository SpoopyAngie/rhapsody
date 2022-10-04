local base64 = require('base64')
local http = require('coro-http')
local json = require('json')
local debug = function(...) print(string.format('(%s) Spotify:', os.date('%F %T')), ...) end

local spotify = {
	API = 'https://api.spotify.com/v1'
}

spotify.setClientID = function(ClientID) spotify.ClientID = ClientID end
spotify.setClientSecret = function(ClientSecret) spotify.ClientSecret = ClientSecret end

spotify.isAccessTokenValid = function()
	if not spotify.AccessToken then return false end
	if os.time(os.date("!*t")) + 300 > spotify.AccessTokenExpiration then return false end

	return true
end

spotify.getAccessToken = function(ClientID, ClientSecret)
	--
	-- Guest Token URL: https://open.spotify.com/get_access_token?reason=transport&productType=web_player
	-- 
	
	assert(type(ClientID) == 'string')
	assert(type(ClientSecret) == 'string')
	
	if spotify.isAccessTokenValid() then return spotify.AccessToken else
		debug("Spotify access token is not valid. Requesting another ...")
		
		local RequestBody = 'grant_type=client_credentials'
		
		local RequestHeaders = {
			{ 'Authorization', string.format("Basic %s", base64.encode(string.format("%s:%s", ClientID, ClientSecret))) },
			{ 'Content-Type', 'application/x-www-form-urlencoded' },
		}
		
		local RequestResponse, RequestBody = http.request("POST", 'https://accounts.spotify.com/api/token', RequestHeaders, RequestBody)
		
		if RequestResponse.code == 200 then
			local RequestBodyJSONDecoded = json.decode(RequestBody)
			local SpotifyAccessToken = RequestBodyJSONDecoded.access_token
			
			spotify.AccessToken = SpotifyAccessToken
			spotify.AccessTokenExpiration = os.time(os.date("!*t")) + tonumber(RequestBodyJSONDecoded.expires_in)
			
			return SpotifyAccessToken
		end
	end
end

spotify.getTrackName = function(SpotifyTrackID)
	local SpotifyAccessToken = spotify.getAccessToken(spotify.ClientID, spotify.ClientSecret)
	
	if SpotifyAccessToken then
		local SpotifyTrackMetadataQueryURL = string.format('%s/tracks/%s', spotify.API, SpotifyTrackID)
		
		local RequestHeaders = {
			{ 'Authorization', string.format('Bearer %s', SpotifyAccessToken) },
			{ 'Accept', 'application/json' },
			{ 'Content-Type', 'application/json' }
		}
		
		local RequestResponse, RequestBody = http.request("GET", SpotifyTrackMetadataQueryURL, RequestHeaders)
		
		if RequestResponse.code == 200 then
			local RequestBodyJSONDecoded = json.decode(RequestBody)
			
			SpotifyTrackName = RequestBodyJSONDecoded.name
			SpotifyTrackTitle = ''
			
			for SpotifyArtistIndex, SpotifyArtist in pairs(RequestBodyJSONDecoded.artists) do
				if SpotifyArtist.type == 'artist' then
					if SpotifyArtistIndex > 1 then SpotifyTrackTitle = SpotifyTrackTitle .. ', ' end
					
					SpotifyTrackTitle = SpotifyTrackTitle .. SpotifyArtist.name
				end
			end
			
			SpotifyTrackTitle = string.format("%s - %s", SpotifyTrackTitle, SpotifyTrackName) 
			
			return nil, SpotifyTrackTitle
		else return RequestResponse.code end
	else return 'Spotify access token not found' end
end

spotify.getPlaylist = function(SpotifyPlaylistID)
	local SpotifyAccessToken = spotify.getAccessToken(spotify.ClientID, spotify.ClientSecret)
	
	if SpotifyAccessToken then
		local SpotifyPlaylistQueryURL = string.format('%s/playlists/%s?fields=name%%2C%%20tracks(items(track))', spotify.API, SpotifyPlaylistID)
		
		local RequestHeaders = {
			{ 'Authorization', string.format('Bearer %s', SpotifyAccessToken) },
			{ 'Accept', 'application/json' },
			{ 'Content-Type', 'application/json' }
		}
		
		local RequestResponse, RequestBody = http.request("GET", SpotifyPlaylistQueryURL, RequestHeaders)
		
		if RequestResponse.code == 200 then
			local RequestBodyJSONDecoded = json.decode(RequestBody)
			local SpotifyPlaylist = {
				Name = RequestBodyJSONDecoded.name,
				Tracks = {}
			}
			
			for _, SpotifyTrack in pairs(RequestBodyJSONDecoded.tracks.items) do
				local SpotifyTrackName = SpotifyTrack.track.name
				local SpotifyTrackTitle = ''
			
				for SpotifyArtistIndex, SpotifyArtist in pairs(SpotifyTrack.track.artists) do
					if SpotifyArtist.type == 'artist' then
						if SpotifyArtistIndex > 1 then SpotifyTrackTitle = SpotifyTrackTitle .. ', ' end
						
						SpotifyTrackTitle = SpotifyTrackTitle .. SpotifyArtist.name
					end
				end
				
				SpotifyTrackTitle = string.format("%s - %s", SpotifyTrackTitle, SpotifyTrackName) 
				
				table.insert(SpotifyPlaylist.Tracks, #SpotifyPlaylist.Tracks + 1, SpotifyTrackTitle)
			end
			
			return nil, SpotifyPlaylist
		else return RequestResponse.code end
	else return 'Spotify access token not found' end
end

return spotify