-- Takes in an mpv loop and passes it through ffmpeg to output an mp4
-- For now only mp4 is supported, but gif may be implemented later

local mp = require "mp"
local utils = require "mp.utils"

local defaults = {
	videoEnc = "libx264",
	audioEnc = "aac",
	otherFlags = {'-movflags', '+faststart'}
}

local burnsubs = false

local function fileInDir(dirfiles, filename)
	local foundFile = false
	for k, file in pairs(dirfiles) do
		if file == filename then
			foundFile = true
			break
		end
	end
	return foundFile
end

local function getOutputName(filename)
	local outprefix = (filename:match("([^/]+)%..+$") or "")
	local outfilename = outprefix .. "_loop.mp4"
	local dirfiles    = utils.readdir(".", "files")

	local foundFile = fileInDir(dirfiles, outfilename)
	if not foundFile then
		return outfilename
	end

	for i=1, 100 do
		outfilename = outprefix .. "_loop" .. tostring(i) .. ".mp4"
		if not fileInDir(dirfiles, outfilename) then
			return outfilename
		end
	end

	return false
end

local function export_loop(burnsubs)
	local burnsubs  = burnsubs or false
	local starttime = mp.get_property("ab-loop-a")
	local endtime   = mp.get_property("ab-loop-b")
	if (not starttime or starttime == 'no' or not endtime or endtime == 'no') then
		print("Could not get loop ends. Please set loop boundaries first.")
		return false
	end
	local duration  = endtime - starttime
	if not (starttime and endtime and duration > 0) then
		print("Invalid loop, please make sure ab-loop-b > ab-loop-a")
		return false
	end
	local filename    = mp.get_property("filename")
	local outfilename = getOutputName(filename)

	-- If we are burning subtitles, it is necessary to place -ss after -i.
	-- This is a big hit to efficiency, as it forces ffmpeg to read the file from the beginning, so we do not do this by default
	local ffmpegArgs  = {}
	if burnsubs then
		ffmpegArgs = {
			'run', 'ffmpeg', '-i', filename, '-ss', starttime, '-t', duration, "-c:v", defaults.videoEnc, "-c:a", defaults.audioEnc,
			"-filter_complex", "subtitles=\'" .. filename .. "\'"
		}
	else
		ffmpegArgs = {
			'run', 'ffmpeg', '-ss', starttime, '-i', filename, '-t', duration, "-c:v", defaults.videoEnc, "-c:a", defaults.audioEnc
		}
	end
	for k,v in pairs(defaults.otherFlags) do
		table.insert(ffmpegArgs, v)
	end
	table.insert(ffmpegArgs, outfilename)
	print      (unpack(ffmpegArgs))
	mp.commandv(unpack(ffmpegArgs))
end

local function export_loop_burnsubs()
	export_loop(true)
end

local function export_loop_nosubs()
	export_loop(false)
end


mp.add_key_binding("G", "export_loop_burnsubs", export_loop_burnsubs)

mp.add_key_binding("g", "export_loop_nosubs", export_loop_nosubs)