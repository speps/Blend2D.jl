import Printf: @sprintf

const srcpath = joinpath(splitdir(Base.source_path())[1], "src", "blend2d", "src")
const outpath = joinpath(splitdir(Base.source_path())[1], "..", "src", "gen")
const header = "# This file has been auto-generated, do not edit!\n"

const enumsignore = ["BLByteOrder"]
const funcsignore = [
	v -> !(v in [
		# implemented manually
		"blImageCodecBuiltInCodecs",
		# BLGlyphRun
		"blContextFillGlyphRunI",
		"blContextFillGlyphRunD",
		"blContextStrokeGlyphRunI",
		"blContextStrokeGlyphRunD",
		# va_list
		"blRuntimeMessageVFmt",
		"blStringApplyOpFormatV",
		# BLFormatInfo
		"blFormatInfoSanitize",
		# BLStrokeOptionsCore
		"blContextGetStrokeOptions",
		"blContextSetStrokeOptions",
		"blPathAddStrokedPath",
		# BLImageScaleOptions
		"blImageScale",
		# BLContextHints
		"blContextSetHints",
		# unused
		"blRuntimeAssertionFailure"
	]),
	v -> !startswith(v, "blFont"),
	v -> !startswith(v, "blGlyph"),
	v -> !startswith(v, "blGradient"),
	v -> !startswith(v, "blPixelConverter"),
	v -> !startswith(v, "blStroke"),
	v -> !startswith(v, "blFile"),
	v -> !endswith(v, "FromData"),
]
const structsignore = [
	# implemented manually
	"BLMatrix2D"
]

function sanitize_name(s)
	if s == "end"
		return "end_"
	end
	return s
end

function parse_header(filename)
	content = join(readlines(filename), "\n")

	# enums
	enums = collect(eachmatch(r"^BL_DEFINE_ENUM\((?<name>\w+)\)\s*\{(?<values>.*?)\}"sm, content))
	enums = filter(v -> !(v[:name] in enumsignore), enums)
	enums = map(function(enum)
		vals = collect(eachmatch(r"^\s*(?<item>BL_\w+)(\s*?=\s*?(?<const>[x0-9a-fA-F]+)u?)?"sm, enum[:values]))
		vals = map(v -> Dict(:item => v[:item], :const => v[:const] == nothing ? "" : String(v[:const])), vals)
		for (index, item) in enumerate(vals)
			if item[:const] == ""
				item[:const] = index == 1 ? "0" : @sprintf("0x%08x", parse(Int, vals[index - 1][:const]) + 1)
			else
				item[:const] = @sprintf("0x%08x", parse(Int, item[:const]))
			end
		end
		Dict(:name => enum[:name], :values => vals)
	end, enums)

	# funcs
	# keep closing ) in 'params' so we can match the end of the params or comma later on
	funcs = collect(eachmatch(r"^BL_API_C\s+(?<return>.+?)\s+BL_CDECL\s+(?<name>\w+)\s*\((?<params>.+?\)).*?;$"sm, content))
	funcs = filter(v -> all(t -> t(v[:name]), funcsignore), funcs)
	funcs = map(function(func)
		params = collect(eachmatch(r"\s*(?<type>.+?)\s+(?<name>\w+?)\s*[,\)]", func[:params]))
		params = map(p -> Dict(:name => p[:name], :type => p[:type]), params)
		Dict(:name => func[:name], :return => func[:return], :params => params)
	end, funcs)

	# structs
	structs = collect(eachmatch(r"^struct\s+(?<name>\w+)\s*\{(?<fields>.*?)\}\s*;"sm, content))
	structs = map(s -> Dict(:name => s[:name], :fields => s[:fields]), structs)
	structs = map(function(s)
		fields = s[:fields]
		fields = replace(fields, r"#if.+?#endif"sm => "")
		fields = replace(fields, r"^\s*//.*?$"sm => "")
		fields = collect(eachmatch(r"\s*(?<type>.+?)\s+(?<name>\w+?)\s*(?<array>\[\d*\])?\s*;"sm, fields))
		fields = map(p -> Dict(:name => p[:name], :type => p[:type]), fields)
		Dict(:name => s[:name], :fields => fields)
	end, structs)

	Dict(:enums => enums, :funcs => funcs, :structs => structs)
end

function ctype_match(ctype)
	return match(r"(const\s+)?(?<basetype>[^*]+)(?<ptr>\*)?", ctype)
end

function is_mutable(structname)
	if any(v -> startswith(structname, v), ["BLBox", "BLRect", "BLPoint", "BLSize"])
		return false
	end
	return true
end

function default_value(type)
	if type == "Ptr{Cvoid}"
		return "Ptr{Cvoid}(0)"
	elseif startswith(type, "C")
		return "0"
	else
		return "$type()"
	end
end

