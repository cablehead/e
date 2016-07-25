local levee = require("levee")
local _ = levee._


local function split(s, sep)
	local sep, fields = sep or "%s", {}
	local pattern = string.format("([^%s]+)", sep)
	s:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end


local command = {
	usage = function()
		return [[Usage: e [options] ]]
	end,

	parse = function(argv)
		local options = {}
		while argv:more() do
			local opt = argv:option()
			if opt == "c" then
				options.c = split(argv:next(), ":")
			else
				argv:exit("unknown option")
			end
		end
		return options
	end,

	run = function(options)
		local h = levee.Hub()
		-- h.stdin = setmetatable({hub = h, no = 0}, h.io.R_mt)
		-- h.stdin.r_ev = h:register_nopoll(0, true)

		io.stdin:setvbuf("no")
		_.fcntl_nonblock(0)
		h.stdin = h.io:r(0)

		local count = 0
		local groups = {}

		h:spawn(function()
			while true do
				h:sleep(1000)

				if options.c then
					print("---")
					local ordered = {}
					for k, v in pairs(groups) do table.insert(ordered, {k=k, v=v}) end
					table.sort(ordered, function(a, b) return a.v > b.v end)
					for __, i in ipairs(ordered) do print(i.k, i.v) end
					groups = {}
				else
					print(count)
					count = 0
				end
			end
		end)

		local stream = h.stdin:stream()
		while true do
			local err, line = stream:line()
			if err then break end

			if options.c then
				local i = 0
				while i <= #options.c do
					local n = options.c[i]
					if tonumber(n) then
						line = split(line)
					else
						line = split(line, n)
						i = i + 1
						n = options.c[i]
					end

					line = line[tonumber(n)]
					i = i + 1
				end

				groups[line] = (groups[line] or 0) + 1
			end

			count = count + 1

			-- h:continue()
		end
	end,
}


local function main()
	local argv = _.argv(arg)

	local nxt = argv:peek()
	if nxt == "-h" or nxt == "--help" then
		io.stderr:write(command.usage() .. "\n")
		os.exit(1)
	end

	local options = command.parse(argv)
	if not options then
		io.stderr:write(command.usage() .. "\n")
		os.exit(1)
	end

	return command.run(options)
end


main()
