using Blend2D

image = Blend2D.BLImageCore()
@show Blend2D.blImageInit(image)
@show image

codec = Blend2D.BLImageCodecCore()
@show Blend2D.blImageCodecInit(codec)
@show codec

codecs = Blend2D.blImageCodecBuiltInCodecs()
@show codecs
@show Blend2D.blImageCodecFindByName(codec, codecs, "PNG")
@show codec

@show Blend2D.blImageReadFromFile(image, "julia.png", codecs)
@show image

@show Blend2D.blImageWriteToFile(image, "julia_out.png", codec)

data = Blend2D.BLImageData()
@show Blend2D.blImageGetData(image, data)
@show data