function convert_type(structnames, enumnames, ctype, isccall)
	t = ctype_match(ctype)
	if t[:basetype] in structnames
		if endswith(t[:basetype], "Impl")
			return "Ptr{Cvoid}"
		elseif is_mutable(t[:basetype])
			return isccall ? "Ref{$(t[:basetype])}" : t[:basetype]
		else
			return t[:basetype]
		end
	elseif t[:basetype] in enumnames
		return t[:basetype]
	elseif t[:basetype] == "char"
		if t[:ptr] != nothing
			return isccall ? "Cstring" : "String"
		else
			return "Cchar"
		end
	elseif t[:basetype] == "uint8_t"
		return "Cuchar"
	elseif t[:basetype] == "uint16_t"
		return isccall ? "Cushort" : "Integer"
	elseif t[:basetype] == "uint32_t"
		return isccall ? "Cuint" : "Integer"
	elseif t[:basetype] == "int64_t"
		return isccall ? "Clonglong" : "Integer"
	elseif t[:basetype] == "uint64_t"
		return isccall ? "Culonglong" : "Integer"
	elseif t[:basetype] == "float"
		return "Cfloat"
	elseif t[:basetype] == "double"
		return "Cdouble"
	elseif t[:basetype] == "bool"
		return "Cuchar"
	elseif t[:basetype] == "char" && t[:ptr] != nothing
		return "Cstring"
	elseif t[:basetype] == "int"
		return isccall ? "Cint" : "Integer"
	elseif t[:basetype] == "size_t"
		return isccall ? "Csize_t" : "Integer"
	elseif t[:basetype] == "intptr_t"
		return "Culonglong"
	elseif t[:basetype] == "BLResult"
		return "BLResultCode"
	elseif t[:basetype] == "BLBitWord"
		return "Ptr{Cvoid}"
	elseif endswith(t[:basetype], "Impl")
		return "Ptr{Cvoid}"
	elseif t[:basetype] == "void"
		if t[:ptr] != nothing
			return "Ptr{Cvoid}"
		else
			return "Cvoid"
		end
	end
	error("unknown type [$(ctype)]")
end

function entry_point_parse_headers()
	mainheader = joinpath(srcpath, "blend2d.h")
	content = join(readlines(mainheader), "\n")
	matches = collect(eachmatch(r"#include \"(?<include>.+?)\""sm, content))
	includes = map(m -> m[:include], matches)
	results = Dict()
	for inc in includes
		incpath = joinpath(srcpath, inc)
		result = parse_header(incpath)
		merge!(append!, results, result)
	end

	exportnames = Set()
	enumnames = Set(map(v -> v[:name], results[:enums]))
	structnames = Set(map(v -> v[:name], results[:structs]))

	mkpath(outpath)
	open(joinpath(outpath, "enums.jl"), "w") do f
		write(f, header)
		for enum in results[:enums]
			push!(exportnames, enum[:name])
			write(f, "# $(enum[:name])\n")
			write(f, "const $(enum[:name]) = UInt32\n")
			for value in enum[:values]
				push!(exportnames, value[:item])
				write(f, "const $(value[:item]) = $(value[:const])\n")
			end
		end
	end

	mkpath(outpath)
	open(joinpath(outpath, "funcs.jl"), "w") do f
		write(f, header)
		for func in results[:funcs]
			push!(exportnames, func[:name])
			ret = convert_type(structnames, enumnames, func[:return], true)
			fparams = join(map(p -> "$(p[:name])::$(convert_type(structnames, enumnames, p[:type], false))", func[:params]), ", ")
			cparams = join(map(p -> "$(convert_type(structnames, enumnames, p[:type], true))", func[:params]), ", ")
			cparamnames = join(map(p -> p[:name], func[:params]), ", ")
			write(f, "function $(func[:name])($(fparams))\n")
			if size(func[:params], 1) > 0
				write(f, "\tccall((:$(func[:name]), libblend2d), $(ret), ($(cparams),), $(cparamnames))\n")
			else
				write(f, "\tccall((:$(func[:name]), libblend2d), $(ret), ())\n")
			end
			write(f, "end\n")
		end
	end

	structstokeep = Set()
	for func in results[:funcs]
		push!(structstokeep, ctype_match(func[:return])[:basetype])
		for p in func[:params]
			push!(structstokeep, ctype_match(p[:type])[:basetype])
		end
	end
	for stru in results[:structs]
		if stru[:name] in structstokeep && !endswith(stru[:name], "Core")
			for f in stru[:fields]
				push!(structstokeep, ctype_match(f[:type])[:basetype])
			end
		end
	end

	mkpath(outpath)
	open(joinpath(outpath, "structs.jl"), "w") do f
		write(f, header)
		for stru in results[:structs]
			if stru[:name] in structstokeep
				if stru[:name] in structsignore
					continue
				end
				push!(exportnames, stru[:name])
				try
					fields = join(map(f -> "\t$(sanitize_name(f[:name]))::$(convert_type(structnames, [], f[:type], true))", stru[:fields]), "\n")
					defaultvalues = join(map(f -> "$(default_value(convert_type(structnames, [], f[:type], true)))", stru[:fields]), ", ")
					cons = "$(stru[:name])() = new($defaultvalues)"
					if is_mutable(stru[:name])
						write(f, "mutable struct $(stru[:name])\n$fields\n\t$cons\nend\n\n")
					else
						defaultconsnames = join(map(f -> f[:name], stru[:fields]), ", ")
						cons = "$cons\n\t$(stru[:name])($defaultconsnames) = new($defaultconsnames)"
						write(f, "struct $(stru[:name])\n$fields\n\t$cons\nend\n\n")
					end
				catch e
					rethrow([ErrorException(stru[:name]), e])
				end
			end
		end
	end

	mkpath(outpath)
	open(joinpath(outpath, "export.jl"), "w") do f
		write(f, header)
		for exportname in exportnames
			write(f, "export $exportname\n")
		end
	end
end

entry_point_parse_headers()
